// wayer_storage — file-backed index: build / meta / search.
// See include/wayer/storage/index.hpp.
#include <wayer/storage/index.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/core/paths.hpp>
#include <wayer/storage/walker.hpp>

#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <format>
#include <fstream>
#include <string>
#include <string_view>
#include <system_error>

namespace wayer::storage {
namespace fs = std::filesystem;

namespace {

constexpr std::string_view kIndexRelPath = "index/files.json";
constexpr std::size_t kDefaultMaxResults = 50;
constexpr std::size_t kHardMaxResults = 200;

std::string to_lower_copy(std::string_view s) {
    std::string out(s);
    std::transform(out.begin(), out.end(), out.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return out;
}

// Append the UTF-8 encoding of cp (BMP or U+FFFD fallback) to out.
void append_utf8(std::string& out, uint32_t cp) {
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        // Outside BMP — emit replacement char; indexed paths never need more.
        out += static_cast<char>(0xEF);
        out += static_cast<char>(0xBF);
        out += static_cast<char>(0xBD);
    }
}

// Minimal streaming reader: the index file can be large, so never slurp it.
class CharStream {
public:
    explicit CharStream(std::istream& in) : in_(in) {}

    // Returns false at EOF.
    bool next(char& c) {
        if (pos_ >= len_) {
            if (!in_) return false;
            in_.read(buf_.data(), static_cast<std::streamsize>(buf_.size()));
            auto got = in_.gcount();
            if (got <= 0) return false;
            len_ = static_cast<std::size_t>(got);
            pos_ = 0;
        }
        c = buf_[pos_++];
        return true;
    }

private:
    std::istream& in_;
    std::array<char, 8192> buf_{};
    std::size_t pos_ = 0;
    std::size_t len_ = 0;
};

bool is_ws(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

uint32_t hex4(CharStream& cs) {
    uint32_t v = 0;
    for (int i = 0; i < 4; ++i) {
        char c = 0;
        if (!cs.next(c)) return 0xFFFD;
        v <<= 4;
        if (c >= '0' && c <= '9') v |= static_cast<uint32_t>(c - '0');
        else if (c >= 'a' && c <= 'f') v |= static_cast<uint32_t>(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') v |= static_cast<uint32_t>(c - 'A' + 10);
        else return 0xFFFD;
    }
    return v;
}

// Parse one "..." literal; the opening quote was already consumed.
// Returns false on EOF/malformed (caller stops the scan cleanly).
bool parse_string(CharStream& cs, std::string& out) {
    out.clear();
    char c = 0;
    while (cs.next(c)) {
        if (c == '"') return true;
        if (c != '\\') {
            out += c;
            continue;
        }
        if (!cs.next(c)) return false;
        switch (c) {
            case '"': out += '"'; break;
            case '\\': out += '\\'; break;
            case '/': out += '/'; break;
            case 'b': out += '\b'; break;
            case 'f': out += '\f'; break;
            case 'n': out += '\n'; break;
            case 'r': out += '\r'; break;
            case 't': out += '\t'; break;
            case 'u': {
                uint32_t cp = hex4(cs);
                // Surrogate halves never appear in indexed paths; map to U+FFFD.
                if (cp >= 0xD800 && cp <= 0xDFFF) cp = 0xFFFD;
                append_utf8(out, cp);
                break;
            }
            default: out += c; break; // lenient: keep raw char
        }
    }
    return false;
}

} // namespace

std::string index_file_path() {
    if (!core::app_paths_initialized()) return "";
    return core::app_paths().cache + "/" + std::string(kIndexRelPath);
}

std::string build_index(const std::string& root) {
    const std::string path = index_file_path();
    if (path.empty()) return R"({"error":"paths_not_initialized"})";

    std::error_code ec;
    fs::path p(path);
    if (p.has_parent_path()) fs::create_directories(p.parent_path(), ec);

    std::ofstream out(path, std::ios::binary | std::ios::trunc);
    if (!out) return R"({"error":"index_write_failed"})";

    std::size_t count = 0;
    out << R"({"root":")" << core::json::escape(root) << R"(","files":[)";
    bool first = true;
    walk_files(root, [&](const fs::directory_entry& e) {
        if (!first) out << ",";
        first = false;
        out << "\"" << core::json::escape(e.path().string()) << "\"";
        ++count;
    });
    out << "]})";
    out.close();
    if (!out) return R"({"error":"index_write_failed"})";

    return std::format(R"({{"path":"{}","count":{}}})", core::json::escape(path), count);
}

std::string index_meta() {
    const std::string path = index_file_path();
    if (path.empty()) return R"({"error":"paths_not_initialized"})";

    std::error_code ec;
    if (!fs::exists(path, ec) || ec) return R"({"status":"missing"})";
    uint64_t bytes = fs::file_size(path, ec);
    if (ec) return R"({"status":"missing"})";
    auto ftime = fs::last_write_time(path, ec);
    if (ec) return R"({"status":"missing"})";
    auto sys_secs = std::chrono::floor<std::chrono::seconds>(
        std::chrono::clock_cast<std::chrono::system_clock>(ftime));
    long long modified = sys_secs.time_since_epoch().count();

    return std::format(R"({{"status":"ready","path":"{}","bytes":{},"modified_unix":{}}})",
                       core::json::escape(path), bytes, modified);
}

std::string search_index(const std::string& query, std::size_t max_results) {
    if (max_results == 0) max_results = kDefaultMaxResults;
    max_results = std::min(max_results, kHardMaxResults);

    const std::string q_lower = to_lower_copy(query);
    std::string matches_json;
    std::size_t total = 0;
    std::size_t kept = 0;

    if (!q_lower.empty()) {
        const std::string path = index_file_path();
        std::ifstream in(path, std::ios::binary);
        if (in) {
            CharStream cs(in);
            // Seek: "files" key, then its opening '['.
            // (Only parses files this module wrote — see build_index.)
            char c = 0;
            std::string lit;
            bool in_array = false;
            while (!in_array && cs.next(c)) {
                if (c != '"') continue;
                if (!parse_string(cs, lit)) break;
                if (lit != "files") continue;
                // Expect ':' then '[' (whitespace allowed, EOF-safe).
                bool colon = false;
                while (cs.next(c)) {
                    if (is_ws(c)) continue;
                    colon = (c == ':');
                    break;
                }
                if (!colon) continue;
                while (cs.next(c)) {
                    if (is_ws(c)) continue;
                    in_array = (c == '[');
                    break;
                }
            }
            // Scan array elements.
            std::string candidate;
            bool done = false;
            while (in_array && !done && cs.next(c)) {
                if (c == ']') break;
                if (c == ',') continue;
                if (is_ws(c)) continue;
                if (c != '"') {
                    done = true; // malformed — stop cleanly, keep what we have
                    break;
                }
                if (!parse_string(cs, candidate)) break;
                if (to_lower_copy(candidate).find(q_lower) == std::string::npos) continue;
                ++total;
                if (kept < max_results) {
                    if (kept > 0) matches_json += ",";
                    matches_json += std::format(R"("{}")", core::json::escape(candidate));
                    ++kept;
                }
            }
        }
    }

    return std::format(R"({{"query":"{}","count":{},"truncated":{},"matches":[{}]}})",
                       core::json::escape(query), total, (total > kept ? "true" : "false"),
                       matches_json);
}

} // namespace wayer::storage

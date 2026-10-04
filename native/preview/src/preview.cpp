// wayer_preview — read-only text preview. See include/wayer/preview/preview.hpp.
#include <wayer/preview/preview.hpp>

#include <wayer/core/json_util.hpp>

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <format>
#include <fstream>
#include <string>
#include <system_error>

namespace wayer::preview {
namespace fs = std::filesystem;

namespace {

constexpr std::size_t kDefaultMaxBytes = 64u * 1024u;
constexpr std::size_t kHardMaxBytes = 256u * 1024u;

} // namespace

std::string read_text_file(const std::string& path, std::size_t max_bytes) {
    if (max_bytes == 0) max_bytes = kDefaultMaxBytes;
    if (max_bytes > kHardMaxBytes) max_bytes = kHardMaxBytes;

    std::error_code ec;
    const fs::path p(path);
    if (!fs::exists(p, ec) || ec) return R"({"error":"not_found"})";
    if (!fs::is_regular_file(p, ec) || ec) return R"({"error":"not_file"})";
    const uint64_t size = fs::file_size(p, ec);
    if (ec) return R"({"error":"unreadable"})";

    std::ifstream in(path, std::ios::binary);
    if (!in) return R"({"error":"unreadable"})";

    std::size_t want = max_bytes;
    if (size < static_cast<uint64_t>(max_bytes)) want = static_cast<std::size_t>(size);
    std::string buf(want, '\0');
    in.read(buf.data(), static_cast<std::streamsize>(want));
    const std::streamsize got = in.gcount();
    if (got < 0) return R"({"error":"unreadable"})";
    buf.resize(static_cast<std::size_t>(got));

    // Binary sniff: a NUL byte means "not text" — report metadata only.
    for (char c : buf) {
        if (c == '\0') {
            return std::format(R"({{"path":"{}","size":{},"binary":true}})",
                               core::json::escape(path), size);
        }
    }

    // Plain line split (\n terminated, tolerates \r\n). The byte budget above
    // already bounds how much we ever hold, so no extra line cap is needed.
    std::string lines_json;
    std::size_t line_count = 0;
    std::size_t start = 0;
    while (start <= buf.size()) {
        const std::size_t end = buf.find('\n', start);
        const bool last = (end == std::string::npos);
        std::string line = buf.substr(start, last ? std::string::npos : end - start);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line_count > 0) lines_json += ",";
        lines_json += std::format(R"("{}")", core::json::escape(line));
        ++line_count;
        if (last) break;
        start = end + 1;
    }

    const bool truncated = size > static_cast<uint64_t>(buf.size());
    return std::format(
        R"({{"path":"{}","size":{},"truncated":{},"line_count":{},"lines":[{}]}})",
        core::json::escape(path), size, truncated ? "true" : "false", line_count, lines_json);
}

} // namespace wayer::preview

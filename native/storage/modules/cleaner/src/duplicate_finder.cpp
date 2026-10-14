// wayer_storage_cleaner — duplicate detection (size → partial hash → full hash).
// v2 JSON: {"version":2,"duplicate_groups":[[{path,size,mtime}...]],"related_groups":[{key,files:[...]}]}
// Contract kept: find_duplicates_to_file writes file, returns {"status":"ok","path":...} only.
#include <wayer/storage/cleaner.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/core/text.hpp>
#include <wayer/storage/walker.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <format>
#include <fstream>
#include <functional>
#include <string>
#include <string_view>
#include <system_error>
#include <unordered_map>
#include <vector>

namespace wayer::storage {

namespace {

// One file's info for the eraser UI. Plain struct — no methods.
struct DupFile {
    std::string path;
    uint64_t size = 0;
    int64_t mtime = 0; // unix seconds, 0 = unknown
};

// FNV-1a 64 over a byte stream — chunked, so multi-GB files never load fully.
uint64_t fnv1a_stream(std::istream& in, size_t max_bytes = static_cast<size_t>(-1)) {
    constexpr uint64_t kOffset = 14695981039346656037ULL;
    constexpr uint64_t kPrime = 1099511628211ULL;
    uint64_t h = kOffset;
    std::array<char, 8192> buf{};
    size_t remaining = max_bytes;
    while (in && remaining > 0) {
        size_t want = std::min(buf.size(), remaining);
        in.read(buf.data(), static_cast<std::streamsize>(want));
        std::streamsize got = in.gcount();
        if (got <= 0) break;
        for (std::streamsize i = 0; i < got; ++i) {
            h ^= static_cast<unsigned char>(buf[static_cast<size_t>(i)]);
            h *= kPrime;
        }
        remaining -= static_cast<size_t>(got);
    }
    return h;
}

// Cheap partial hash: first 4 KiB mixed with size.
// returns false when file cannot be opened - caller must SKIP.
bool try_partial_hash(const fs::path& p, uint64_t size, uint64_t& out) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return false;

    uint64_t h = fnv1a_stream(f, 4096);
    out = h ^ (size * 0x9E3779B97F4A7C15ULL);

    return true;
}

// returns false when file cannot be opened - caller must skip, not group
bool try_full_hash(const fs::path& p, uint64_t& out) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return false;

    out = fnv1a_stream(f);
    return true;
}

// Final guard: hash says "maybe equal", bytes say "sure".
// Returns false on any open/read trouble — caller treats as "not proven".
bool files_byte_equal(const fs::path& a, const fs::path& b) {
    std::ifstream fa(a, std::ios::binary);
    std::ifstream fb(b, std::ios::binary);
    if (!fa || !fb) return false;
    std::array<char, 8192> bufa{};
    std::array<char, 8192> bufb{};
    while (true) {
        fa.read(bufa.data(), static_cast<std::streamsize>(bufa.size()));
        fb.read(bufb.data(), static_cast<std::streamsize>(bufb.size()));
        std::streamsize ga = fa.gcount();
        std::streamsize gb = fb.gcount();
        if (ga != gb) return false;
        if (ga == 0) return true; // both hit end together
        for (std::streamsize i = 0; i < ga; ++i) {
            if (bufa[static_cast<size_t>(i)] != bufb[static_cast<size_t>(i)]) return false;
        }
    }
}

// Plain unix seconds for JSON. NDK-safe pattern from storage/index.cpp:
// no file_clock::to_sys / clock_cast (NDK libc++ lacks it).
int64_t file_mtime_unix(const fs::path& p) {
    std::error_code ec;
    auto ftime = fs::last_write_time(p, ec);
    if (ec) return 0;
    const auto age = ftime - fs::file_time_type::clock::now();
    const auto sys_tp = std::chrono::system_clock::now() +
        std::chrono::duration_cast<std::chrono::system_clock::duration>(age);
    return std::chrono::floor<std::chrono::seconds>(sys_tp).time_since_epoch().count();
}

uint64_t file_size_or_zero(const fs::path& p) {
    std::error_code ec;
    uint64_t sz = fs::file_size(p, ec);
    if (ec) return 0;
    return sz;
}

// --- Related-files key: basic string ops only ---
bool ends_with_word(const std::string& s, const std::string& word) {
    if (s.size() < word.size()) return false;
    return s.compare(s.size() - word.size(), word.size(), word) == 0;
}

void trim_trailing_space_dash(const std::string& s, std::string& out) {
    size_t end = s.size();
    while (end > 0) {
        char c = s[end - 1];
        if (c == ' ' || c == '\t' || c == '-' || c == '_' || c == '.') --end;
        else break;
    }
    out = s.substr(0, end);
}

// "notes (1).docx" / "notes - final.docx" / "notes_v2.pdf" -> "notes"
// NEVER used for delete decisions — display grouping only.
std::string normalize_related_key(const std::string& filename) {
    std::string lower = core::ascii_lower(filename);
    size_t dot = lower.rfind('.');
    std::string base = lower;
    if (dot != std::string::npos && dot != 0) base = lower.substr(0, dot);
    // Trim once before loop.
    std::string cur;
    trim_trailing_space_dash(base, cur);
    for (int iter = 0; iter < 5; ++iter) {
        std::string t;
        trim_trailing_space_dash(cur, t);
        cur = t;
        if (cur.empty()) break;
        // Trailing "(digits)" like " (1)" or "(12)".
        if (!cur.empty() && cur.back() == ')') {
            size_t open = cur.rfind('(');
            if (open != std::string::npos && open + 1 < cur.size()) {
                bool all_digits = true;
                for (size_t i = open + 1; i + 1 < cur.size(); ++i) {
                    if (cur[i] < '0' || cur[i] > '9') { all_digits = false; break; }
                }
                if (all_digits) {
                    cur = cur.substr(0, open);
                    continue;
                }
            }
            break;
        }
        if (ends_with_word(cur, "copy")) {
            // Require a separator before "copy" so "copycat" survives.
            size_t pos = cur.size() - 4;
            if (pos > 0 && (cur[pos - 1] == ' ' || cur[pos - 1] == '-' || cur[pos - 1] == '_' ||
                            cur[pos - 1] == '(')) {
                cur = cur.substr(0, pos - 1);
                continue;
            }
            break;
        }
        if (ends_with_word(cur, "final")) {
            size_t pos = cur.size() - 5;
            if (pos > 0 && (cur[pos - 1] == ' ' || cur[pos - 1] == '-' || cur[pos - 1] == '_')) {
                cur = cur.substr(0, pos - 1);
                continue;
            }
            break;
        }
        // Trailing v-number: " v2", "_v2", "-v2", "v2".
        size_t n = cur.size();
        size_t d = n;
        while (d > 0 && cur[d - 1] >= '0' && cur[d - 1] <= '9') --d;
        if (d < n && d > 0 && (cur[d - 1] == 'v' || cur[d - 1] == 'V')) {
            size_t vpos = d - 1;
            if (vpos == 0) { cur.clear(); break; }
            char sep = cur[vpos - 1];
            if (sep == ' ' || sep == '-' || sep == '_' || vpos == 0) {
                cur = (vpos > 0) ? cur.substr(0, vpos - (sep == ' ' || sep == '-' || sep == '_' ? 1 : 0)) : "";
                continue;
            }
        }
        break;
    }
    std::string done;
    trim_trailing_space_dash(cur, done);
    return done;
}

} // namespace

std::string find_duplicates(const std::string& root_path) {
    // Step 1: group by size.
    std::unordered_map<uint64_t, std::vector<fs::path>> by_size;
    walk_files(root_path, [&](const fs::directory_entry& e) {
        std::error_code ec;
        uint64_t sz = e.file_size(ec);
        if (!ec && sz > 0) by_size[sz].push_back(e.path());
    });

    // Step 2: within each size group, group by partial hash.
    std::vector<std::vector<DupFile>> duplicate_groups;
    for (auto& size_entry : by_size) {
        std::vector<fs::path>& paths = size_entry.second;
        if (paths.size() < 2) continue; // unique size, can't be a dup

        std::unordered_map<uint64_t, std::vector<fs::path>> by_partial;
        for (auto& p : paths) {
            uint64_t h = 0;
            if (!try_partial_hash(p, size_entry.first, h)) continue;

            by_partial[h].push_back(p);
        }

        // Step 3: confirm with full hash only for partial-hash collisions.
        for (auto& partial_entry : by_partial) {
            std::vector<fs::path>& candidates = partial_entry.second;
            if (candidates.size() < 2) continue;

            std::unordered_map<uint64_t, std::vector<fs::path>> by_full;
            for (auto& p : candidates) {
                uint64_t h = 0;
                if (!try_full_hash(p, h)) continue;

                by_full[h].push_back(p);
            }

            for (auto& full_entry : by_full) {
                std::vector<fs::path>& same_hash = full_entry.second;
                if (same_hash.size() < 2) continue;
                // Hash is only a hint: split by real byte content.
                std::vector<std::vector<fs::path>> verified;
                for (auto& p : same_hash) {
                    bool placed = false;
                    for (auto& v : verified) {
                        if (files_byte_equal(v.front(), p)) {
                            v.push_back(p);
                            placed = true;
                            break;
                        }
                    }
                    if (!placed) verified.push_back({p});
                }
                for (auto& v : verified) {
                    if (v.size() < 2) continue;
                    std::vector<DupFile> group;
                    group.reserve(v.size());
                    for (auto& p : v) {
                        DupFile f;
                        f.path = p.string();
                        f.size = size_entry.first;
                        f.mtime = file_mtime_unix(p);
                        group.push_back(f);
                    }
                    duplicate_groups.push_back(group);
                }
            }
        }
    }

    for (auto& g : duplicate_groups)
        std::sort(g.begin(), g.end(), [](const DupFile& a, const DupFile& b) { return a.path < b.path; });
    std::sort(duplicate_groups.begin(), duplicate_groups.end(),
              [](const std::vector<DupFile>& a, const std::vector<DupFile>& b) {
                  return a.front().path < b.front().path;
              });

    // Related files: same normalized name, any size/version. Display only.
    std::unordered_map<std::string, std::vector<fs::path>> by_related;
    for (auto& size_entry : by_size) {
        for (auto& p : size_entry.second) {
            std::string fname = p.filename().string();
            if (fname.empty()) continue;
            std::string key = normalize_related_key(fname);
            if (key.size() < 3) continue;
            by_related[key].push_back(p);
        }
    }
    struct RelatedGroup {
        std::string key;
        std::vector<DupFile> files;
    };
    std::vector<RelatedGroup> related;
    std::vector<std::string> keys;
    keys.reserve(by_related.size());
    for (auto& e : by_related) {
        if (e.second.size() >= 2 && e.second.size() <= 20) keys.push_back(e.first);
    }
    std::sort(keys.begin(), keys.end());
    constexpr size_t kMaxRelatedGroups = 200;
    constexpr size_t kMaxFilesPerRelated = 20;
    for (auto& k : keys) {
        if (related.size() >= kMaxRelatedGroups) break;
        auto& paths = by_related[k];
        RelatedGroup g;
        g.key = k;
        // Stable order before enriching.
        std::sort(paths.begin(), paths.end());
        size_t want = std::min(paths.size(), kMaxFilesPerRelated);
        for (size_t i = 0; i < want; ++i) {
            DupFile f;
            f.path = paths[i].string();
            f.size = file_size_or_zero(paths[i]);
            f.mtime = file_mtime_unix(paths[i]);
            g.files.push_back(f);
        }
        related.push_back(g);
    }

    std::string json = R"({"version":2,"duplicate_groups":[)";
    for (size_t g = 0; g < duplicate_groups.size(); ++g) {
        json += "[";
        for (size_t i = 0; i < duplicate_groups[g].size(); ++i) {
            const DupFile& f = duplicate_groups[g][i];
            json += std::format(R"({{"path":"{}","size":{},"mtime":{}}})",
                                core::json::escape(f.path), f.size, f.mtime);
            if (i + 1 < duplicate_groups[g].size()) json += ",";
        }
        json += "]";
        if (g + 1 < duplicate_groups.size()) json += ",";
    }
    json += R"(],"related_groups":[)";
    for (size_t g = 0; g < related.size(); ++g) {
        json += std::format(R"({{"key":"{}","files":[)", core::json::escape(related[g].key));
        for (size_t i = 0; i < related[g].files.size(); ++i) {
            const DupFile& f = related[g].files[i];
            json += std::format(R"({{"path":"{}","size":{},"mtime":{}}})",
                                core::json::escape(f.path), f.size, f.mtime);
            if (i + 1 < related[g].files.size()) json += ",";
        }
        json += "]}";
        if (g + 1 < related.size()) json += ",";
    }
    json += "]}";
    return json;
}

std::string find_duplicates_to_file(const std::string& root_path, const std::string& out_path) {
    const std::string json = find_duplicates(root_path);
    if (!core::write_text_file(out_path, json)) {
        return R"({"status":"error","reason":"write_failed"})";
    }
    return std::format(R"({{"status":"ok","path":"{}"}})", core::json::escape(out_path));
}

} // namespace wayer::storage

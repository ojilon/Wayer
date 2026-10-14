// wayer_storage_cleaner — duplicate detection (size → partial hash → full hash).
#include <wayer/storage/cleaner.hpp>

#include <wayer/core/json_util.hpp>
#include <wayer/core/text.hpp>
#include <wayer/storage/walker.hpp>

#include <algorithm>
#include <array>
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
        std::vector<std::vector<fs::path>> duplicate_groups;
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
                        if (v.size() > 1) duplicate_groups.push_back(v);
                    }
                }
            }
        }
    
        for (auto& g : duplicate_groups) std::sort(g.begin(), g.end());
        std::sort(duplicate_groups.begin(), duplicate_groups.end(),
                  [](const std::vector<fs::path>& a, const std::vector<fs::path>& b) {
                      return a.front() < b.front();
                  });

        std::string json = R"({"duplicate_groups":[)";
        for (size_t g = 0; g < duplicate_groups.size(); ++g) {
            json += "[";
            for (size_t i = 0; i < duplicate_groups[g].size(); ++i) {
                json += std::format(R"("{}")", core::json::escape(duplicate_groups[g][i].string()));
                if (i + 1 < duplicate_groups[g].size()) json += ",";
            }
            json += "]";
            if (g + 1 < duplicate_groups.size()) json += ",";
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

// duplicate_finder.cpp
#include "duplicate_finder.hpp"
#include "dir_walker.hpp"
#include <unordered_map>
#include <fstream>
#include <format>
#include <functional> // std::hash
#include "../utils/json_util.hpp"

namespace wayer::storage {

    // Cheap partial hash: first N bytes, combined with the size.
    uint64_t partial_hash(const fs::path& p, uint64_t size) {
        std::ifstream f(p, std::ios::binary);
        char buf[4096]{};
        f.read(buf, sizeof(buf));
        std::string_view chunk(buf, static_cast<size_t>(f.gcount()));
        return std::hash<std::string_view>{}(chunk) ^ (size * 0x9E3779B97F4A7C15ULL);
    }

    // Full hash only used to CONFIRM a partial-hash collision.
    uint64_t full_hash(const fs::path& p) {
        std::ifstream f(p, std::ios::binary);
        std::string content((std::istreambuf_iterator<char>(f)), {});
        return std::hash<std::string>{}(content);
    }

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
        for (auto& [size, paths] : by_size) {
            if (paths.size() < 2) continue; // unique size, can't be a dup

            std::unordered_map<uint64_t, std::vector<fs::path>> by_partial;
            for (auto& p : paths) by_partial[partial_hash(p, size)].push_back(p);

            // Step 3: confirm with full hash only for partial-hash collisions.
            for (auto& [ph, candidates] : by_partial) {
                if (candidates.size() < 2) continue;

                std::unordered_map<uint64_t, std::vector<fs::path>> by_full;
                for (auto& p : candidates) by_full[full_hash(p)].push_back(p);

                for (auto& [fh, confirmed] : by_full) {
                    if (confirmed.size() > 1) duplicate_groups.push_back(confirmed);
                }
            }
        }

        // Build JSON (using the escape() helper from json_util.hpp)
        std::string json = R"({"duplicate_groups":[)";
        for (size_t g = 0; g < duplicate_groups.size(); ++g) {
            json += "[";
            for (size_t i = 0; i < duplicate_groups[g].size(); ++i) {
                json += std::format(R"("{}")", json::escape(duplicate_groups[g][i].string()));
                if (i + 1 < duplicate_groups[g].size()) json += ",";
            }
            json += "]";
            if (g + 1 < duplicate_groups.size()) json += ",";
        }
        json += "]}";
        return json;
    }
}
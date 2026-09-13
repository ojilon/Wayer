#include <unordered_map>
#include <cstdint>
#include <filesystem>
#include <sys/statvfs.h>
#include <algorithm>
#include <format>
#include "extension_map.hpp"

/**
 * Gets storage statistics for the specified root path.
 * Uses std::filesystem::recursive_directory_iterator to traverse directories.
 * Uses std::unordered_map to categorize files by extension.
 * Uses statvfs to get partition-level storage metrics (total, free, used).
 * Uses std::format (C++20) for modern string formatting.
 * 
 * Categorizes files into: images, videos, audio, documents, foreign, system, others.
 * Uses EXTENSION_MAP (from extension_map.hpp) to match file extensions to categories.
 * Files not in the map are categorized as "others".
 * 
 * @param root_path The root directory path to analyze.
 * @return JSON string with storage statistics including total_bytes, used_bytes,
 *         free_bytes, progress_percent, and breakdown by category.
 * 
 * STL usage:
 * - std::unordered_map<std::string, uint64_t>: map to accumulate sizes by category
 * - fs::recursive_directory_iterator: traverses all files and directories recursively
 * - std::format: formats the JSON output string efficiently (C++20)
 * - statvfs: system struct for getting filesystem statistics
 * 
 * Example: get_storage_stats("/storage/emulated/0") returns:
 * {"total_bytes":1073741824,"used_bytes":536870912,"free_bytes":536870912,
 *  "progress_percent":50,"breakdown":{"images":1073741824,"videos":0,"audio":0,
 *  "documents":0,"foreign":0,"system":0,"others":0}}
 */
namespace wayer::storage {
    namespace fs = std::filesystem;

    //Hardcoded retail sizes in bytes
    // 64GB = 64'000'000'000 bytes
    constexpr uint64_t RETAIL_64GB = 64ULL * 1000ULL * 1000ULL * 1000ULL;



    std::string get_storage_stats(const std::string& root_path) {

        struct statvfs stat {};
        if (statvfs(root_path.c_str(), &stat) != 0) {
            return R"({"error": "Failed to read storage statistics"})";
        }

        //partition metrics from the OS
        uint64_t partition_total = static_cast<uint64_t>(stat.f_blocks) * stat.f_frsize;
        uint64_t free_bytes = static_cast<uint64_t>(stat.f_bavail) * stat.f_frsize;
        uint64_t partition_used = partition_total - free_bytes;

        uint64_t total_bytes = (partition_total > RETAIL_64GB) ? partition_total : RETAIL_64GB;
        uint64_t system_bytes = (total_bytes > partition_total) ? (total_bytes - partition_total) : 0;
        uint64_t used_bytes = partition_used + system_bytes;

        int progress_percent = total_bytes > 0 ? static_cast<int>((used_bytes * 100) / total_bytes) : 0;

        std::unordered_map<std::string, uint64_t> categories = {
            {"images", 0}, {"videos", 0}, {"audio", 0}, {"foreign", 0}, {"others", 0}
        };

        std::error_code ec;
        for (const auto& entry : fs::recursive_directory_iterator(
                 root_path, fs::directory_options::skip_permission_denied, ec)) {
            if (ec) break;
            if (entry.is_regular_file(ec)) {
                auto ext = entry.path().extension().string();
                std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

                uint64_t sz = entry.file_size(ec);
                if (ec) continue;

                if (auto it = EXTENSION_MAP.find(ext); it != EXTENSION_MAP.end()) {
                    categories[std::string(it -> second)] += sz;
                } else {
                    categories["others"] += sz;
                }
            }
        }

        return std::format(
            R"({{)"
            R"("total_bytes":{},"used_bytes":{},"free_bytes":{},"progress_percent":{},)"
            R"("breakdown":{{"images":{},"videos":{},"audio":{},"documents":{},"foreign":{},"system":{},"others":{}}})"
            R"(}})",
            total_bytes, used_bytes, free_bytes, progress_percent,
            categories["images"], categories["videos"], categories["audio"], 
            categories["documents"], categories["foreign"], system_bytes, categories["others"]
        );
    }
}
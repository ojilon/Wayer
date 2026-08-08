#pragma once
#include <string>
#include <string_view>
#include <cstdint>

namespace wayer::storage {
    std::string list_files(std::string_view path);
    std::string get_storage_stats(const std::string& root_path);

    // Bulk search: returns exact_matches + related_matches JSON
    std::string search_files(const std::string& root_path, const std::string& query);

    // Bulk large-file scan: JSON array sorted by size descending
    // min_bytes default 10MB, max_results default 50
    std::string find_large_files(const std::string& root_path,
                                uint64_t min_bytes,
                                int max_results);
}

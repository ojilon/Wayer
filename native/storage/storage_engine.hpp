#pragma once
#include <string>
#include <string_view>

namespace wayer::storage {
    std::string list_files(std::string_view path);
    std::string get_storage_stats(const std::string& root_path);

    // Bulk search: returns exact_matches + related_matches JSON
    std::string search_files(const std::string& root_path, const std::string& query);
}

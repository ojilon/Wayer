#pragma once
#include <string>
#include <string_view>

namespace wayer::storage {
    std::string list_files(std::string_view path);
    std::string get_storage_stats(const std::string& root_path);
}
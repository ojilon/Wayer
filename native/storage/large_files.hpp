#pragma once

#include <cstdint>
#include <string>

namespace wayer::storage {
    std::string find_large_files(const std::string &root_path, uint64_t min_bytes, int max_results);

}
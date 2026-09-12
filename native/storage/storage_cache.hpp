// storage_cache.hpp
#pragma once
#include <string>
namespace wayer::storage {
    void write_cache(const std::string& cache_path, const std::string& json);
    std::string read_cache_if_fresh(const std::string& cache_path, int max_age_seconds);
}
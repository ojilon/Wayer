#pragma once
// wayer_storage — file-backed cache for stats/index JSON blobs.
#include <string>

namespace wayer::storage {
void write_cache(const std::string& cache_path, const std::string& json);
std::string read_cache_if_fresh(const std::string& cache_path, int max_age_seconds);
// Explicit invalidation after native mutations (delete / apply_organize).
bool invalidate_cache(const std::string& cache_path);
} // namespace wayer::storage

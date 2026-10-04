#pragma once
// wayer_storage — storage statistics over a root path.
#include <cstdint>
#include <string>

namespace wayer::storage {

// Compute stats for root_path, write the JSON document to out_path, record a
// SQLite history row (best-effort), and reply {"status":"ok","path":...}.
// known_device_bytes comes from Java (0 = legacy retail-capacity floor).
std::string write_storage_stats(const std::string& root_path, const std::string& out_path,
                                uint64_t known_device_bytes);

} // namespace wayer::storage

#pragma once
// wayer_storage — storage statistics over a root path.
#include <cstdint>
#include <string>

namespace wayer::storage {

// Classic entry point (kept for JNI compat). Uses statvfs partition metrics
// plus a retail-capacity floor when Java has not supplied a real capacity.
std::string get_storage_stats(const std::string& root_path);

// Preferred entry point: Java passes the real device capacity (bytes) queried
// via StorageManager/StatFs. Pass 0 to fall back to the legacy behavior.
std::string get_storage_stats(const std::string& root_path, uint64_t known_device_bytes);

} // namespace wayer::storage

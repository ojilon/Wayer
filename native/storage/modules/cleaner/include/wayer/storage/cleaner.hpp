#pragma once
// wayer_storage_cleaner — duplicates + large-file helpers.
#include <cstdint>
#include <string>

namespace wayer::storage {
// Kept in wayer::storage for JNI compat; submodule owns the TUs.
std::string find_duplicates(const std::string& root_path);
std::string find_large_files(const std::string& root_path, uint64_t min_bytes, int max_results);
// Same results written to out_path; replies are {"status":"ok","path":...} only.
std::string find_duplicates_to_file(const std::string& root_path, const std::string& out_path);
std::string find_large_files_to_file(const std::string& root_path, uint64_t min_bytes,
                                     int max_results, const std::string& out_path);
} // namespace wayer::storage

#pragma once
// wayer_storage_search — file-name search helpers.
#include <string>

namespace wayer::storage {
// Kept in wayer::storage for JNI compat; submodule owns the TU.
std::string search_files(const std::string& root_path, const std::string& query);
} // namespace wayer::storage

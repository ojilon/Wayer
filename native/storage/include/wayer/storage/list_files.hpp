#pragma once
// wayer_storage — non-recursive directory listing.
#include <string>
#include <string_view>

namespace wayer::storage {
std::string list_files(std::string_view path);
} // namespace wayer::storage

#pragma once
#include <string>
#include <string_view>

namespace wayer::storage {
    std::string list_files(std::string_view path);
}
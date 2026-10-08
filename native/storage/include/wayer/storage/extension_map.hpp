#pragma once
// wayer_storage — extension → category map (defined in src/extension_map.cpp).
#include <string>
#include <string_view>
#include <unordered_map>

namespace wayer::storage {

// Shared lookup table. Read-only after startup; never modified at runtime.
extern const std::unordered_map<std::string, std::string> EXTENSION_MAP;

// Lower-cased extension (including dot) → category, or "others".
// Lowering happens inside, so callers pass the raw extension.
std::string category_for_extension(std::string_view ext);

} // namespace wayer::storage

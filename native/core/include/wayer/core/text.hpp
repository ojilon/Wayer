#pragma once
// wayer_core — tiny plain-text helpers shared by every module.
// Single home for case folding so each engine stops carrying its own copy.
#include <string>

namespace wayer::core {

// Lowercase ASCII A-Z in place-copy. Non-ASCII bytes pass through untouched,
// which is exactly what file-name matching in this tree needs.
std::string ascii_lower(std::string s);

} // namespace wayer::core

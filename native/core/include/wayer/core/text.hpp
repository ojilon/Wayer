#pragma once
// wayer_core — tiny plain-text helpers shared by every module.
// Single home for case folding so each engine stops carrying its own copy.
#include <string>

namespace wayer::core {

// Lowercase ASCII A-Z in place-copy. Non-ASCII bytes pass through untouched,
// which is exactly what file-name matching in this tree needs.
std::string ascii_lower(std::string s);

// Write content to path (creating parents, truncating). True only when the
// file verifies afterwards. For C++-computed results Java will read back.
bool write_text_file(const std::string& path, const std::string& content);

} // namespace wayer::core

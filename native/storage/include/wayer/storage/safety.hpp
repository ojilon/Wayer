#pragma once
// wayer_storage — directory exclusion rules for tree walks.
// Migrated from native/storage/safety_rules.hpp (defined in src/safety.cpp).
#include <filesystem>

namespace wayer::storage {
namespace fs = std::filesystem;

// Names checked once per directory, at the top of the subtree — not per-file.
bool is_excluded_dir(const fs::path& dir);
} // namespace wayer::storage

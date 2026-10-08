#pragma once
// wayer_storage — shared walk primitive (defined in src/walker.cpp).
// Migrated from dir_walker.hpp.
#include <filesystem>
#include <functional>
#include <string>

namespace wayer::storage {
namespace fs = std::filesystem;

// Calls visit(entry) for every regular file under root.
// Prunes excluded directories instead of just filtering their contents —
// it never descends into them at all.
void walk_files(const std::string& root,
                const std::function<void(const fs::directory_entry&)>& visit);
} // namespace wayer::storage

// dir_walker.hpp
#pragma once
#include <filesystem>
#include <functional>
#include "safety_rules.hpp"

namespace wayer::storage {
    namespace fs = std::filesystem;

    // Calls visit(entry) for every regular file under root.
    // Prunes excluded directories instead of just filtering their contents —
    // it never descends into them at all.
    inline void walk_files(const std::string& root,
                            const std::function<void(const fs::directory_entry&)>& visit) {
        std::error_code ec;
        fs::recursive_directory_iterator it(
            root, fs::directory_options::skip_permission_denied, ec);
        fs::recursive_directory_iterator end;

        if (ec) return; // can't even open root

        while (it != end) {
            const auto& entry = *it;

            bool is_dir = entry.is_directory(ec);
            if (ec) { it.increment(ec); continue; }

            if (is_dir) {
                if (is_excluded_dir(entry.path())) {
                    it.disable_recursion_pending(); // don't step inside this dir
                    it.increment(ec);
                    continue;
                }
                it.increment(ec);
                continue;
            }

            bool is_file = entry.is_regular_file(ec);
            if (!ec && is_file) visit(entry);

            it.increment(ec);
            if (ec) break; // stop cleanly rather than looping on a broken iterator
        }
    }
}
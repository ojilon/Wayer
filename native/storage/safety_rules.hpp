// safety_rules.hpp
#pragma once
#include <filesystem>
#include <string>

namespace wayer::storage {
    namespace fs = std::filesystem;

    // Names checked once per directory, at the top of the subtree — not per-file.
    inline bool is_excluded_dir(const fs::path& dir) {
        std::string name = dir.filename().string();
        if (name == "data" && dir.parent_path().filename() == "Android") return true;
        if (name == "obb"  && dir.parent_path().filename() == "Android") return true;
        if (name == ".thumbnails") return true;
        if (name == ".trashed") return true;
        if (name == ".dwayer_cache") return true; // your own app's cache dir
        return false;
    }
}
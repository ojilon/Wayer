// wayer_storage — directory exclusion rules. See include/wayer/storage/safety.hpp.
#include <wayer/storage/safety.hpp>

#include <filesystem>
#include <string>

namespace wayer::storage {

bool is_excluded_dir(const fs::path& dir) {
    const std::string name = dir.filename().string();
    if (name == "data" && dir.parent_path().filename() == "Android") return true;
    if (name == "obb" && dir.parent_path().filename() == "Android") return true;
    if (name == ".thumbnails") return true;
    if (name == ".trashed") return true;
    if (name == ".dwayer_cache") return true; // app's own cache dir
    return false;
}

} // namespace wayer::storage

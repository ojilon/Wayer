// wayer_storage — directory exclusion rules. See include/wayer/storage/safety.hpp.
#include <wayer/storage/safety.hpp>

#include <filesystem>
#include <string>

namespace wayer::storage {

bool is_excluded_dir(const fs::path& dir) {
    const std::string name = dir.filename().string();
    // Android private data — never scan (scoped storage denies most anyway).
    if (name == "data" && dir.parent_path().filename() == "Android") return true;
    if (name == "obb" && dir.parent_path().filename() == "Android") return true;
    // Thumbnails / caches / trash — scanning wastes time, deleting risks system files.
    if (name == ".thumbnails") return true;
    if (name == "thumbnails") return true;
    if (name == ".trashed") return true;
    if (name == ".trash") return true;
    if (name == ".cache") return true;
    if (name == "LOST.DIR") return true;
    // App's own scratch + holding folder (see FileMutator.moveToTrash).
    // Keeps scans from finding their own output / staged deletes.
    if (name == ".dwayer_cache") return true; // app's own cache dir
    if (name == "wayer_trash") return true;
    if (name == ".wayer_trash") return true;
    // NOTE: hardlinks (same inode, two paths) are NOT skipped here — detecting
    // them needs fs::equivalent(a,b) per pair (slow). They may still appear as
    // duplicates but save 0 bytes; UI labels them via size+mtime instead.
    return false;
}

} // namespace wayer::storage

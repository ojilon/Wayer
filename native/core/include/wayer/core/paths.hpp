#pragma once
#include <string>

namespace wayer::core {

/**
 * App-owned directories under the path Java passes at init (filesDir / subdir).
 *
 * Layout:
 *   <root>/paths.json  manifest: canonical paths + per-dir status (see below)
 *   <root>/cache/      storage_stats, index, search results
 *   <root>/temp/       transfer staging, organize dry-runs
 *   <root>/logs/       native.log
 *
 * The manifest is the shared record of this layout: Java persists the
 * `manifest` path returned by the init action and consults that file for
 * per-folder paths instead of re-deriving them on both sides.
 */
struct AppPaths {
    std::string root;
    std::string cache;
    std::string temp;
    std::string logs;

    static AppPaths from_root(const std::string& app_root);
};

// Outcome of ensuring a single directory (idempotent, never throws).
struct DirEnsure {
    std::string path;
    bool existed = false; // already a directory before this call
    bool ready = false;   // is a directory now (creation verified, not assumed)
};

// Full ensure report: paths + per-directory status.
struct AppDirsReport {
    AppPaths paths;
    DirEnsure root;
    DirEnsure cache;
    DirEnsure temp;
    DirEnsure logs;

    bool all_ready() const { return root.ready && cache.ready && temp.ready && logs.ready; }
};

// Check-then-create for root + cache/temp/logs. Safe to call on every init.
AppDirsReport ensure_app_dirs(const std::string& app_root);

// Write <root>/paths.json: {version, root, dirs{...}, existed{...}, ready}.
// Returns the manifest path, or "" when it could not be written.
std::string write_paths_manifest(const AppDirsReport& report);

// Call once from JNI after Java supplies files dir.
void set_app_paths(const AppPaths& paths);
const AppPaths& app_paths();
bool app_paths_initialized();

} // namespace wayer::core

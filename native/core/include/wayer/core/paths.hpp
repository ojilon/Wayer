#pragma once
#include <string>

namespace wayer::core {

/**
 * App-owned directories under the path Java passes at init (filesDir / subdir).
 * Implementation: migrate into src/paths.cpp (see MIGRATION.md).
 *
 * Layout (target):
 *   <root>/cache/   storage_stats, index, search results
 *   <root>/temp/    transfer staging, organize dry-runs
 *   <root>/logs/    native.log
 */
struct AppPaths {
    std::string root;
    std::string cache;
    std::string temp;
    std::string logs;

    static AppPaths from_root(const std::string& app_root);
};

// Call once from JNI after Java supplies files dir.
void set_app_paths(const AppPaths& paths);
const AppPaths& app_paths();

} // namespace wayer::core

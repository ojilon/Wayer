// wayer_core — AppPaths implementation. See include/wayer/core/paths.hpp.
#include <wayer/core/paths.hpp>

#include <filesystem>
#include <mutex>
#include <system_error>

namespace wayer::core {
namespace {

std::mutex g_mutex;
AppPaths g_paths; // empty root until set_app_paths() is called from JNI.
bool g_initialized = false;

} // namespace

AppPaths AppPaths::from_root(const std::string& app_root) {
    namespace fs = std::filesystem;
    AppPaths p;
    p.root = app_root;
    fs::path root(app_root);
    p.cache = (root / "cache").string();
    p.temp = (root / "temp").string();
    p.logs = (root / "logs").string();

    // Best-effort: create the tree now so later writers never have to.
    std::error_code ec;
    fs::create_directories(p.cache, ec);
    fs::create_directories(p.temp, ec);
    fs::create_directories(p.logs, ec);
    return p;
}

void set_app_paths(const AppPaths& paths) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_paths = paths;
    g_initialized = true;

    // Ensure directories exist even if caller built AppPaths manually.
    std::error_code ec;
    namespace fs = std::filesystem;
    if (!g_paths.cache.empty()) fs::create_directories(g_paths.cache, ec);
    if (!g_paths.temp.empty()) fs::create_directories(g_paths.temp, ec);
    if (!g_paths.logs.empty()) fs::create_directories(g_paths.logs, ec);
}

const AppPaths& app_paths() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_paths;
}

bool app_paths_initialized() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_initialized;
}

int core_module_anchor() { return 0; }

} // namespace wayer::core

// wayer_core — AppPaths implementation. See include/wayer/core/paths.hpp.
#include <wayer/core/paths.hpp>

#include <wayer/core/json_util.hpp>

#include <filesystem>
#include <format>
#include <fstream>
#include <mutex>
#include <string>
#include <system_error>

namespace wayer::core {

    namespace {
    std::mutex g_mutex;
    AppPaths g_paths; // empty root until set_app_paths() is called from JNI.
    bool g_initialized = false;

    namespace fs = std::filesystem;

    // Check-then-create for one directory: record whether it already existed,
    // create only when missing, then verify it is actually usable.
    DirEnsure ensure_one(const fs::path& dir) {
        DirEnsure d;
        d.path = dir.string();
        std::error_code ec;
        d.existed = fs::is_directory(dir, ec);
        ec.clear();
        if (!d.existed) fs::create_directories(dir, ec);
        ec.clear();
        d.ready = fs::is_directory(dir, ec);
        return d;
    }

    const char* bool_json(bool v) { return v ? "true" : "false"; }
    } // namespace

    AppDirsReport ensure_app_dirs(const std::string& app_root) {
        AppDirsReport r;
        fs::path root(app_root);
        r.root = ensure_one(root);
        r.paths.root = app_root;
        r.paths.cache = (root / "cache").string();
        r.paths.temp = (root / "temp").string();
        r.paths.logs = (root / "logs").string();
        // Children only attempted when the root itself is usable; their
        // `ready` flags stay false otherwise so callers see the real state.
        if (r.root.ready) {
            r.cache = ensure_one(r.paths.cache);
            r.temp = ensure_one(r.paths.temp);
            r.logs = ensure_one(r.paths.logs);
        } else {
            r.cache.path = r.paths.cache;
            r.temp.path = r.paths.temp;
            r.logs.path = r.paths.logs;
        }
        return r;
    }

    std::string write_paths_manifest(const AppDirsReport& report) {
        if (report.paths.root.empty() || !report.root.ready) return "";
        const std::string manifest =
            (fs::path(report.paths.root) / "paths.json").string();
        std::ofstream out(manifest, std::ios::binary | std::ios::trunc);
        if (!out) return "";
        out << std::format(
            R"({{"version":1,"root":"{}","dirs":{{"cache":"{}","temp":"{}","logs":"{}"}},)"
            R"("existed":{{"root":{},"cache":{},"temp":{},"logs":{}}},)"
            R"("ready":{{"root":{},"cache":{},"temp":{},"logs":{}}}}})",
            json::escape(report.paths.root), json::escape(report.paths.cache),
            json::escape(report.paths.temp), json::escape(report.paths.logs),
            bool_json(report.root.existed), bool_json(report.cache.existed),
            bool_json(report.temp.existed), bool_json(report.logs.existed),
            bool_json(report.root.ready), bool_json(report.cache.ready),
            bool_json(report.temp.ready), bool_json(report.logs.ready));
        out.close();
        if (!out) return "";
        return manifest;
    }

    AppPaths AppPaths::from_root(const std::string& app_root) {
        return ensure_app_dirs(app_root).paths;
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

// wayer_shim.cpp — C++ shim exposing extern "C" wayer_* symbols for the Odin router.
// Each function is a thin wrapper over the existing C++ domain module.
//
// Returned const char* pointers point into a thread_local std::string slot via keep();
// the pointer is valid until the next shim call on the same thread that returns a string.
// No <jni.h> here — jni/wayer_engine.c is the only jni.h user.
//
// Symbol names match the `foreign shim` block in native/odin/wayer_core.odin exactly
// (SEAM RULE: name + signature preserved across C++ shim → C file → Odin proc).
#include <wayer/core/json_util.hpp>
#include <wayer/core/paths.hpp>
#include <wayer/core/logging.hpp>
#include <wayer/storage/storage.hpp>
#include <wayer/documents/documents.hpp>
#include <wayer/transfer/transfer.hpp>
#include <wayer/preview/preview.hpp>

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

namespace {

    thread_local std::string g_return_slot;
    
    const char* keep(std::string s) {
        g_return_slot = std::move(s);
        return g_return_slot.c_str();
    }
    
    } // namespace
    
    extern "C" {
    
    const char* wayer_list_files(const char* path) {
        return keep(wayer::storage::list_files(path));
    }
    
    const char* wayer_get_network_info() {
        return keep(wayer::transfer::get_network_info());
    }
    
    const char* wayer_filter_documents(const char* payload) {
        return keep(wayer::documents::filter_documents(payload));
    }
    
    const char* wayer_start_listener(int port) {
        return keep(wayer::transfer::start_listener(port));
    }
    
    const char* wayer_search_files_to_file(const char* root, const char* query, const char* out_path) {
        return keep(wayer::storage::search_files_to_file(root, query, out_path));
    }
    
    const char* wayer_find_large_files_to_file(const char* root, uint64_t min_bytes, int max_results,
                                               const char* out_path) {
        return keep(wayer::storage::find_large_files_to_file(
            root, min_bytes, max_results, out_path));
    }
    
    const char* wayer_find_duplicates_to_file(const char* root, const char* out_path) {
        return keep(wayer::storage::find_duplicates_to_file(root, out_path));
    }
    
    const char* wayer_plan_organize_to_file(const char* root, const char* out_path) {
        return keep(wayer::storage::plan_organize_to_file(root, out_path));
    }
    
    const char* wayer_apply_organize_file(const char* plan_path, const char* report_path) {
        return keep(wayer::storage::apply_organize_file(plan_path, report_path));
    }
    
    const char* wayer_read_cache_if_fresh(const char* cache_path, int max_age) {
        return keep(wayer::storage::read_cache_if_fresh(cache_path, max_age));
    }
    
    const char* wayer_write_storage_stats(const char* root, const char* cache_path, uint64_t known_bytes) {
        return keep(wayer::storage::write_storage_stats(root, cache_path, known_bytes));
    }
    
    const char* wayer_read_text_file(const char* path, uint64_t max_bytes) {
        return keep(wayer::preview::read_text_file(
            path, static_cast<std::size_t>(max_bytes)));
    }
    
    bool wayer_invalidate_cache(const char* cache_path) {
        return wayer::storage::invalidate_cache(cache_path);
    }
    
    const char* wayer_init_app_paths(const char* app_root) {
        std::string root(app_root);
        auto report = wayer::core::ensure_app_dirs(root);
        wayer::core::set_app_paths(report.paths);
        std::string manifest = wayer::core::write_paths_manifest(report);
        std::string reply = R"({"status":"paths_set","manifest":")";
        reply += wayer::core::json::escape(manifest);
        reply += R"(","all_ready":)";
        reply += report.all_ready() ? "true" : "false";
        reply += R"(,"root":")";
        reply += wayer::core::json::escape(report.paths.root);
        reply += R"(","cache":")";
        reply += wayer::core::json::escape(report.paths.cache);
        reply += R"(","temp":")";
        reply += wayer::core::json::escape(report.paths.temp);
        reply += R"(","logs":")";
        reply += wayer::core::json::escape(report.paths.logs);
        reply += "\"}";
        return keep(reply);
    }
    
    const char* wayer_json_escape(const char* s) {
        return keep(wayer::core::json::escape(s));
    }
    
    void wayer_log_info(const char* tag, const char* msg) {
        wayer::core::log::info(tag, msg);
    }
    
    void wayer_log_error(const char* tag, const char* msg) {
        wayer::core::log::error(tag, msg);
    }

} // extern "C"

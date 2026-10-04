// libwayer_engine.so — sole JNI boundary (see jni/MIGRATION.md).
// Only file in the tree allowed to include <jni.h>. No domain logic here:
// every action routes into wayer_core / wayer_storage / wayer_documents /
// wayer_transfer / wayer_media.
#include <jni.h>

#include <wayer/core/json_util.hpp>
#include <wayer/core/logging.hpp>
#include <wayer/core/paths.hpp>
#include <wayer/documents/documents.hpp>
#include <wayer/preview/preview.hpp>
#include <wayer/storage/storage.hpp>
#include <wayer/transfer/transfer.hpp>

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <format>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr int ACTION_PING = 1;
constexpr int ACTION_GET_STATUS = 2;
constexpr int ACTION_LIST_FILES = 3;
constexpr int ACTION_GET_NETWORK_INFO = 4;
constexpr int ACTION_FILTER_DOCUMENTS = 5;
constexpr int ACTION_START_LISTENER = 6;
constexpr int ACTION_GET_STORAGE_STATS = 7;
constexpr int ACTION_SEARCH_FILES = 8;
constexpr int ACTION_FIND_LARGE_FILES = 9;
constexpr int ACTION_FIND_DUPLICATES = 10;
constexpr int ACTION_PLAN_ORGANIZE = 11;
constexpr int ACTION_APPLY_ORGANIZE = 12;
constexpr int ACTION_GET_CACHED_STATS = 13;
// New modular actions (see native/MODULES.md ordered migration step 7).
constexpr int ACTION_INIT_APP_PATHS = 14;
constexpr int ACTION_BUILD_INDEX = 15;
constexpr int ACTION_INVALIDATE_CACHE = 16;
constexpr int ACTION_INDEX_META = 17;
constexpr int ACTION_SEARCH_INDEX = 18;
constexpr int ACTION_READ_TEXT_FILE = 19;

std::vector<std::string> split_payload(std::string_view payload, char sep = '|') {
    std::vector<std::string> parts;
    size_t start = 0;
    while (start <= payload.size()) {
        auto pos = payload.find(sep, start);
        if (pos == std::string_view::npos) {
            parts.emplace_back(payload.substr(start));
            break;
        }
        parts.emplace_back(payload.substr(start, pos - start));
        start = pos + 1;
    }
    return parts;
}

// Payloads shaped "text|number" where the text itself may legally contain
// '|'. The number is split off the LAST separator, and only when the tail
// is all digits with something before it. Otherwise the whole payload is
// the text and the default applies.
void split_trailing_number(const std::string& payload, std::size_t default_value,
                           std::string& out_text, std::size_t& out_number) {
    out_text = payload;
    out_number = default_value;
    const std::size_t pos = payload.find_last_of('|');
    if (pos == std::string::npos || pos == 0) return;
    const std::string tail = payload.substr(pos + 1);
    if (tail.empty()) return;
    for (char ch : tail) {
        if (ch < '0' || ch > '9') return;
    }
    out_number = static_cast<std::size_t>(std::strtoull(tail.c_str(), nullptr, 10));
    out_text.resize(pos);
}

std::string init_app_paths(std::string_view app_root_raw) {
    std::string app_root(app_root_raw);
    // Trim whitespace/newlines defensively (Java may pass filesDir with suffix).
    while (!app_root.empty() &&
           (app_root.back() == '\n' || app_root.back() == '\r' || app_root.back() == ' ' ||
            app_root.back() == '\t' || app_root.back() == '/')) {
        app_root.pop_back();
    }
    if (app_root.empty()) return R"({"error":"bad_payload"})";
    // Namespace app data under <filesDir>/wayer unless caller already did.
    if (app_root.size() < 6 || app_root.compare(app_root.size() - 6, 6, "/wayer") != 0) {
        app_root += "/wayer";
    }
    // Check-then-create lives in wayer_core; this file only routes + reports.
    // The manifest (<root>/paths.json) is the shared record Java consults for
    // per-folder paths, so later actions can take file paths instead of blobs.
    auto report = wayer::core::ensure_app_dirs(app_root);
    wayer::core::set_app_paths(report.paths);
    const std::string manifest = wayer::core::write_paths_manifest(report);
    wayer::core::log::info(
        "WayerEngine",
        std::format("App paths set: root={} ready={} manifest={}", report.paths.root,
                    report.all_ready() ? "yes" : "no", manifest));
    return std::format(
        R"({{"status":"paths_set","manifest":"{}","all_ready":{},"root":"{}","cache":"{}","temp":"{}","logs":"{}"}})",
        wayer::core::json::escape(manifest), report.all_ready() ? "true" : "false",
        wayer::core::json::escape(report.paths.root), wayer::core::json::escape(report.paths.cache),
        wayer::core::json::escape(report.paths.temp), wayer::core::json::escape(report.paths.logs));
}

// BUILD_INDEX lives in wayer_storage (see storage/index.hpp) so this file stays
// a thin router: split helpers + action dispatch only, no domain logic.

std::string route_action(int action_id, std::string_view payload) {
    switch (action_id) {
        case ACTION_PING:
            return "PONG: " + std::string(payload);
        case ACTION_GET_STATUS:
            return R"({"status": "ready", "engine": "C++23"})";
        case ACTION_LIST_FILES:
            return wayer::storage::list_files(payload);
        case ACTION_GET_NETWORK_INFO:
            return wayer::transfer::get_network_info();
        case ACTION_FILTER_DOCUMENTS:
            return wayer::documents::filter_documents(payload);
        case ACTION_START_LISTENER:
            return wayer::transfer::start_listener(8080);
        case ACTION_GET_STORAGE_STATS: {
            // Payload: "root" or "root|known_device_bytes" (see storage/flags.md).
            auto parts = split_payload(payload);
            std::string root = parts.empty() ? "" : parts[0];
            uint64_t known_bytes = 0;
            if (parts.size() > 1 && !parts[1].empty()) {
                known_bytes = std::strtoull(parts[1].c_str(), nullptr, 10);
            }
            return wayer::storage::get_storage_stats(root, known_bytes);
        }
        case ACTION_SEARCH_FILES: {
            auto parts = split_payload(payload);
            std::string root = parts.empty() ? "" : parts[0];
            std::string query = parts.size() > 1 ? parts[1] : "";
            return wayer::storage::search_files(root, query);
        }
        case ACTION_FIND_LARGE_FILES: {
            auto parts = split_payload(payload);
            std::string root = parts.empty() ? "/storage/emulated/0" : parts[0];
            uint64_t min_bytes = 10ull * 1024 * 1024;
            int max_results = 50;
            if (parts.size() > 1 && !parts[1].empty()) {
                min_bytes = static_cast<uint64_t>(std::strtoull(parts[1].c_str(), nullptr, 10));
            }
            if (parts.size() > 2 && !parts[2].empty()) {
                max_results = static_cast<int>(std::strtol(parts[2].c_str(), nullptr, 10));
            }
            return wayer::storage::find_large_files(root, min_bytes, max_results);
        }
        case ACTION_FIND_DUPLICATES:
            return wayer::storage::find_duplicates(std::string(payload));
        case ACTION_PLAN_ORGANIZE:
            return wayer::storage::plan_organize(std::string(payload));
        case ACTION_APPLY_ORGANIZE:
            return wayer::storage::apply_organize(std::string(payload)); // pipe-delimited, not JSON
        case ACTION_GET_CACHED_STATS: {
            // parts[0]=cache_path, parts[1]=root, parts[2]=max_age,
            // parts[3]=known_device_bytes (optional; 0/absent = legacy floor).
            std::vector<std::string> parts = split_payload(payload);
            if (parts.size() < 3) return R"({"error":"bad_payload"})";
            int max_age = static_cast<int>(std::strtol(parts[2].c_str(), nullptr, 10));

            std::string cached = wayer::storage::read_cache_if_fresh(parts[0], max_age);
            if (!cached.empty()) return cached;

            uint64_t known_bytes = 0;
            if (parts.size() > 3 && !parts[3].empty()) {
                known_bytes = std::strtoull(parts[3].c_str(), nullptr, 10);
            }
            std::string fresh = wayer::storage::get_storage_stats(parts[1], known_bytes);
            wayer::storage::write_cache(parts[0], fresh);
            return fresh;
        }
        case ACTION_INIT_APP_PATHS:
            return init_app_paths(payload);
        case ACTION_BUILD_INDEX:
            return wayer::storage::build_index(std::string(payload));
        case ACTION_INDEX_META:
            return wayer::storage::index_meta();
        case ACTION_SEARCH_INDEX: {
            // Payload "query|max_results" (max optional, default 50).
            std::string query;
            std::size_t max_results = 0;
            split_trailing_number(std::string(payload), 50, query, max_results);
            return wayer::storage::search_index(query, max_results);
        }
        case ACTION_READ_TEXT_FILE: {
            // Payload "path|max_bytes" (budget optional, default 64 KiB).
            std::string path;
            std::size_t max_bytes = 0;
            split_trailing_number(std::string(payload), 0, path, max_bytes);
            return wayer::preview::read_text_file(path, max_bytes);
        }
        case ACTION_INVALIDATE_CACHE:
            return wayer::storage::invalidate_cache(std::string(payload))
                        ? R"({"status":"invalidated"})"
                        : R"({"status":"missing"})";
        default:
            wayer::core::log::error("WayerEngine", "unknown action from Java");
            return R"({"error": "unknown_action"})";
    }
}

} // namespace

extern "C" {
JNIEXPORT void JNICALL
Java_com_example_wayer_core_NativeEngine_initEngine(JNIEnv* /* env */, jclass /* clazz */) {
    wayer::core::log::info("WayerEngine", "C++ engine initialized");
}

JNIEXPORT jstring JNICALL
Java_com_example_wayer_core_NativeEngine_processAction(
    JNIEnv* env, jclass /* clazz */, jint action_id, jstring payload) {
    const char* native_str = env->GetStringUTFChars(payload, nullptr);
    if (!native_str) return env->NewStringUTF("");

    std::string response = route_action(static_cast<int>(action_id), native_str);

    env->ReleaseStringUTFChars(payload, native_str);
    return env->NewStringUTF(response.c_str());
}

} // extern "C"

// libwayer_engine.so — sole JNI boundary (see jni/MIGRATION.md).
// Only file in the tree allowed to include <jni.h>. No domain logic here:
// every action routes into wayer_core / wayer_storage / wayer_documents /
// wayer_transfer / wayer_media.
#include <jni.h>
#include <android/log.h>

#include <wayer/core/json_util.hpp>
#include <wayer/core/paths.hpp>
#include <wayer/documents/documents.hpp>
#include <wayer/storage/storage.hpp>
#include <wayer/transfer/transfer.hpp>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <format>
#include <string>
#include <string_view>
#include <vector>

#define LOG_TAG "WayerEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

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
    auto paths = wayer::core::AppPaths::from_root(app_root);
    wayer::core::set_app_paths(paths);
    LOGI("App paths set: root=%s", paths.root.c_str());
    return std::format(
        R"({{"status":"paths_set","root":"{}","cache":"{}","temp":"{}","logs":"{}"}})",
        wayer::core::json::escape(paths.root), wayer::core::json::escape(paths.cache),
        wayer::core::json::escape(paths.temp), wayer::core::json::escape(paths.logs));
}

// BUILD_INDEX lives in wayer_storage (see storage/index.hpp) so this file stays
// a thin router: split helpers + action dispatch only, no domain logic.

std::string route_action(int action_id, std::string_view payload) {
    using namespace wayer;
    switch (action_id) {
        case ACTION_PING:
            return "PONG: " + std::string(payload);
        case ACTION_GET_STATUS:
            return R"({"status": "ready", "engine": "C++23"})";
        case ACTION_LIST_FILES:
            return storage::list_files(payload);
        case ACTION_GET_NETWORK_INFO:
            return transfer::get_network_info();
        case ACTION_FILTER_DOCUMENTS:
            return documents::filter_documents(payload);
        case ACTION_START_LISTENER:
            return transfer::start_listener(8080);
        case ACTION_GET_STORAGE_STATS: {
            // Payload: "root" or "root|known_device_bytes" (see storage/flags.md).
            auto parts = split_payload(payload);
            std::string root = parts.empty() ? "" : parts[0];
            uint64_t known_bytes = 0;
            if (parts.size() > 1 && !parts[1].empty()) {
                known_bytes = std::strtoull(parts[1].c_str(), nullptr, 10);
            }
            return storage::get_storage_stats(root, known_bytes);
        }
        case ACTION_SEARCH_FILES: {
            auto parts = split_payload(payload);
            std::string root = parts.empty() ? "" : parts[0];
            std::string query = parts.size() > 1 ? parts[1] : "";
            return storage::search_files(root, query);
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
            return storage::find_large_files(root, min_bytes, max_results);
        }
        case ACTION_FIND_DUPLICATES:
            return storage::find_duplicates(std::string(payload));
        case ACTION_PLAN_ORGANIZE:
            return storage::plan_organize(std::string(payload));
        case ACTION_APPLY_ORGANIZE:
            return storage::apply_organize(std::string(payload)); // pipe-delimited, not JSON
        case ACTION_GET_CACHED_STATS: {
            // parts[0]=cache_path, parts[1]=root, parts[2]=max_age,
            // parts[3]=known_device_bytes (optional; 0/absent = legacy floor).
            if (parts.size() < 3) return R"({"error":"bad_payload"})";
            int max_age = static_cast<int>(std::strtol(parts[2].c_str(), nullptr, 10));

            std::string cached = storage::read_cache_if_fresh(parts[0], max_age);
            if (!cached.empty()) return cached;

            uint64_t known_bytes = 0;
            if (parts.size() > 3 && !parts[3].empty()) {
                known_bytes = std::strtoull(parts[3].c_str(), nullptr, 10);
            }
            std::string fresh = storage::get_storage_stats(parts[1], known_bytes);
            storage::write_cache(parts[0], fresh);
            return fresh;
        }
        case ACTION_INIT_APP_PATHS:
            return init_app_paths(payload);
        case ACTION_BUILD_INDEX:
            return storage::build_index(std::string(payload));
        case ACTION_INDEX_META:
            (void)payload;
            return storage::index_meta();
        case ACTION_SEARCH_INDEX: {
            // Payload "query|max_results" (max optional, default 50). Queries may
            // legally contain '|', so the cap is split off the LAST separator and
            // only when the tail is all digits.
            std::string query(payload);
            std::size_t max_results = 50;
            auto pos = query.find_last_of('|');
            if (pos != std::string::npos) {
                std::string tail = query.substr(pos + 1); // owned: strtoull needs NUL
                bool numeric = !tail.empty() &&
                               std::all_of(tail.begin(), tail.end(),
                                           [](char ch) { return ch >= '0' && ch <= '9'; });
                if (numeric && pos > 0) {
                    max_results = static_cast<std::size_t>(std::strtoull(tail.c_str(), nullptr, 10));
                    query.resize(pos);
                }
            }
            return storage::search_index(query, max_results);
        }
        case ACTION_INVALIDATE_CACHE:
            return storage::invalidate_cache(std::string(payload))
                       ? R"({"status":"invalidated"})"
                       : R"({"status":"missing"})";
        default:
            LOGE("Unknown action_id: %d", action_id);
            return R"({"error": "unknown_action"})";
    }
}

} // namespace

extern "C" {
JNIEXPORT void JNICALL
Java_com_example_wayer_core_NativeEngine_initEngine(JNIEnv* /* env */, jclass /* clazz */) {
    LOGI("Wayer C++ Engine Initialized (C++23 Standard)");
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

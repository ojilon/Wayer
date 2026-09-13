#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <cstdlib>
// C++ Standard Library: std
// - std::string, std::string_view: string handling (string_view for non-owning views)
// - std::vector: dynamic array container with methods like emplace_back()
// - std::filesystem: file system operations (used in storage modules)
// - std::format: string formatting (C++20)
#include "storage/analyse_storage_space.hpp"
#include "storage/large_files.hpp"
#include "storage/list_files.hpp"
#include "storage/file_search.hpp"
#include "storage/duplicate_finder.hpp"
#include "storage/file_organizer.hpp"
#include "storage/storage_cache.hpp"
#include "transfer/transfer_engine.hpp"
#include "documents/document_engine.hpp"

#define LOG_TAG "WayerEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

constexpr int ACTION_PING              = 1;
constexpr int ACTION_GET_STATUS        = 2;
constexpr int ACTION_LIST_FILES        = 3;
constexpr int ACTION_GET_NETWORK_INFO  = 4;
constexpr int ACTION_FILTER_DOCUMENTS  = 5;
constexpr int ACTION_START_LISTENER    = 6;
constexpr int ACTION_GET_STORAGE_STATS = 7;
constexpr int ACTION_SEARCH_FILES      = 8;
constexpr int ACTION_FIND_LARGE_FILES  = 9;
constexpr int ACTION_FIND_DUPLICATES = 10;
constexpr int ACTION_PLAN_ORGANIZE   = 11;
constexpr int ACTION_APPLY_ORGANIZE  = 12;
constexpr int ACTION_GET_CACHED_STATS = 13;

/**
 * Splits a payload string into parts using the given separator.
 * Uses std::vector< std::string > to store the parts.
 * Method: emplace_back - constructs and inserts a new element at the end of the vector,
 *           constructing the element in-place rather than copying or moving an existing object.
 * Example: std::vector<std::string> parts; parts.emplace_back("text");
 * Adds "text" to the end of the vector, constructing the string in-place.
 * 
 * @param payload The string view to split.
 * @param sep Separator character (default '|').
 * @return Vector of string parts split by the separator.
 */
namespace {

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

/**
 * Routes a JNI action ID to its corresponding response string.
 * Uses std::string for building response strings.
 * Uses std::format (C++20) for modern string formatting.
 * Uses std::string_view for non-owning string views.
 * 
 * Available actions and their responses:
 * - ACTION_PING: Returns "PONG: " + payload
 * - ACTION_GET_STATUS: Returns {"status": "ready", "engine": "C++23"}
 * - ACTION_LIST_FILES: Calls wayer::storage::list_files(payload)
 * - ACTION_GET_NETWORK_INFO: Returns {"transfer status": "idle", "protocol" : "raw_sockets"}
 * - ACTION_FILTER_DOCUMENTS: Calls wayer::documents::filter_documents(payload)
 * - ACTION_START_LISTENER: Starts a socket listener on port 8080
 * - ACTION_GET_STORAGE_STATS: Returns storage statistics as JSON
 * - ACTION_SEARCH_FILES: Searches files with root and query
 * - ACTION_FIND_LARGE_FILES: Finds large files with min_bytes and max_results
 * - ACTION_FIND_DUPLICATES: Finds duplicate files
 * - ACTION_PLAN_ORGANIZE: Plans organization of files
 * - ACTION_APPLY_ORGANIZE: Applies organization (pipe-delimited, not JSON)
 * - ACTION_GET_CACHED_STATS: Returns cached or fresh storage stats
 * 
 * @param action_id The action ID to process.
 * @param payload The payload string view containing action-specific data.
 * @return JSON string response for the given action.
 */
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

        case ACTION_GET_STORAGE_STATS:
            return wayer::storage::get_storage_stats(std::string(payload));

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
            auto parts = split_payload(payload); // parts[0]=cache_path, parts[1]=root, parts[2]=max_age_seconds
            if (parts.size() < 3) return R"({"error":"bad_payload"})";
            int max_age = static_cast<int>(std::strtol(parts[2].c_str(), nullptr, 10));

            std::string cached = wayer::storage::read_cache_if_fresh(parts[0], max_age);
            if (!cached.empty()) return cached;

            std::string fresh = wayer::storage::get_storage_stats(parts[1]);
            wayer::storage::write_cache(parts[0], fresh);
            return fresh;
        }
        
        default:
            LOGE("Unknown action_id: %d", action_id);
            return R"({"error": "unknown_action"})";
    }
}

} // namespace

/**
 * JNI initialization function called from Java.
 * Currently logs that the C++ Engine has been initialized using C++23 standard.
 * 
 * Uses LOGI macro for info logging with ANDROID_LOG_INFO.
 * Uses LOGI macro with LOG_TAG "WayerEngine".
 * Indicates the engine is ready to process actions.
 */
extern "C" {

JNIEXPORT void JNICALL
Java_com_example_wayer_core_NativeEngine_initEngine(JNIEnv* /* env */, jclass /* clazz */) {
    LOGI("Wayer C++ Engine Initialized (C++23 Standard)");
}

JNIEXPORT jstring JNICALL
Java_com_example_wayer_core_NativeEngine_processAction(
        JNIEnv* env, jclass /* clazz */, jint action_id, jstring payload) {

    /**
     * JNI process action function that bridges Java and C++ native code.
     * Converts a Java jstring payload to a native std::string, processes the action,
     * and returns a new Java jstring with the response.
     * 
     * Uses JNIEnv::GetStringUTFChars to convert jstring to const char*.
     * Uses JNIEnv::ReleaseStringUTFChars to release the native string.
     * Uses std::string to hold the response string.
     * Creates a new Java jstring with env->NewStringUTF(response.c_str()).
     * 
     * @param env JNI environment pointer.
     * @param clazz Java class reference (unused).
     * @param action_id The action ID to process.
     * @param payload The Java jstring payload containing action data.
     * @return Java jstring with the response JSON string.
     * 
     * Uses std::string to hold the response JSON string.
     * Uses env->GetStringUTFChars / ReleaseStringUTFChars for JNI string handling.
     * Uses env->NewStringUTF to create a new Java jstring from the response.
     */
    const char* native_str = env->GetStringUTFChars(payload, nullptr);
    if (!native_str) return env->NewStringUTF("");

    std::string response = route_action(static_cast<int>(action_id), native_str);

    env->ReleaseStringUTFChars(payload, native_str);
    return env->NewStringUTF(response.c_str());
}

} // extern "C"

#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <cstdlib>
#include "storage/storage_engine.hpp"
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

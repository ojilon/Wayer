#include <jni.h>
#include <android/log.h>
#include <string>
#include <string_view>
#include "storage/storage_engine.hpp"
#include "transfer/transfer_engine.hpp"

#define LOG_TAG "WayerEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Action Identifiers (Match Java UI events)
constexpr int ACTION_PING = 1;
constexpr int ACTION_GET_STATUS = 2;
constexpr int ACTION_LIST_FILES = 3;
constexpr int ACTION_GET_NETWORK_INFO = 4;

namespace {
    // Isolated internal router (keeps JNI layer minimal)
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
            default:
                LOGE("Unknown action_id: %d", action_id);
                return R"({"error": "unknown_action"})";
        }
    }
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_wayer_core_NativeEngine_initEngine(JNIEnv* /* env */, jclass /* clazz */) {
    LOGI("Wayer C++ Engine Initialized (C++23 Standard)");
}

JNIEXPORT jstring JNICALL
Java_com_example_wayer_core_NativeEngine_processAction(JNIEnv* env, jclass /* clazz */, jint action_id, jstring payload) {
    const char* native_str = env->GetStringUTFChars(payload, nullptr);
    if (!native_str) return env->NewStringUTF("");

    std::string_view payload_view(native_str);
    std::string response = route_action(static_cast<int>(action_id), payload_view);

    env->ReleaseStringUTFChars(payload, native_str);
    return env->NewStringUTF(response.c_str());
}

} // extern "C"
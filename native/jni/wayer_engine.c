#include <jni.h>

#include <stddef.h>
#include <stdint.h>

//C ABI -> odin core
extern const char* wayer_route_action(int action_id, const char* payload);
extern void wayer_init_engine(void);

JNIEXPORT void JNICALL
Java_com_example_wayer_bridge_NativeEngine_initEngine(JNIEnv* /* env */, jclass /* clazz */) {
    wayer_init_engine();
}

JNIEXPORT jstring JNICALL
Java_com_example_wayer_bridge_NativeEngine_processAction(
    JNIEnv* env, jclass /* clazz */, jint action_id, jstring payload) {
    const char* native_str = (*env)->GetStringUTFChars(env, payload, NULL);
    if (!native_str) return (*env)->NewStringUTF(env, "");

    const char* response = wayer_route_action((int)action_id, native_str);

    (*env)->ReleaseStringUTFChars(env, payload, native_str);
    return (*env)->NewStringUTF(env, response ? response : "");
}
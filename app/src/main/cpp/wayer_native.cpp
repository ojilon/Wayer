#include <jni.h>
#include <string>

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_wayer_NativeBridge_getEngineVersion(JNIEnv* env, jobject /*this*/) {
    std::string version = "Wayer C++23 Engine v0.0.0";
    return env->NewStringUTF(version.c_str());
}
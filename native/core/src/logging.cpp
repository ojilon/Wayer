// wayer_core — logging facade. See include/wayer/core/logging.hpp.
#include <wayer/core/logging.hpp>

#include <cstdio>
#include <string>

#if defined(__ANDROID__)
#include <android/log.h>
#endif

namespace wayer::core::log {

void info(std::string_view tag, std::string_view msg) {
#if defined(__ANDROID__)
    std::string t(tag), m(msg);
    __android_log_print(ANDROID_LOG_INFO, t.c_str(), "%s", m.c_str());
#else
    std::string t(tag), m(msg);
    std::fprintf(stderr, "[I][%s] %s\n", t.c_str(), m.c_str());
#endif
}

void error(std::string_view tag, std::string_view msg) {
#if defined(__ANDROID__)
    std::string t(tag), m(msg);
    __android_log_print(ANDROID_LOG_ERROR, t.c_str(), "%s", m.c_str());
#else
    std::string t(tag), m(msg);
    std::fprintf(stderr, "[E][%s] %s\n", t.c_str(), m.c_str());
#endif
}

void infof(const char* tag, const char* msg) {
    info(tag != nullptr ? tag : "Wayer", msg != nullptr ? msg : "");
}

void errorf(const char* tag, const char* msg) {
    error(tag != nullptr ? tag : "Wayer", msg != nullptr ? msg : "");
}

} // namespace wayer::core::log

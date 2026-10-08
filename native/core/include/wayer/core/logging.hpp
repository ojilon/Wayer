#pragma once
// wayer_core — thin logging facade (no domain logic).
// Android: forwards to __android_log_print + optional file under app_paths().logs.
// Host builds (unit tests): falls back to stderr.

#include <string_view>

namespace wayer::core::log {

void info(std::string_view tag, std::string_view msg);
void error(std::string_view tag, std::string_view msg);

// printf-style helpers for call sites that already format with {} via std::format.
// Prefer passing a pre-formatted std::string; these just forward.
void infof(const char* tag, const char* msg);
void errorf(const char* tag, const char* msg);

} // namespace wayer::core::log

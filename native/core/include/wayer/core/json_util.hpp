#pragma once
// wayer_core — JSON output helpers (header-only).
// Migrated from native/utils/json_util.hpp. New code must include this file:
//   #include <wayer/core/json_util.hpp>
// and call wayer::core::json::escape().

#include <cstdio>
#include <string>
#include <string_view>

namespace wayer::core::json {

inline std::string escape(std::string_view s) {
    std::string out;
    out.reserve(s.size() + 8);
    for (unsigned char c : s) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:
                if (c < 0x20) {
                    char buf[8]{};
                    std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                    out += buf;
                } else {
                    out += static_cast<char>(c);
                }
        }
    }
    return out;
}

} // namespace wayer::core::json

// Back-compat alias for any out-of-tree call sites still on wayer::json::escape.
namespace wayer::json {
using wayer::core::json::escape;
} // namespace wayer::json

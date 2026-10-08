#pragma once
// wayer_core — JSON output helpers (defined in src/json_util.cpp).
// New code must include this file:
//   #include <wayer/core/json_util.hpp>
// and call wayer::core::json::escape().

#include <string>
#include <string_view>

namespace wayer::core::json {

// Escape one string for embedding inside "..." in hand-written JSON.
std::string escape(std::string_view s);

} // namespace wayer::core::json

// Back-compat alias for any out-of-tree call sites still on wayer::json::escape.
namespace wayer::json {
using wayer::core::json::escape;
} // namespace wayer::json

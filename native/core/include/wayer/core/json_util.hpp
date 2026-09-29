#pragma once
// TARGET: move implementation from native/utils/json_util.hpp here.
// During migration, storage/documents may still include the legacy header.
// Prefer: #include <wayer/core/json_util.hpp>

#include <string>

namespace wayer::core::json {

// Declarations only until utils/json_util.hpp body is moved + .cpp if needed.
// Legacy file is header-only — copy its contents into this header or a .cpp.

inline std::string escape_placeholder(const std::string& s) {
    // Replace by real escape() from utils/json_util.hpp during migration.
    return s;
}

} // namespace wayer::core::json

#pragma once
// wayer_storage — file-backed index over a walked tree.
//
// BUILD_INDEX walks once and spills {"root", "files":[...]} under the app
// cache; INDEX_META and SEARCH_INDEX serve metadata / matches from that file
// so JNI never ships giant strings and search avoids a full tree walk per
// keystroke. Nothing here includes jni.h; JNI only routes into these.
#include <cstddef>
#include <string>

namespace wayer::storage {

// Absolute index path under app_paths().cache ("" when paths uninitialized).
std::string index_file_path();

// Walk root once, spill the listing to the index file.
// Returns {"path","count"} — Java reads the file itself when needed.
std::string build_index(const std::string& root);

// Metadata only, never the listing:
// {"status":"ready","path",...} | {"status":"missing"} |
// {"error":"paths_not_initialized"}.
std::string index_meta();

// Case-insensitive substring search over indexed paths.
// Returns {"query","count","truncated","matches":[...]} capped at max_results.
std::string search_index(const std::string& query, std::size_t max_results);
// Same result written to out_path; reply is {"status":"ok","path":...} only.
std::string search_index_to_file(const std::string& query, std::size_t max_results,
                                 const std::string& out_path);

} // namespace wayer::storage

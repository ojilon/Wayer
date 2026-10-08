#pragma once
// wayer_preview — read-only document/text preview for the in-app viewer.
//
// Rules: this module only READS. No writes, no deletes, no renames, no JNI.
// Java passes an absolute path plus a byte budget; C++ returns a small JSON
// blob. Large files are capped, binary files get metadata without content.
#include <cstddef>
#include <string>

namespace wayer::preview {

// Read up to max_bytes of a text file (0 = default 64 KiB, hard cap 256 KiB).
// Text:   {"path","size","truncated","line_count","lines":[...]}
// Binary: {"path","size","binary":true}  (content withheld, never dumped)
// Errors: {"error":"not_found" | "not_file" | "unreadable"}
std::string read_text_file(const std::string& path, std::size_t max_bytes);

} // namespace wayer::preview

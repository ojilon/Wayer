// =============================================================================
// documents.odin — document discovery via C walk + extension filter
//
// Part of package documents (wayer_documents). Finds documents (.pdf, .epub,
// .docx, .txt, .md) under a root path by walking the tree in C and filtering
// by extension. The C helpers use only bionic-safe calls (no statx).
//
// Why C walk?
//   * The walk must be recursive and exclusion-aware (skip thumbnails etc.).
//   * Odin's core:os walk would hit Android 10 seccomp; C's opendir/readdir
//     is safe.
//   * Buffer is a fixed 64 KiB array so we never allocate a dynamic JSON
//     string in C beyond the temp result.
//
// Output shape (what DocumentActivity parses)
//   Success: {"path":"/sdcard","documents":["/sdcard/a.pdf","/sdcard/b.txt"]}
//   Error:   {"error":"invalid_directory"}
//
// File-backed variant is not yet exposed to Java; the Files/DocumentActivity
// flow uses the inline JSON (small result) and caches via PathCache when
// needed.
//
// Mirrors: wayer::documents::filter_documents in document_engine.cpp
//          doc_filter_helper.c / check_if_directory.c
// =============================================================================

package documents

import "core:fmt"
import "core:strings"
import "core:c"

import core_heart "../../core/src"
import js_util "../../json_utils/src"

// ---------------------------------------------------------------------------
// C ABI — from doc_filter_helper.c / check_if_directory.c
// ---------------------------------------------------------------------------

foreign import doc_c "system:c"

@(default_calling_convention = "c")
foreign doc_c {
	// Returns 1 if path is a directory, 0 otherwise (bionic-safe stat)
	is_directory :: proc(path: cstring) -> c.int ---

	// Walk + filter: fills buf with quoted JSON strings, sets buf_len and first
	// Returns 0 on success, non-zero on error (invalid directory etc.)
	walk_and_filter :: proc(root: cstring, buf: [^]u8, buf_max: c.int, buf_len: ^c.int, first: ^b32) -> i32 ---
}

// Target extensions — mirrors TARGET_EXTENSIONS in C++.
// Lowercased inside C walk, so we just list them for documentation.
TARGET_EXTENSIONS :: [5]string{".pdf", ".epub", ".docx", ".txt", ".md"}

// filter_documents recursively finds documents with target extensions.
// Mirrors wayer::documents::filter_documents
filter_documents :: proc(path: string) -> string {
	if len(path) == 0 {
		return `{"error":"invalid_directory"}`
	}

	c_path := strings.clone_to_cstring(path, context.temp_allocator)
	if is_directory(c_path) == 0 {
		return `{"error":"invalid_directory"}`
	}

	// Pre-allocate 64 KiB buffer for C to write JSON array elements.
	// C writes comma-separated quoted strings: `"a.pdf","b.txt",...`
	BUFFER_SIZE :: 64 * 1024
	c_buffer := make([]u8, BUFFER_SIZE, context.temp_allocator)

	buf_len: c.int = 0
	first_item: b32 = true

	err_code := walk_and_filter(c_path, raw_data(c_buffer), BUFFER_SIZE, &buf_len, &first_item)
	if err_code != 0 {
		return `{"error":"invalid_directory"}`
	}

	// Extract the C-written content (may be empty when no documents found)
	docs_content := string(c_buffer[:buf_len])

	// Build wrapper JSON safely using builder (avoid fmt.tprintf escaping issues)
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, `{"path":"%s","documents":[%s]}`, js_util.json_escape(path), docs_content)

	return strings.to_string(b)
}

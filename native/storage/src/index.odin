// =============================================================================
// index.odin — file-backed index bridge (thin Odin wrapper over index_c.c)
//
// Part of package storage. The heavy lifting (walk → JSON spill, search via
// streaming parser, group-by-day) lives in C (index_c.c) because it needs
// heap-allocated GroupUd (~MB) and NDK readdir/stat on API 29.
// Odin only validates payloads, clamps limits, and forwards via FFI.
//
// Why C for the index?
//   * GroupUd can be up to 32 days × 64 files × ~512 B path ≈ 1 MiB; putting
//     it on Odin's stack would overflow (Android default stack 1 MiB). C
//     malloc's it on the heap.
//   * Walking with readdir/stat must use bionic-safe calls; C does this
//     directly without touching Odin's core:os.
//   * Streaming parser (Stream) reads files.json without loading it all into
//     memory — Java's Transfer search may run over an index with 50k entries.
//
// Actions exposed to wayer_core.odin
//   build_index(root, index_path)               → {"path","count"}
//   index_meta(index_path)                      → {"status":"ready","bytes",...} | missing
//   search_index_to_file(query, max, out, idx)  → {"status":"ok","path"} (matches spilled)
//   group_index_by_day(idx, out, days, per_day) → {"status":"ok","path"}
//
// All `*_to_file` variants keep JNI replies tiny; Java reads the file.
//
// Mirrors: wayer::storage::build_index, index_meta etc. in index.hpp / index_c.c
// =============================================================================

package storage

import "core:c"
import "core:strings"

import fs "../../file_system_bridge/src"

// ---------------------------------------------------------------------------
// C ABI — from native/storage/src/index_c.c / index_c.h
// ---------------------------------------------------------------------------

foreign import index_c "system:c"

@(default_calling_convention = "c")
foreign index_c {
	wayer_build_index          :: proc(root, index_path: cstring) -> cstring ---
	wayer_index_meta           :: proc(index_path: cstring) -> cstring ---
	wayer_search_index_to_file :: proc(query: cstring, max_results: u64, out_path, index_path: cstring) -> cstring ---
	wayer_group_index_by_day   :: proc(index_path, out_path: cstring, max_days, max_per_day: c.int) -> cstring ---
}

// cs is already defined in fs_android.odin (same package) — reuse it.
// To avoid redefinition, we rely on the single `cs` from fs_android.odin.
// If this file declares its own, Odin will error with duplicate. So we use
// the existing one. For documentation we note its signature:
//   cs :: proc(s: string) -> cstring  // clone to cstring on temp_allocator

// ---------------------------------------------------------------------------
// Thin wrappers — validation + clamping before FFI
// ---------------------------------------------------------------------------

// build_index walks root and spills files.json to index_path.
// Returns C reply JSON (caller in wayer_core.odin wraps with reply()).
build_index :: proc(root: string, index_path: string) -> string {
	if len(root) == 0 || len(index_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	return string(wayer_build_index(fs.cs(root), fs.cs(index_path)))
}

// index_meta returns metadata for index_path (bytes, mtime) without the listing.
index_meta :: proc(index_path: string) -> string {
	if len(index_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	return string(wayer_index_meta(fs.cs(index_path)))
}

// search_index_to_file searches index_path for query, spills matches to out_path.
search_index_to_file :: proc(query: string, max_results: u64, out_path: string, index_path: string) -> string {
	if len(out_path) == 0 || len(index_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	limit := max_results
	if limit == 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	return string(wayer_search_index_to_file(fs.cs(query), limit, fs.cs(out_path), fs.cs(index_path)))
}

// group_index_by_day groups index entries by modification day, spills to out_path.
group_index_by_day :: proc(index_path: string, out_path: string, max_days: int, max_per_day: int) -> string {
	if len(index_path) == 0 || len(out_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	days := max_days
	if days <= 0 {
		days = 14
	}
	if days > 32 {
		days = 32
	}
	per_day := max_per_day
	if per_day <= 0 {
		per_day = 50
	}
	if per_day > 64 {
		per_day = 64
	}
	return string(wayer_group_index_by_day(fs.cs(index_path), fs.cs(out_path), c.int(days), c.int(per_day)))
}

// =============================================================================
// stats_db.odin — SQLite history of storage snapshots (best-effort)
//
// Part of package storage. Records each computed stats snapshot to a SQLite DB
// at <cache>/stats/stats.db so Home/Storage can show history later. Failure
// to record never fails the stats call itself (same as C++).
//
// Schema (created on demand)
//   CREATE TABLE IF NOT EXISTS stats_snapshots(
//     root TEXT PRIMARY KEY, total_bytes INTEGER,
//     used_bytes INTEGER, computed_unix INTEGER);
//
// Android 10 / bionic
//   DB lives under the private app cache (<root>/cache/stats/) which is always
//   writable (no scoped-storage permission needed). SQLite is the amalgamation
//   in third_party/sqlite/ — linked via wayer_sqlite3 static lib.
//
// Mirrors: wayer::storage::stats_db_record in native/storage/src/stats_db.cpp
// =============================================================================

package storage

import "core:c"
import "core:strings"

import core_heart "../../core/src"
import fs "../../file_system_bridge/src"

// ---------------------------------------------------------------------------
// SQLite C API — from third_party/sqlite/sqlite3.h (linked via wayer_sqlite3)
// ---------------------------------------------------------------------------

foreign import sqlite "system:c"

@(default_calling_convention = "c")
foreign sqlite {
	sqlite3_open       :: proc(filename: cstring, ppDb: ^^sqlite3) -> c.int ---
	sqlite3_close      :: proc(db: ^sqlite3) -> c.int ---
	sqlite3_exec       :: proc(db: ^sqlite3, sql: cstring, callback: rawptr, arg: rawptr, errmsg: ^cstring) -> c.int ---
	sqlite3_prepare_v2 :: proc(db: ^sqlite3, sql: cstring, nByte: c.int, ppStmt: ^^sqlite3_stmt, pzTail: ^cstring) -> c.int ---
	sqlite3_bind_text  :: proc(stmt: ^sqlite3_stmt, index: c.int, text: cstring, n: c.int, destructor: rawptr) -> c.int ---
	sqlite3_bind_int64 :: proc(stmt: ^sqlite3_stmt, index: c.int, value: i64) -> c.int ---
	sqlite3_step       :: proc(stmt: ^sqlite3_stmt) -> c.int ---
	sqlite3_finalize   :: proc(stmt: ^sqlite3_stmt) -> c.int ---
	sqlite3_errmsg     :: proc(db: ^sqlite3) -> cstring ---
}

sqlite3      :: struct {} // opaque (real fields in sqlite3.c)
sqlite3_stmt :: struct {} // opaque

SQLITE_OK   :: c.int(0)
SQLITE_DONE :: c.int(101)
// SQLITE_TRANSIENT = (sqlite3_destructor_type)-1 — tells SQLite to copy text
SQLITE_TRANSIENT :: rawptr(rawptr(~uintptr(0)))

// ---------------------------------------------------------------------------
// c_time is defined in fs_android.odin (same package storage) — shared here.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// stats_db_record — record snapshot to SQLite
// ---------------------------------------------------------------------------

// stats_db_record inserts/replaces the row for `root` with total/used bytes.
// Returns true on success, false on any error (caller ignores false).
stats_db_record :: proc(root: string, total_bytes: u64, used_bytes: u64) -> bool {
	if len(root) == 0 || !core_heart.is_app_paths_initialized() {
		return false
	}

	cache := core_heart.get_app_paths().cache
	if len(cache) == 0 {
		return false
	}

	// Ensure stats directory exists (private cache → always writable)
	stats_dir := strings.concatenate({cache, "/stats"}, context.temp_allocator)
	if !fs.mkdir_p_c(stats_dir) {
		return false
	}

	db_path := strings.concatenate({stats_dir, "/stats.db"}, context.temp_allocator)
	c_db_path := strings.clone_to_cstring(db_path, context.temp_allocator)

	db: ^sqlite3 = nil
	if sqlite3_open(c_db_path, &db) != SQLITE_OK {
		if db != nil {
			sqlite3_close(db)
		}
		return false
	}
	defer sqlite3_close(db)

	// Create schema if not exists
	schema := "CREATE TABLE IF NOT EXISTS stats_snapshots(root TEXT PRIMARY KEY, total_bytes INTEGER, used_bytes INTEGER, computed_unix INTEGER);"
	c_schema := strings.clone_to_cstring(schema, context.temp_allocator)
	if sqlite3_exec(db, c_schema, nil, nil, nil) != SQLITE_OK {
		return false
	}

	// Prepare insert-or-replace
	insert_sql := "INSERT OR REPLACE INTO stats_snapshots(root, total_bytes, used_bytes, computed_unix) VALUES(?, ?, ?, ?);"
	c_insert := strings.clone_to_cstring(insert_sql, context.temp_allocator)

	stmt: ^sqlite3_stmt = nil
	if sqlite3_prepare_v2(db, c_insert, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)

	// Bind params
	c_root := strings.clone_to_cstring(root, context.temp_allocator)
	if sqlite3_bind_text(stmt, 1, c_root, -1, SQLITE_TRANSIENT) != SQLITE_OK { return false }
	if sqlite3_bind_int64(stmt, 2, i64(total_bytes)) != SQLITE_OK { return false }
	if sqlite3_bind_int64(stmt, 3, i64(used_bytes)) != SQLITE_OK { return false }

	now := fs.c_time(nil)
	if sqlite3_bind_int64(stmt, 4, now) != SQLITE_OK { return false }

	if sqlite3_step(stmt) != SQLITE_DONE {
		return false
	}

	return true
}

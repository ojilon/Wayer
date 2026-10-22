package storage

import "core:c"
import "core:fmt"
import "core:os"
import "core:time"

import core_heart "../../core/src"

// SQLite C API via FFI (sqlite3.c from third_party/sqlite/)
foreign import sqlite "system:c"

@(default_calling_convention = "c")
foreign sqlite {
	sqlite3_open        :: proc(filename: cstring, ppDb: ^*sqlite3) -> c.int ---
	sqlite3_close       :: proc(db: *sqlite3) -> c.int ---
	sqlite3_exec        :: proc(db: *sqlite3, sql: cstring, callback: *c.void, arg: *c.void, errmsg: ^cstring) -> c.int ---
	sqlite3_prepare_v2  :: proc(db: *sqlite3, sql: cstring, nByte: c.int, ppStmt: ^*sqlite3_stmt, pzTail: ^cstring) -> c.int ---
	sqlite3_bind_text   :: proc(stmt: *sqlite3_stmt, index: c.int, text: cstring, n: c.int, destructor: *c.void) -> c.int ---
	sqlite3_bind_int64  :: proc(stmt: *sqlite3_stmt, index: c.int, value: i64) -> c.int ---
	sqlite3_step        :: proc(stmt: *sqlite3_stmt) -> c.int ---
	sqlite3_finalize    :: proc(stmt: *sqlite3_stmt) -> c.int ---
	sqlite3_errmsg      :: proc(db: *sqlite3) -> cstring ---
}

sqlite3 :: opaque {}
sqlite3_stmt :: opaque {}

SQLITE_OK      :: c.int(0)
SQLITE_DONE    :: c.int(101)
SQLITE_TRANSIENT :: *c.void(@ptrCast(-1))

// stats_db_record records a storage stats snapshot to SQLite
// Mirrors wayer::storage::stats_db_record
// Returns true on success, false on failure
stats_db_record :: proc(root: string, total_bytes: u64, used_bytes: u64) -> bool {
	if len(root) == 0 || !core_heart.is_app_paths_initialized() {
		return false
	}

	cache := core_heart.get_app_paths().cache
	if len(cache) == 0 {
		return false
	}

	// Create stats directory
	stats_dir := core_heart.ascii_lower(cache) // reuse cache path
	stats_dir = fmt.tprintf("%s/stats", cache)
	err := os.make_dir(stats_dir)
	if err != nil && err != os.ErrAlreadyExists {
		return false
	}

	db_path := fmt.tprintf("%s/stats.db", stats_dir)
	c_db_path := strings.clone_to_cstring(db_path, context.temp_allocator)

	var db: *sqlite3 = nil
	if sqlite3_open(c_db_path, &db) != SQLITE_OK {
		if db != nil { sqlite3_close(db) }
		return false
	}
	defer sqlite3_close(db)

	// Create schema
	schema := "CREATE TABLE IF NOT EXISTS stats_snapshots(root TEXT PRIMARY KEY, total_bytes INTEGER, used_bytes INTEGER, computed_unix INTEGER);"
	c_schema := strings.clone_to_cstring(schema, context.temp_allocator)
	if sqlite3_exec(db, c_schema, nil, nil, nil) != SQLITE_OK {
		return false
	}

	// Prepare insert
	insert_sql := "INSERT OR REPLACE INTO stats_snapshots(root, total_bytes, used_bytes, computed_unix) VALUES(?, ?, ?, ?);"
	c_insert_sql := strings.clone_to_cstring(insert_sql, context.temp_allocator)

	var stmt: *sqlite3_stmt = nil
	if sqlite3_prepare_v2(db, c_insert_sql, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)

	// Bind parameters
	c_root := strings.clone_to_cstring(root, context.temp_allocator)
	if sqlite3_bind_text(stmt, 1, c_root, -1, SQLITE_TRANSIENT) != SQLITE_OK { return false }
	if sqlite3_bind_int64(stmt, 2, i64(total_bytes)) != SQLITE_OK { return false }
	if sqlite3_bind_int64(stmt, 3, i64(used_bytes)) != SQLITE_OK { return false }

	now: i64 = time.now().unix()
	if sqlite3_bind_int64(stmt, 4, now) != SQLITE_OK { return false }

	if sqlite3_step(stmt) != SQLITE_DONE {
		return false
	}

	return true
}
# Native overview — Odin October 2025 sweep · Android 10 target

> **Branch** `arena/e58556e6-wayer` (off `3db8fbc fix`).  
> **Toolchain** Odin `dev-2025-10` + NDK 29.x + CMake 3.22.1, ABI `arm64-v8a` only.  
> **Scope** Sweep through `native/` → correct Odin syntax, add C wrappers for bionic, add header comments, update README.

---

## 1. Why Odin + C wrappers on Android 10

Android 10 (API 29) has a **seccomp filter that blocks `statx` / `openat2`**. Older Wayer used `core:os` file walks (`os.read_dir`, `os.stat`, `std::filesystem`) which on newer NDKs / Odin versions may emit `statx` — the app would crash with `SIGSYS` on a real Android 10 device.

**Solution in this sweep**

- All Odin file I/O goes through **C wrappers** that call only allowlisted syscalls:

  **`native/core/include/wayer/core/android_fs.h` allowlist**
  ```
  opendir, readdir, closedir (WayerFsDir)
  stat (WayerFsEntry, wayer_fs_stat)
  open/read/write/close (wayer_fs_read_file/write_file)
  mkdir (wayer_fs_mkdir_p — looped mkdir, no mkdirat)
  rename, unlink (wayer_fs_rename/remove)
  wayer_fs_walk_files (recursive C walk, depth 32, path 512, same exclusion rules as safety.cpp)
  time(2), free (for buffers)
  ```

  See `android_fs.c` top comment for the full contract.

- **Odin never imports `core:os` for filesystem**. The `import "core:os"` in a few earlier files is either removed or only used for host fallback (`os.stderr` on non-Android). On Android, `log` goes to `__android_log_print` via `system:c` FFI.

- **Heap, not stack, for large index state** (`index_c.c` `GroupUd` ~ 1 MiB on heap; Odin's default Android thread stack is 1 MiB — putting it on the stack would overflow).

See `native/MODULES.md` for the dependency graph (core ← storage ← documents/transfer, preview leaf, jni links all).

---

## 2. Odin October 2025 syntax fixes

The October 2025 release had two breaking changes that touched every `*.odin` file:

### 2.1 New `core:os` (explicit allocators, `^os.File`)

- Old `os.write_entire_file(path, data)` etc. lost their overloads; new signatures require `allocator` param and return `os.Error`.
- **Fix**: avoid `core:os` for Android file work entirely (use C wrappers). Host code (`logging.odin` stderr fallback) uses `os.stream_from_handle(os.stderr, allocator)` with explicit allocator. `paths.odin` removed all `os.stat` / `os.make_dir` calls in favor of `wayer_fs_*`.

### 2.2 `ODIN_OS` enum, `foreign` + `thread_local` + attributes

| Old (pre-Oct 2025) | October 2025 (this branch) |
|--------------------|-----------------------------|
| `when ODIN_OS == "android"` | `when ODIN_OS == .Android` |
| `foreign { foo :: proc() --- }` (bare) | `foreign import lib "system:c"` then `foreign lib { foo :: proc \"c\" () -> ... --- }` |
| `@(thread_local) buf: [N]u8` before name | `buf: [N]u8` at process scope (Bridge single-thread executor already serializes; no `thread_local` needed — avoids Bionic TLS `__tls_get_addr` quirks) |
| `@(export, cdecl)` | `@(export, link_name="...") proc \"c\" ()` |
| `import core_heart "core:core_heart"` | `import core_heart "../../core/src"` (relative to each file) |
| `c.free`, `std.mem` | `free` from `foreign libc` + `mem.compare/slice_ptr` |
| `sort` package | `slice` package (`slice.sort_by`, `slice.sort`) |

### 2.3 Dynamic literals, `using`

- `map[string]T{}` literals now require `#+feature dynamic-literals`. We use `make(map[string]T, n, allocator)` instead.
- `using` as statement requires `#+feature using-stmt`. We don't use `using` in statement position (only on struct fields where still allowed).

### 2.4 Reply buffer (JNI)

`wayer_core.odin` had `@(thread_local) reply_buffer: [16384]u8`. Replaced with a plain `reply_buffer: [16384]u8` at package scope. Safe because `Bridge.java` runs native file jobs on a **single-thread executor** — only one JNI file job at a time, so no concurrent `reply()` on different threads. This also works on Android 10 where Bionic's `__tls_get_addr` for thread-local in a `.so` loaded without `RTLD_GLOBAL` can fail.

---

## 3. Per-module sweep notes

### `native/core/src/` → package `core_heart`

| File | Fix |
|------|-----|
| `core.odin` | Removed broken `json_util.json_escape` re-exports (same-package symbols are already visible; no `filename.proc` qualifier). Now documents the facade only. |
| `json_util.odin` | Added header block, kept `builder_make(temp_allocator)` + `to_string`. |
| `logging.odin` | Fixed `foreign import libc` + `@(default_calling_convention="c")`, `ODIN_OS == .Android` enum, host fallback to `os.stream_from_handle`. |
| `paths.odin` | **Rewrote** to use `wayer_fs_stat/mkdir_p/write_file` C wrappers (no `os.stat`/`make_dir`). Added normalization, `all_ready` helper, `cstr` helper. Extensive header on layout + bionic. |
| `text.odin` | Fixed `@(export, link_name="ascii_lower_c") proc \"c\"`, removed `os.make_dir`/`write_entire_file` in favor of C wrappers, reordered imports, added docs. |

### `native/storage/src/` → package `storage`

| File | Fix |
|------|-----|
| `fs_android.odin` | **New central bridge** — consolidates `WayerFsDir/Entry`, `cs`, `stat_c`, `mkdir_p_c`, `write_file_c`, `read_file_c` (copies malloc'd C buffer to Odin heap then `free`), `walk_files_c` with package-scope `walk_trampoline` (Odin forbids nested `extern "c" fn`). Also exports `c_time` (via `time(2)`) for `cache.odin`/`stats_db`. |
| `storage.odin` | Stripped broken re-exports (`Category :: extension_map.Category`). Now a facade doc (Odin same-package symbols need no aliases). |
| `extension_map.odin` | Kept but added full header + kept 16-byte stack buffer for lowercasing (no alloc). |
| `safety.odin` | Added header mapping to `is_excluded_name` in `index_c.c`. |
| `walker.odin` | Fixed `WayerDir`/`WayerDirEntry` to `dir_walk_android.c` structs (had mismatched `size` field), `top` key cloning, `is_excluded_dir` call. |
| `stats_json.odin` | Fixed `FolderStat`/`StorageNumbers` doc + `core_heart` import path + loop index form. |
| `cache.odin` | Removed `os.*` usage, uses `stat_c`/`mkdir_p_c`/`write_file_c` + `c_time` from `fs_android` for `max_age` check (1 MiB read cap). |
| `analyse_storage_space.odin` | Uses `statvfs` via `system:c` FFI (LP64 struct), `scan_dir` walker, `slice.sort_by`, `max()` for retail floor fallback. Writes via `write_file_c`. |
| `list_files.odin` | Uses `WayerFsDir` (not `core:os.read_dir`), `WayerFsEntry` with `name_len`, `core_heart.json_escape`. |
| `search.odin` | Fixed `WayerWalkResult` foreign import, `wayer_walk_directory` return convention (0=fail), `strings.clone` for entry names, `builder_make` result. |
| `cleaner.odin` | **Large rewrite** — replaced `c.free`/`std.mem.eql`/`io.Reader` with `mem.compare`, `slice.sort_by`, `FNV-1a` over `[]u8`, context structs for walk callbacks (`DupWalkCtx`, `LargeAccum`), `walk_files_with_ctx` + `walk_ctx_inner` trampoline (avoids nested `extern "c"`). Group logic unchanged (size → partial hash → full hash → byte-equal). |
| `organizer.odin` | Fixed `date_bucket` via `stat_c` + `time.unix`/`time.date`, `category_for_name` check, walk via `walk_files_with_ctx`, manual JSON scanner with `find_json_string_end`/`unescape_json_string`, `mkdir_p_c`/`rename_c` with dup suffix, report JSON via builder. |
| `index.odin` | Thin FFI wrapper — validates, clamps `max_results` to 1..200, `max_days` 1..32, forwards to `index_c.c` procs. No bare `foreign {}`. |
| `stats_db.odin` | Kept SQLite FFI (`sqlite3_*`), removed duplicate `c_time` (now from `fs_android`), `mkdir_p_c` for `stats/` dir. |

### `native/documents/src/` → `documents`

Fixed `context.allocator = allocator` typo (now uses `context.temp_allocator`), `BUFFER_SIZE` constant, `strings.clone_to_cstring` for `path`, builder for wrapper JSON.

### `native/transfer/src/` → `transfer`

Removed bogus `SockAddrIn` etc. (not used — C does the socket), kept only `wayer_transfer_bind_test` FFI, `AF_INET`-style constants removed (C handles them).

### `native/preview/src/` → `preview`

Fixed to use `storage.stat_c`/`read_file_c` (not `storage.fs.*` qualifier), `strings.builder_make` for `lines_json`, `core_heart.bool_to_string` for `truncated`, handles empty path.

### `native/media/src/` → `media`

Minimal stub doc; keeps `media_module_anchor` so `wayer_media` CMake target is not empty.

### `native/odin/wayer_core.odin` → `wayer_core` (only package CMake builds)

| Fix |
|-----|
| `foreign import index_c "system:c"` + `foreign index_c { wayer_build_index ... }` (was bare `foreign {}`) |
| `reply_buffer: [16384]u8` not `thread_local` (see §2.4) |
| `ODIN_OS == .Android` enum |
| `all_digits` handles empty, `split_trailing_number` for `path|max_bytes` |
| `init_app_paths` canonical `/wayer` suffix, `core_heart.ensure_app_dirs` + `set_app_paths` via C wrappers |
| `route_action` switch covers all 14 action IDs, clamps `max_results`/`max_days`, uses `storage.read_cache_if_fresh` fast path |
| All `wayer_*` exports use `proc \"c\"` + `context = runtime.default_context()` + `defer free_all(temp_allocator)` + `reply()` pattern |
| Added `wayer_media_anchor` export so `wayer_media` not stripped |

---

## 4. C wrappers — what fights bionic and how we abstract it

### `native/core/src/android_fs.c` / `include/wayer/core/android_fs.h`

| Proc | Syscall(s) | Used from |
|------|-----------|-----------|
| `wayer_fs_opendir/readdir/closedir` | `opendir`/`readdir`/`stat`/`closedir` | `fs_android.odin`, `walker.odin`, `list_files.odin` |
| `wayer_fs_walk_files` | recursive `opendir`/`stat` depth 32, path 512 | `fs_android.odin` `walk_files_c`, `search.odin` (via `collect_data.c`), `cleaner`, `organizer` |
| `wayer_fs_stat` | `stat(2)` only | `paths.odin`, `cache.odin`, `preview`, `stats_db` |
| `wayer_fs_mkdir_p` | looped `mkdir(2)` | `paths.odin`, `cache`, `organizer`, `stats_db` |
| `wayer_fs_write_file` | `open(WRONLY|CREAT|TRUNC)` + `write` loop | `paths.odin`, `text.odin`, `cache`, `analyse_storage_space` |
| `wayer_fs_read_file` | `open`+`fstat`+`read` loop (malloc result) | `fs_android` `read_file_c`, `preview`, `organizer`, `cleaner` reads |
| `wayer_fs_rename/remove` | `rename(2)`/`unlink(2)` | `fs_android` `rename_c`/`remove_c` |
| `wayer_fs_stat` (size/mtime/is_dir) | `stat` + `S_ISDIR`/`S_ISREG` | everywhere that needs metadata |

**Excluded** (never called): `statx`, `openat`, `openat2`, `fstatat`, `getdents64` directly — anything in bionic's seccomp blocklist for API 29.

### `native/storage/src/index_c.c` / `index_c.h`

- File-backed index: `BUILD_INDEX` walks once → `files.json` (`{"root","files":[...]}`) under `app cache`.
- `SEARCH_INDEX` / `GROUP_INDEX_BY_DAY` are streaming parsers (`Stream` 8 KiB buf) — never load full `files.json` into memory.
- `GroupUd` (~1 MiB heap via `malloc`, not stack) — prevents thread stack overflow on 50k-file indexes.

### `native/shim/odin_bionic_shim.h` (new thin header)

Documents the contract above so future Odin files know to include `android_fs.h` and not reach for `core:os`.

---

## 5. How to add more native code on this branch

1. Drop `foo.odin` anywhere under `native/` (e.g. `native/storage/src/foo.odin`).
2. Make it `package storage` (or the owning module's package) so `storage.odin` façade covers it.
3. Import it from an already-imported package (`wayer_core.odin` imports `storage`) so CMake's `GLOB_RECURSE` + `CONFIGURE_DEPENDS` picks it up without editing `CMakeLists.txt`.
4. For filesystem: call `stat_c`/`walk_files_c`/etc. from `fs_android.odin` — never `os.*`.
5. For large replies: write to a file under `core_heart.get_app_paths().cache` and return `{status, path}`; Java reads via `PathCache.readFile`.
6. Document the proc's JNI action ID in `NativeEngine.java` + `wayer_core.odin` header.

Build:

```bash
odin check native/odin                 # syntax check
cmake -S native -B /tmp/b -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=29 -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake
cmake --build /tmp/b --target wayer_engine
```


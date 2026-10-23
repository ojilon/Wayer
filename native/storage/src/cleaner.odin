// cleaner.odin — large files + duplicate detection (C FS backend)
// Uses android_fs.c for bionic-safe directory walks and file I/O.

package storage

import "core:c"
import "core:crypto/fnv"
import "core:fmt"
import "core:hash"
import "core:io"
import "core:sort"
import "core:strings"
import "core:time"

import core_heart "../../core/src"



// =============================================================================
// LARGE FILES
// =============================================================================

LargeEntry :: struct {
	name: string,
	path: string,
	size: u64,
}

// find_large_files returns JSON with top N largest files
// Mirrors wayer::storage::find_large_files
find_large_files :: proc(root_path: string, min_bytes: u64, max_results: int) -> string {
	if max_results <= 0 { max_results = 50 }
	if min_bytes == 0 { min_bytes = 10 * 1024 * 1024 } // 10 MB default
	
	found: []LargeEntry
	
	// Walk and collect large files using C FS
	fs.walk_files_c(root_path, proc(path: string, name: string, size: i64, mtime: i64) {
		if size < i64(min_bytes) { return }
		
		found = append(found, LargeEntry{
			name = name,
			path = path,
			size = u64(size),
		}, context.temp_allocator)
	})
	
	// Sort by size descending (top N)
	sort.sort_by(found[:], proc(a, b: LargeEntry) -> bool { return a.size > b.size })
	
	want := min(max_results, len(found))
	top := found[:want]
	
	// Build JSON
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, `{"min_bytes":%d,"count":%d,"files":[`, min_bytes, len(top))
	
	for i, entry in top {
		if i > 0 { strings.write_string(&sb, ",") }
		fmt.sbprintf(&sb, `{"name":"%s","path":"%s","size":%d}`,
			core_heart.json_escape(entry.name),
			core_heart.json_escape(entry.path),
			entry.size)
	}
	
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// find_large_files_to_file writes results to file
// Mirrors wayer::storage::find_large_files_to_file
find_large_files_to_file :: proc(root_path: string, min_bytes: u64, max_results: int, out_path: string) -> string {
	json := find_large_files(root_path, min_bytes, max_results)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(out_path))
}

// =============================================================================
// DUPLICATES
// =============================================================================

DupFile :: struct {
	path: string,
	size: u64,
	mtime: i64, // unix seconds, 0 = unknown
}

// FNV-1a 64-bit hash over a stream, up to max_bytes
fnv1a_stream :: proc(reader: io.Reader, max_bytes: u64) -> u64 {
	const kOffset = 14695981039346656037
	const kPrime = 1099511628211
	
	h := u64(kOffset)
	buf: [8192]u8
	remaining := max_bytes
	
	for remaining > 0 {
		want := min(int(remaining), len(buf))
		n, err := reader.read(buf[:want])
		if err != nil || n == 0 { break }
		
		for i := 0; i < n; i++ {
			h ^= u64(buf[i])
			h *= kPrime
		}
		remaining -= u64(n)
	}
	
	return h
}

// try_partial_hash computes hash of first 4 KiB mixed with size
// Returns (hash, success)
try_partial_hash :: proc(path: string, size: u64) -> (u64, bool) {
	// Use C FS to read file
	data, ok := fs.read_file_c(path, 4096)
	if !ok { return 0, false }
	
	h := fnv1a_stream(io.reader_from_slice(data), u64(data.len))
	h ^= size * 0x9E3779B97F4A7C15
	return h, true
}

// try_full_hash computes full FNV-1a hash of file
// Returns (hash, success)
try_full_hash :: proc(path: string) -> (u64, bool) {
	data, ok := fs.read_file_c(path, usize.MAX)
	if !ok { return 0, false }
	
	h := fnv1a_stream(io.reader_from_slice(data), u64(data.len))
	return h, true
}

// files_byte_equal compares two files byte-by-byte
files_byte_equal :: proc(a: string, b: string) -> bool {
	data_a, ok_a := fs.read_file_c(a, usize.MAX)
	if !ok_a { return false }
	defer c.free(data_a.ptr) // need to free if malloc'd
	
	data_b, ok_b := fs.read_file_c(b, usize.MAX)
	if !ok_b { return false }
	defer c.free(data_b.ptr)
	
	return std.mem.eql(u8, data_a, data_b)
}

// file_mtime_unix returns file modification time as unix seconds
file_mtime_unix :: proc(path: string) -> i64 {
	_, mtime, _, ok := fs.stat_c(path)
	if !ok { return 0 }
	return mtime
}

// file_size_or_zero returns file size or 0 on error
file_size_or_zero :: proc(path: string) -> u64 {
	size, _, _, ok := fs.stat_c(path)
	if !ok { return 0 }
	return u64(size)
}

// =============================================================================
// Related files (display only)
// =============================================================================

ends_with_word :: proc(s: string, word: string) -> bool {
	if len(s) < len(word) { return false }
	return s[len(s)-len(word):] == word
}

trim_trailing_space_dash :: proc(s: string, out: *string) {
	end := len(s)
	for end > 0 {
		ch := s[end-1]
		if ch == ' ' || ch == '\t' || ch == '-' || ch == '_' || ch == '.' {
			end--
		} else {
			break
		}
	}
	*out = s[:end]
}

// normalize_related_key normalizes a filename for related-file grouping
// Mirrors the C++ normalize_related_key
normalize_related_key :: proc(filename: string) -> string {
	lower := core_heart.ascii_lower(filename)
	dot := strings.last_index_byte(lower, '.')
	base := lower
	if dot > 0 {
		base = lower[:dot]
	}
	
	cur := base
	trim_trailing_space_dash(cur, &cur)
	
	for iter := 0; iter < 5; iter++ {
		trim_trailing_space_dash(cur, &cur)
		if len(cur) == 0 { break }
		
		// Trailing "(digits)" like " (1)" or "(12)"
		if len(cur) > 0 && cur[len(cur)-1] == ')' {
			open := strings.last_index_byte(cur, '(')
			if open != -1 && open+1 < len(cur) {
				all_digits := true
				for i := open + 1; i+1 < len(cur); i++ {
					if cur[i] < '0' || cur[i] > '9' {
						all_digits = false
						break
					}
				}
				if all_digits {
					cur = cur[:open]
					continue
				}
			}
			break
		}
		
		if ends_with_word(cur, "copy") {
			pos := len(cur) - 4
			if pos > 0 && (cur[pos-1] == ' ' || cur[pos-1] == '-' || cur[pos-1] == '_' || cur[pos-1] == '(') {
				cur = cur[:pos-1]
				continue
			}
			break
		}
		
		if ends_with_word(cur, "final") {
			pos := len(cur) - 5
			if pos > 0 && (cur[pos-1] == ' ' || cur[pos-1] == '-' || cur[pos-1] == '_') {
				cur = cur[:pos-1]
				continue
			}
			break
		}
		
		// Trailing v-number: " v2", "_v2", "-v2", "v2"
		n := len(cur)
		d := n
		for d > 0 && cur[d-1] >= '0' && cur[d-1] <= '9' {
			d--
		}
		if d < n && d > 0 && (cur[d-1] == 'v' || cur[d-1] == 'V') {
			vpos := d - 1
			if vpos == 0 { cur = ""; break }
			sep := cur[vpos-1]
			if sep == ' ' || sep == '-' || sep == '_' || vpos == 0 {
				if vpos > 0 && (sep == ' ' || sep == '-' || sep == '_') {
					cur = cur[:vpos-1]
				} else {
					cur = cur[:vpos]
				}
				continue
			}
		}
		break
	}
	
	trim_trailing_space_dash(cur, &cur)
	return cur
}

// find_duplicates returns JSON with duplicate groups and related groups
// Mirrors wayer::storage::find_duplicates
find_duplicates :: proc(root_path: string) -> string {
	// Step 1: group by size
	by_size: map[u64][]string = make(map[u64][]string, context.temp_allocator)
	
	fs.walk_files_c(root_path, proc(path: string, name: string, size: i64, mtime: i64) {
		if size <= 0 { return }
		u := u64(size)
		by_size[u] = append(by_size[u], path, context.temp_allocator)
	})
	
	// Step 2: within each size group, group by partial hash
	duplicate_groups: [][]DupFile
	
	for size, paths in by_size {
		if len(paths) < 2 { continue }
		
		by_partial: map[u64][]string = make(map[u64][]string, context.temp_allocator)
		for path in paths {
			h, ok := try_partial_hash(path, size)
			if !ok { continue }
			by_partial[h] = append(by_partial[h], path, context.temp_allocator)
		}
		
		// Step 3: confirm with full hash only for partial-hash collisions
		for _, candidates in by_partial {
			if len(candidates) < 2 { continue }
			
			by_full: map[u64][]string = make(map[u64][]string, context.temp_allocator)
			for path in candidates {
				h, ok := try_full_hash(path)
				if !ok { continue }
				by_full[h] = append(by_full[h], path, context.temp_allocator)
			}
			
			for _, same_hash in by_full {
				if len(same_hash) < 2 { continue }
				
				// Hash is only a hint: split by real byte content
				verified: [][]string
				for path in same_hash {
					placed := false
					for v in verified {
						if files_byte_equal(v[0], path) {
							v = append(v, path, context.temp_allocator)
							placed = true
							break
						}
					}
					if !placed {
						verified = append(verified, []string{path}, context.temp_allocator)
					}
				}
				
				for v in verified {
					if len(v) < 2 { continue }
					group: []DupFile
					for path in v {
						group = append(group, DupFile{
							path = path,
							size = size,
							mtime = file_mtime_unix(path),
						}, context.temp_allocator)
					}
					duplicate_groups = append(duplicate_groups, group, context.temp_allocator)
				}
			}
		}
	}
	
	// Sort duplicate groups
	for g in duplicate_groups {
		sort.sort_by(g[:], proc(a, b: DupFile) -> bool { return a.path < b.path })
	}
	sort.sort_by(duplicate_groups[:], proc(a, b: []DupFile) -> bool { return a[0].path < b[0].path })
	
	// Related files: same normalized name, any size/version. Display only.
	by_related: map[string][]string = make(map[string][]string, context.temp_allocator)
	for size, paths in by_size {
		for path in paths {
			fname := strings.split(path, "/", context.temp_allocator)[-1]
			if len(fname) == 0 { continue }
			key := normalize_related_key(fname)
			if len(key) < 3 { continue }
			by_related[key] = append(by_related[key], path, context.temp_allocator)
		}
	}
	
	RelatedGroup :: struct {
		key: string,
		files: []DupFile,
	}
	
	related: []RelatedGroup
	keys: []string
	for k in by_related {
		if len(by_related[k]) >= 2 && len(by_related[k]) <= 20 {
			keys = append(keys, k, context.temp_allocator)
		}
	}
	sort.sort(keys[:])
	
	const kMaxRelatedGroups = 200
	const kMaxFilesPerRelated = 20
	
	for k in keys {
		if len(related) >= kMaxRelatedGroups { break }
		paths := by_related[k]
		sort.sort(paths[:])
		want := min(len(paths), kMaxFilesPerRelated)
		
		g := RelatedGroup{key = k}
		for i := 0; i < want; i++ {
			g.files = append(g.files, DupFile{
				path = paths[i],
				size = file_size_or_zero(paths[i]),
				mtime = file_mtime_unix(paths[i]),
			}, context.temp_allocator)
		}
		related = append(related, g, context.temp_allocator)
	}
	
	// Build JSON
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"version":2,"duplicate_groups":[`)
	
	for gi, group in duplicate_groups {
		strings.write_string(&sb, "[")
		for i, f in group {
			if i > 0 { strings.write_string(&sb, ",") }
			fmt.sbprintf(&sb, `{"path":"%s","size":%d,"mtime":%d}`,
				core_heart.json_escape(f.path), f.size, f.mtime)
		}
		strings.write_string(&sb, "]")
		if gi+1 < len(duplicate_groups) { strings.write_string(&sb, ",") }
	}
	
	strings.write_string(&sb, `],"related_groups":[`)
	
	for gi, group in related {
		if gi > 0 { strings.write_string(&sb, ",") }
		fmt.sbprintf(&sb, `{"key":"%s","files":[`, core_heart.json_escape(group.key))
		for i, f in group.files {
			if i > 0 { strings.write_string(&sb, ",") }
			fmt.sbprintf(&sb, `{"path":"%s","size":%d,"mtime":%d}`,
				core_heart.json_escape(f.path), f.size, f.mtime)
		}
		strings.write_string(&sb, "]}")
	}
	
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// find_duplicates_to_file writes results to file
// Mirrors wayer::storage::find_duplicates_to_file
find_duplicates_to_file :: proc(root_path: string, out_path: string) -> string {
	json := find_duplicates(root_path)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(out_path))
}
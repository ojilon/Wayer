package storage

import "core:os"
import "core:strings"

// Everything the walk accumulates. Passing ^Scan around replaces the C++ lambda capture.
Scan :: struct {
	categories: [Category]u64,
	top_dirs:   map[string]u64,
}

// `top` is the name of the top-level folder we are inside.
// "" means we're directly in the root, so files here count toward categories only.
scan_dir :: proc(scan: ^Scan, dir: string, top: string) {
	fd, open_err := os.open(dir)
	if open_err != nil { return } // unreadable folder: skip it, like the C++ error_code path

	infos, read_err := os.read_dir(fd, -1, context.allocator) // -1 = read everything
	os.close(fd)
	if read_err != nil { return }
	defer os.file_info_slice_delete(infos, context.allocator) // free this folder's entries before returning

	for info in infos {
		if info.type == .Directory {
			if is_excluded_dir(info.name, dir) { continue }

			child := strings.concatenate({dir, "/", info.name}, context.temp_allocator)
			// Directly under root, each child folder starts a new "top" folder.
			// Deeper down, keep the one we already have.
			child_top := top if top != "" else info.name
			scan_dir(scan, child, child_top)
			continue
		}

		// optional but recommended: only count real files (skips symlinks, sockets, pipes)
		if info.type != .Regular { continue }

		size := u64(max(info.size, 0))
		scan.categories[category_for_name(info.name)] += size

		if top != "" {
			if top not_in scan.top_dirs {
				// `top` points into memory freed after this folder, so the map key needs its own copy
				scan.top_dirs[strings.clone(top, context.temp_allocator)] = 0
			}
			scan.top_dirs[top] += size
		}
	}
}

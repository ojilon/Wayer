#ifndef WAYER_INDEX_C_H
#define WAYER_INDEX_C_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * File-backed index (C + bionic only — no statx).
 *
 * Index JSON shape:
 *   {"root":"...","files":[{"path":"...","size":N,"mtime":Unix,"kind":"image"},...]}
 *
 * All functions return a pointer to a thread-local buffer (valid until next call
 * on the same thread). Never free it.
 */

/* Walk root → write index_path. Reply: {"path":"...","count":N} or {"error":"..."} */
const char *wayer_build_index(const char *root, const char *index_path);

/* Stat the index file. Reply: ready | missing | error */
const char *wayer_index_meta(const char *index_path);

/* Substring search on each file's path (case-insensitive ASCII).
 * Writes result JSON to out_path. Reply: {"status":"ok","path":"..."} */
const char *wayer_search_index_to_file(const char *query, uint64_t max_results, const char *out_path,
                                       const char *index_path);

/* Read index_path, group by local calendar day (mtime), write out_path.
 * Reply: {"status":"ok","path":"..."} */
const char *wayer_group_index_by_day(const char *index_path,
                                     const char *out_path,
                                     int max_days,
                                     int max_per_day);

#ifdef __cplusplus
}
#endif
#endif
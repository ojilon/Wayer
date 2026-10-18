/* C bridge for directory listing on Android.
 * Uses only opendir/readdir/stat — no statx (blocked by Android 10 seccomp).
 * Called from Odin via foreign import.
 */
#ifndef WAYER_DIR_WALK_ANDROID_H
#define WAYER_DIR_WALK_ANDROID_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One entry returned to Odin. name is UTF-8, not necessarily NUL-padded beyond name_len. */
typedef struct WayerDirEntry {
    const char *name;     /* points into internal buffer; valid until next next() or close */
    size_t      name_len;
    int         is_dir;   /* 1 = directory, 0 = regular file, -1 = other/unknown */
    int64_t     size;     /* byte size for files; 0 for dirs */
} WayerDirEntry;

/* Opaque directory handle */
typedef struct WayerDir WayerDir;

/* Open directory at path (NUL-terminated). Returns NULL on failure. */
WayerDir *wayer_dir_open(const char *path);

/* Write next entry into *out. Returns 1 if ok, 0 if end or error. */
int wayer_dir_next(WayerDir *dir, WayerDirEntry *out);

/* Close and free. Safe to call with NULL. */
void wayer_dir_close(WayerDir *dir);

#ifdef __cplusplus
}
#endif

#endif /* WAYER_DIR_WALK_ANDROID_H */

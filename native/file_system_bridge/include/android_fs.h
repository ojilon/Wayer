#ifndef WAYER_ANDROID_FS_H
#define WAYER_ANDROID_FS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- single directory entry (no statx) ---- */
typedef struct WayerFsEntry {
    const char *name;       /* valid until next next() or close */
    size_t      name_len;
    int         is_dir;     /* 1 dir, 0 file, -1 other */
    int64_t     size;       /* files only */
    int64_t     mtime;      /* unix seconds */
} WayerFsEntry;

typedef struct WayerFsDir WayerFsDir;

/* Open directory for reading */
WayerFsDir *wayer_fs_opendir(const char *path);

/* Read next entry; returns 1 on success, 0 on end/error.
 * Output 'out' points to internal buffer valid until next readdir/close. */
int wayer_fs_readdir(WayerFsDir *d, WayerFsEntry *out);

/* Close directory handle */
void wayer_fs_closedir(WayerFsDir *d);

/* ---- recursive walk callback (heap-friendly, depth-limited) ---- */
typedef void (*WayerFsFileCb)(const char *path, const char *name,
                              int64_t size, int64_t mtime, void *ud);

/* Walk files under root, calling cb for each regular file.
 * Skips excluded names (thumbnails, Android/data, etc.).
 * Returns number of files visited (or 0 on error). */
int wayer_fs_walk_files(const char *root, WayerFsFileCb cb, void *ud);

/* ---- path ops (bionic-safe) ---- */
int wayer_fs_stat(const char *path, int64_t *size_out, int64_t *mtime_out, int *is_dir_out);
int wayer_fs_mkdir_p(const char *path);                    /* 0 ok */
int wayer_fs_write_file(const char *path, const void *data, size_t n);

/* Returns malloc'd buffer + sets *n_out; caller free(); NULL on error.
 * Reads up to max_bytes (0 = no limit). */
char *wayer_fs_read_file(const char *path, size_t max_bytes, size_t *n_out);

int wayer_fs_rename(const char *from, const char *to);
int wayer_fs_remove(const char *path);

#ifdef __cplusplus
}
#endif

#endif /* WAYER_ANDROID_FS_H */
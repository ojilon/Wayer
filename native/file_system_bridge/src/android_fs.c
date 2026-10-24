/*
 * android_fs.c — bionic-safe FS for Odin (Android 10+).
 * Only opendir/readdir/stat/open/read/write/mkdir/rename/unlink.
 * Never statx.
 */
#include "../include/android_fs.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define WAYER_PATH_MAX 512
#define WAYER_MAX_DEPTH 32

struct WayerFsDir {
    DIR *dp;
    char prefix[WAYER_PATH_MAX];
    size_t prefix_len;
    char name_buf[256];
};

/* Check if a directory name should be excluded from scans */
static int excluded_name(const char *name, const char *parent_name) {
    if (!name) return 1;
    if (!strcmp(name, ".") || !strcmp(name, "..")) return 1;
    if (!strcmp(name, ".thumbnails") || !strcmp(name, "thumbnails")) return 1;
    if (!strcmp(name, ".trashed") || !strcmp(name, ".trash")) return 1;
    if (!strcmp(name, ".cache") || !strcmp(name, "LOST.DIR")) return 1;
    if (!strcmp(name, ".dwayer_cache") || !strcmp(name, "wayer_trash") ||
        !strcmp(name, ".wayer_trash"))
        return 1;
    if (parent_name && !strcmp(parent_name, "Android") &&
        (!strcmp(name, "data") || !strcmp(name, "obb")))
        return 1;
    return 0;
}

/* Extract parent directory name for exclusion checks */
static void parent_name_of(const char *path, char *out, size_t out_sz) {
    out[0] = 0;
    const char *slash = strrchr(path, '/');
    if (!slash || slash == path) return;
    const char *start = slash;
    while (start > path && start[-1] != '/') start--;
    size_t n = (size_t)(slash - start);
    if (n >= out_sz) n = out_sz - 1;
    memcpy(out, start, n);
    out[n] = 0;
}

WayerFsDir *wayer_fs_opendir(const char *path) {
    if (!path || !path[0]) return NULL;
    DIR *dp = opendir(path);
    if (!dp) return NULL;
    WayerFsDir *d = calloc(1, sizeof(*d));
    if (!d) { closedir(dp); return NULL; }
    d->dp = dp;
    size_t n = strlen(path);
    if (n >= WAYER_PATH_MAX - 2) { closedir(dp); free(d); return NULL; }
    memcpy(d->prefix, path, n);
    if (n > 0 && path[n - 1] != '/') d->prefix[n++] = '/';
    d->prefix[n] = 0;
    d->prefix_len = n;
    return d;
}

int wayer_fs_readdir(WayerFsDir *d, WayerFsEntry *out) {
    if (!d || !d->dp || !out) return 0;
    for (;;) {
        struct dirent *ent = readdir(d->dp);
        if (!ent) return 0;
        if (ent->d_name[0] == '.' &&
            (ent->d_name[1] == 0 || (ent->d_name[1] == '.' && ent->d_name[2] == 0)))
            continue;
        size_t nl = strlen(ent->d_name);
        if (nl >= sizeof(d->name_buf)) continue;
        memcpy(d->name_buf, ent->d_name, nl + 1);

        char full[WAYER_PATH_MAX];
        if (d->prefix_len + nl + 1 > sizeof(full)) continue;
        memcpy(full, d->prefix, d->prefix_len);
        memcpy(full + d->prefix_len, ent->d_name, nl + 1);

        struct stat st;
        if (stat(full, &st) != 0) continue;

        out->name = d->name_buf;
        out->name_len = nl;
        out->size = 0;
        out->mtime = (int64_t)st.st_mtime;
        out->is_dir = -1;
        if (S_ISDIR(st.st_mode)) out->is_dir = 1;
        else if (S_ISREG(st.st_mode)) {
            out->is_dir = 0;
            out->size = (int64_t)st.st_size;
        }
        return 1;
    }
}

void wayer_fs_closedir(WayerFsDir *d) {
    if (!d) return;
    if (d->dp) closedir(d->dp);
    free(d);
}

/* Recursive walk helper */
static void walk_rec(const char *dir, unsigned depth, WayerFsFileCb cb, void *ud) {
    if (depth > WAYER_MAX_DEPTH) return;
    DIR *dp = opendir(dir);
    if (!dp) return;

    char parent[256];
    parent_name_of(dir, parent, sizeof(parent));

    struct dirent *ent;
    while ((ent = readdir(dp)) != NULL) {
        if (excluded_name(ent->d_name, parent)) continue;

        char full[WAYER_PATH_MAX];
        if ((size_t)snprintf(full, sizeof(full), "%s/%s", dir, ent->d_name) >= sizeof(full))
            continue;

        struct stat st;
        if (stat(full, &st) != 0) continue;

        if (S_ISDIR(st.st_mode)) {
            walk_rec(full, depth + 1, cb, ud);
            continue;
        }
        if (!S_ISREG(st.st_mode)) continue;
        cb(full, ent->d_name, (int64_t)st.st_size, (int64_t)st.st_mtime, ud);
    }
    closedir(dp);
}

int wayer_fs_walk_files(const char *root, WayerFsFileCb cb, void *ud) {
    if (!root || !cb) return 0;
    walk_rec(root, 0, cb, ud);
    return 1; /* walk started successfully */
}

int wayer_fs_stat(const char *path, int64_t *size_out, int64_t *mtime_out, int *is_dir_out) {
    struct stat st;
    if (!path || stat(path, &st) != 0) return -1;
    if (size_out) *size_out = (int64_t)st.st_size;
    if (mtime_out) *mtime_out = (int64_t)st.st_mtime;
    if (is_dir_out) *is_dir_out = S_ISDIR(st.st_mode) ? 1 : 0;
    return 0;
}

int wayer_fs_mkdir_p(const char *path) {
    if (!path || !path[0]) return -1;
    char tmp[WAYER_PATH_MAX];
    size_t len = strlen(path);
    if (len >= sizeof(tmp)) return -1;
    memcpy(tmp, path, len + 1);
    for (size_t i = 1; i < len; i++) {
        if (tmp[i] == '/') {
            tmp[i] = 0;
            mkdir(tmp, 0755);
            tmp[i] = '/';
        }
    }
    return mkdir(tmp, 0755) == 0 || errno == EEXIST ? 0 : -1;
}

int wayer_fs_write_file(const char *path, const void *data, size_t n) {
    if (!path) return -1;
    /* ensure parent directory exists */
    char dir[WAYER_PATH_MAX];
    snprintf(dir, sizeof(dir), "%s", path);
    char *slash = strrchr(dir, '/');
    if (slash) { *slash = 0; wayer_fs_mkdir_p(dir); }

    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return -1;
    const char *p = (const char *)data;
    size_t left = n;
    while (left) {
        ssize_t w = write(fd, p, left);
        if (w < 0) { close(fd); return -1; }
        p += (size_t)w;
        left -= (size_t)w;
    }
    close(fd);
    return 0;
}

/* Returns malloc'd buffer + sets *n_out; caller free(); NULL on error.
 * Reads up to max_bytes (0 = no limit). */
char *wayer_fs_read_file(const char *path, size_t max_bytes, size_t *n_out) {
    if (n_out) *n_out = 0;
    int fd = open(path, O_RDONLY);
    if (fd < 0) return NULL;
    struct stat st;
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) { close(fd); return NULL; }
    size_t n = (size_t)st.st_size;
    if (max_bytes > 0 && n > max_bytes) n = max_bytes;
    char *buf = malloc(n + 1);
    if (!buf) { close(fd); return NULL; }
    size_t got = 0;
    while (got < n) {
        ssize_t r = read(fd, buf + got, n - got);
        if (r <= 0) break;
        got += (size_t)r;
    }
    close(fd);
    buf[got] = 0;
    if (n_out) *n_out = got;
    return buf;
}

int wayer_fs_rename(const char *from, const char *to) {
    return rename(from, to) == 0 ? 0 : -1;
}

int wayer_fs_remove(const char *path) {
    return unlink(path) == 0 ? 0 : -1;
}
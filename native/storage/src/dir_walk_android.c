/*
 * Android-safe directory walk (bionic only).
 * Avoids statx — required for Android 10 seccomp.
 */
#include "wayer/storage/dir_walk_android.h"

#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <limits.h>

struct WayerDir {
    DIR  *dp;
    char  path_prefix[PATH_MAX];  /* "parent/" for building child paths */
    size_t path_prefix_len;
    char  name_buf[256];          /* last entry name (for Odin pointer) */
};

WayerDir *wayer_dir_open(const char *path) {
    if (!path || !path[0]) return NULL;

    DIR *dp = opendir(path);
    if (!dp) return NULL;

    WayerDir *d = (WayerDir *)calloc(1, sizeof(WayerDir));
    if (!d) {
        closedir(dp);
        return NULL;
    }

    d->dp = dp;

    /* Build "path/" prefix for stat() of children */
    size_t n = strlen(path);
    if (n >= PATH_MAX - 2) {
        closedir(dp);
        free(d);
        return NULL;
    }
    memcpy(d->path_prefix, path, n);
    if (n > 0 && path[n - 1] != '/') {
        d->path_prefix[n++] = '/';
    }
    d->path_prefix[n] = '\0';
    d->path_prefix_len = n;

    return d;
}

int wayer_dir_next(WayerDir *dir, WayerDirEntry *out) {
    if (!dir || !dir->dp || !out) return 0;

    for (;;) {
        struct dirent *ent = readdir(dir->dp);
        if (!ent) return 0;

        /* Skip . and .. */
        if (ent->d_name[0] == '.' &&
            (ent->d_name[1] == '\0' ||
             (ent->d_name[1] == '.' && ent->d_name[2] == '\0'))) {
            continue;
        }

        size_t name_len = strlen(ent->d_name);
        if (name_len >= sizeof(dir->name_buf)) continue; /* skip absurd names */

        memcpy(dir->name_buf, ent->d_name, name_len + 1);

        /* Full path for stat */
        char full[PATH_MAX];
        if (dir->path_prefix_len + name_len + 1 > sizeof(full)) continue;
        memcpy(full, dir->path_prefix, dir->path_prefix_len);
        memcpy(full + dir->path_prefix_len, ent->d_name, name_len + 1);

        struct stat st;
        if (stat(full, &st) != 0) continue;

        out->name     = dir->name_buf;
        out->name_len = name_len;
        out->size     = 0;
        out->is_dir   = -1;

        if (S_ISDIR(st.st_mode)) {
            out->is_dir = 1;
        } else if (S_ISREG(st.st_mode)) {
            out->is_dir = 0;
            out->size   = (int64_t)st.st_size;
        }

        return 1;
    }
}

void wayer_dir_close(WayerDir *dir) {
    if (!dir) return;
    if (dir->dp) closedir(dir->dp);
    free(dir);
}
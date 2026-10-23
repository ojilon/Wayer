
#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

typedef struct {
    char *name;
    char *path;
    int is_dir;
    int is_file;
    int is_symlink;
} WayerWalkEntry;

typedef struct {
    WayerWalkEntry *entries;
    size_t count;
    size_t capacity;
} WayerWalkResult;

static char *copy_text(const char *text){
    size_t len = strlen(text);
    char *copy = malloc(len + 1);

    if (copy != NULL) {
        memcpy(copy, text, len + 1);
    }

    return copy;
}

static int add_entry(WayerWalkResult *result, const char *name, const char *path,
    int is_dir,  int is_file,   int is_symlink) {
    
    if (result->count == result->capacity) {
        size_t next = result->capacity == 0
            ? 32
            : result->capacity * 2;

        if (next > SIZE_MAX / sizeof(WayerWalkEntry)) {
            return 0;
        }

        void *memory = realloc(
            result->entries,
            next * sizeof(WayerWalkEntry)
        );

        if (memory == NULL) {
            return 0;
        }

        result->entries = memory;
        result->capacity = next;
    }

    char *name_copy = copy_text(name);
    char *path_copy = copy_text(path);

    if (name_copy == NULL || path_copy == NULL) {
        free(name_copy);
        free(path_copy);
        return 0;
    }

    result->entries[result->count++] = (WayerWalkEntry) {
        .name = name_copy,
        .path = path_copy,
        .is_dir = is_dir,
        .is_file = is_file,
        .is_symlink = is_symlink,
    };

    return 1;
}

static int walk_directory( const char *root, WayerWalkResult *result, unsigned int depth) {
    // Prevent unbounded recursion through deeply nested trees.
    if (depth > 256) {
        return 1;
    }

    DIR *dir = opendir(root);
    if (dir == NULL) {
        return 1; // Skip inaccessible directories.
    }

    struct dirent *entry;
    int ok = 1;

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        size_t root_len = strlen(root);
        size_t name_len = strlen(entry->d_name);
        int slash = root_len > 0 && root[root_len - 1] != '/';

        if (root_len > SIZE_MAX - name_len - (size_t)slash - 1) {
            ok = 0;
            break;
        }

        size_t path_len = root_len + (size_t)slash + name_len;
        char *path = malloc(path_len + 1);

        if (path == NULL) {
            ok = 0;
            break;
        }

        snprintf(path, path_len + 1, "%s%s%s", root, slash ? "/" : "", entry->d_name);

        struct stat info;
        if (lstat(path, &info) != 0) {
            free(path);
            continue;
        }

        int is_link = S_ISLNK(info.st_mode);
        int is_dir = S_ISDIR(info.st_mode);
        int is_file = S_ISREG(info.st_mode);

        if (!add_entry(result, entry->d_name, path, is_dir, is_file, is_link)) {
            free(path);
            ok = 0;
            break;
        }

        // Do not follow symlinks.
        if (is_dir && !is_link) {
            if (!walk_directory(path, result, depth + 1)) {
                free(path);
                ok = 0;
                break;
            }
        }

        free(path);
    }

    closedir(dir);
    return ok;
}

int wayer_walk_directory(    const char *root,     WayerWalkResult *result){
    if (root == NULL || result == NULL) {
        return 0;
    }

    memset(result, 0, sizeof(*result));

    if (!walk_directory(root, result, 0)) {
        return 0;
    }

    return 1;
}

void wayer_walk_free(WayerWalkResult *result)
{
    if (result == NULL) {
        return;
    }

    for (size_t i = 0; i < result->count; i++) {
        free(result->entries[i].name);
        free(result->entries[i].path);
    }

    free(result->entries);
    memset(result, 0, sizeof(*result));
}

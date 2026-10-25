#include <bits/strcasecmp.h>
#include <stddef.h>
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

//extension helper, returns 1 if path matches valise extensions
static int is_target_extension(const char *filename) {
    const char *dot = strrchr(filename, '.');
    if (!dot) return 0;

    if(strcasecmp(dot, ".pdf") == 0) return 1;
    if(strcasecmp(dot, ".docx") == 0) return 1;
    if(strcasecmp(dot, ".txt") == 0) return 1;
    if(strcasecmp(dot, ".md") == 0) return 1;
    return 0;
}

// Escapes basic JSON characters into buffer
static void json_escape(const char *src, char *dst, size_t dst_max) {
    size_t j = 0;
    for (size_t i = 0; src[i] != '\0' && j < dst_max - 2; i++) {
        if (src[i] == '"' || src[i] == '\\') {
            dst[j++] = '\\';
        }
        dst[j++] = src[i];
    }
    dst[j] = '\0';
}

int walk_and_filter(const char *root, char *buf, size_t buf_max, size_t *buf_len, int *first){
    DIR *dir = opendir(root);
    if(!dir) return -1;

    struct dirent *entry;
    struct stat st;
    char full_path[1024];

    while((entry = readdir(dir)) != NULL){
        //skip the directory navigation loops
        if(strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0){
            continue;
        }

        // Construct full path
        snprintf(full_path, sizeof(full_path), "%s/%s", root, entry->d_name);
        
        // Bionic-safe stat call (does not use statx!)
        if (stat(full_path, &st) != 0) continue;
        
        if (S_ISDIR(st.st_mode)) {
            // Recursively walk subdirectories
            walk_and_filter(full_path, buf, buf_max, buf_len, first);
            } else if (S_ISREG(st.st_mode) && is_target_extension(entry->d_name)) {
            // Found a target document! Append to JSON buffer
            char esc_name[512];
            char esc_path[1024];
            json_escape(entry->d_name, esc_name, sizeof(esc_name));
            json_escape(full_path, esc_path, sizeof(esc_path));
        
            char item_buf[2048];
            int written = snprintf(item_buf, sizeof(item_buf), 
                    "%s{\"name\":\"%s\",\"path\":\"%s\",\"size\":%lld}",
                     (*first) ? "" : ",", esc_name, esc_path, (long long)st.st_size);
        
            *first = 0; // Toggle first item delimiter flag
        
            // Ensure buffer doesn't overflow
            if (*buf_len + written < buf_max - 64) {
                    strcpy(buf + *buf_len, item_buf);
                     *buf_len += written;
            }
        }        
    }

    closedir(dir);
    return 0;
}
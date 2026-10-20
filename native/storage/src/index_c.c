/*
 * index_c.c — file-backed index + search + group-by-day (C only).
 * Uses opendir/readdir/stat only (Android 10 seccomp safe — no statx).
 *
 * Stack safety:
 *  - GroupUd is heap-allocated (~few MB); never on the thread stack.
 *  - walk_dir uses a depth limit and smaller path buffers.
 */
#include "wayer/storage/index_c.h"

#include <ctype.h>
#include <dirent.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

/* Shorter than PATH_MAX so recursion and heap structs stay small */
#define WAYER_PATH_MAX 512
#define WAYER_MAX_WALK_DEPTH 32

#define MAX_DAY_FILES 64
#define MAX_DAYS_CAP  32

/* ---------- thread-local reply (never free) ---------- */
static __thread char g_reply[512];

static const char *reply_fmt(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_reply, sizeof(g_reply), fmt, ap);
    va_end(ap);
    return g_reply;
}

/* ---------- json escape into FILE ---------- */
static void json_escape_fp(FILE *fp, const char *s) {
    if (!s) return;
    for (; *s; ++s) {
        unsigned char c = (unsigned char)*s;
        switch (c) {
        case '"':  fputs("\\\"", fp); break;
        case '\\': fputs("\\\\", fp); break;
        case '\b': fputs("\\b", fp); break;
        case '\f': fputs("\\f", fp); break;
        case '\n': fputs("\\n", fp); break;
        case '\r': fputs("\\r", fp); break;
        case '\t': fputs("\\t", fp); break;
        default:
            if (c < 0x20) fprintf(fp, "\\u%04x", c);
            else fputc((int)c, fp);
        }
    }
}

/* ---------- kind from extension ---------- */
static const char *kind_from_name(const char *name) {
    const char *dot = strrchr(name, '.');
    if (!dot || !dot[1]) return "other";
    char ext[16];
    size_t n = 0;
    for (const char *p = dot; *p && n < sizeof(ext) - 1; ++p)
        ext[n++] = (char)tolower((unsigned char)*p);
    ext[n] = 0;
    if (!strcmp(ext, ".jpg") || !strcmp(ext, ".jpeg") || !strcmp(ext, ".png") ||
        !strcmp(ext, ".webp") || !strcmp(ext, ".gif") || !strcmp(ext, ".heic") ||
        !strcmp(ext, ".bmp"))
        return "image";
    if (!strcmp(ext, ".mp4") || !strcmp(ext, ".mkv") || !strcmp(ext, ".avi") ||
        !strcmp(ext, ".webm") || !strcmp(ext, ".3gp") || !strcmp(ext, ".mov"))
        return "video";
    if (!strcmp(ext, ".mp3") || !strcmp(ext, ".wav") || !strcmp(ext, ".flac") ||
        !strcmp(ext, ".m4a") || !strcmp(ext, ".ogg") || !strcmp(ext, ".aac"))
        return "audio";
    if (!strcmp(ext, ".pdf") || !strcmp(ext, ".txt") || !strcmp(ext, ".doc") ||
        !strcmp(ext, ".docx") || !strcmp(ext, ".xls") || !strcmp(ext, ".xlsx") ||
        !strcmp(ext, ".md") || !strcmp(ext, ".py") || !strcmp(ext, ".csv"))
        return "document";
    if (!strcmp(ext, ".apk") || !strcmp(ext, ".obb"))
        return "foreign";
    return "other";
}

/* ---------- excluded directory names (mirror safety.cpp) ---------- */
static int is_excluded_name(const char *name, const char *parent_name) {
    if (!name) return 1;
    if (!strcmp(name, ".thumbnails") || !strcmp(name, "thumbnails")) return 1;
    if (!strcmp(name, ".trashed") || !strcmp(name, ".trash")) return 1;
    if (!strcmp(name, ".cache") || !strcmp(name, "LOST.DIR")) return 1;
    if (!strcmp(name, ".dwayer_cache") || !strcmp(name, "wayer_trash") ||
        !strcmp(name, ".wayer_trash"))
        return 1;
    if (!strcmp(name, "data") && parent_name && !strcmp(parent_name, "Android")) return 1;
    if (!strcmp(name, "obb") && parent_name && !strcmp(parent_name, "Android")) return 1;
    return 0;
}

/* last component of the parent directory of path */
static void parent_folder_name(const char *path, char *out, size_t out_sz) {
    out[0] = 0;
    if (!path || out_sz == 0) return;
    const char *slash = strrchr(path, '/');
    if (!slash || slash == path) return;
    const char *end = slash;
    const char *start = slash;
    while (start > path && *(start - 1) != '/') start--;
    size_t n = (size_t)(end - start);
    if (n >= out_sz) n = out_sz - 1;
    memcpy(out, start, n);
    out[n] = 0;
}

static const char *basename_c(const char *path) {
    const char *s = strrchr(path, '/');
    return s ? s + 1 : path;
}

/* ---------- recursive walk → append JSON objects to fp ---------- */
struct WalkCtx {
    FILE *fp;
    int first;
    size_t count;
};

static void walk_dir(struct WalkCtx *ctx, const char *dir, int depth) {
    if (!ctx || !dir || depth > WAYER_MAX_WALK_DEPTH) return;

    DIR *dp = opendir(dir);
    if (!dp) return;

    char parent_name[256];
    parent_folder_name(dir, parent_name, sizeof(parent_name));

    struct dirent *ent;
    while ((ent = readdir(dp)) != NULL) {
        if (ent->d_name[0] == '.' &&
            (ent->d_name[1] == 0 ||
             (ent->d_name[1] == '.' && ent->d_name[2] == 0)))
            continue;

        if (is_excluded_name(ent->d_name, parent_name))
            continue;

        char full[WAYER_PATH_MAX];
        if ((size_t)snprintf(full, sizeof(full), "%s/%s", dir, ent->d_name) >= sizeof(full))
            continue;

        struct stat st;
        if (stat(full, &st) != 0) continue;

        if (S_ISDIR(st.st_mode)) {
            walk_dir(ctx, full, depth + 1);
            continue;
        }
        if (!S_ISREG(st.st_mode)) continue;

        if (!ctx->first) fputc(',', ctx->fp);
        ctx->first = 0;

        fprintf(ctx->fp, "{\"path\":\"");
        json_escape_fp(ctx->fp, full);
        fprintf(ctx->fp, "\",\"size\":%lld,\"mtime\":%lld,\"kind\":\"%s\"}",
                (long long)st.st_size,
                (long long)st.st_mtime,
                kind_from_name(ent->d_name));
        ctx->count++;
    }
    closedir(dp);
}

/* ---------- BUILD ---------- */
const char *wayer_build_index(const char *root, const char *index_path) {
    if (!root || !root[0] || !index_path || !index_path[0])
        return reply_fmt("{\"error\":\"bad_payload\"}");

    /* mkdir parent of index_path */
    char dirbuf[WAYER_PATH_MAX];
    if ((size_t)snprintf(dirbuf, sizeof(dirbuf), "%s", index_path) >= sizeof(dirbuf))
        return reply_fmt("{\"error\":\"path_too_long\"}");

    char *slash = strrchr(dirbuf, '/');
    if (slash) {
        *slash = 0;
        char tmp[WAYER_PATH_MAX];
        size_t len = strlen(dirbuf);
        for (size_t i = 1; i < len; i++) {
            if (dirbuf[i] == '/') {
                memcpy(tmp, dirbuf, i);
                tmp[i] = 0;
                mkdir(tmp, 0755);
            }
        }
        mkdir(dirbuf, 0755);
    }

    FILE *fp = fopen(index_path, "wb");
    if (!fp) return reply_fmt("{\"error\":\"index_write_failed\"}");

    fputs("{\"root\":\"", fp);
    json_escape_fp(fp, root);
    fputs("\",\"files\":[", fp);

    struct WalkCtx ctx = {.fp = fp, .first = 1, .count = 0};
    walk_dir(&ctx, root, 0);

    fputs("]}", fp);
    if (fclose(fp) != 0) return reply_fmt("{\"error\":\"index_write_failed\"}");

    return reply_fmt("{\"path\":\"%s\",\"count\":%zu}", index_path, ctx.count);
}

/* ---------- META ---------- */
const char *wayer_index_meta(const char *index_path) {
    if (!index_path || !index_path[0])
        return reply_fmt("{\"error\":\"bad_payload\"}");

    struct stat st;
    if (stat(index_path, &st) != 0)
        return reply_fmt("{\"status\":\"missing\"}");

    return reply_fmt(
        "{\"status\":\"ready\",\"path\":\"%s\",\"bytes\":%lld,\"modified_unix\":%lld}",
        index_path, (long long)st.st_size, (long long)st.st_mtime);
}

/* ---------- streaming helpers for search / group ---------- */
typedef struct {
    FILE *fp;
    char buf[8192];
    size_t pos, len;
} Stream;

static int stream_next(Stream *s, char *c) {
    if (s->pos >= s->len) {
        size_t n = fread(s->buf, 1, sizeof(s->buf), s->fp);
        if (n == 0) return 0;
        s->len = n;
        s->pos = 0;
    }
    *c = s->buf[s->pos++];
    return 1;
}

static int parse_json_string(Stream *s, char *out, size_t out_sz) {
    size_t n = 0;
    char c;
    while (stream_next(s, &c)) {
        if (c == '"') {
            if (out_sz) out[n < out_sz ? n : out_sz - 1] = 0;
            return 1;
        }
        if (c == '\\') {
            if (!stream_next(s, &c)) return 0;
            switch (c) {
            case '"': case '\\': case '/': break;
            case 'n': c = '\n'; break;
            case 'r': c = '\r'; break;
            case 't': c = '\t'; break;
            default: break;
            }
        }
        if (n + 1 < out_sz) out[n++] = c;
        else n++;
    }
    return 0;
}

static void ascii_lower_inplace(char *s) {
    for (; *s; ++s)
        if (*s >= 'A' && *s <= 'Z') *s = (char)(*s - 'A' + 'a');
}

/* Skip to "files" then '[' */
static int seek_files_array(Stream *s) {
    char c, lit[64];
    while (stream_next(s, &c)) {
        if (c != '"') continue;
        if (!parse_json_string(s, lit, sizeof(lit))) return 0;
        if (strcmp(lit, "files") != 0) continue;
        while (stream_next(s, &c)) {
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
            if (c != ':') return 0;
            break;
        }
        while (stream_next(s, &c)) {
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
            return c == '[';
        }
    }
    return 0;
}

typedef void (*FileCb)(const char *path, long long size, long long mtime,
                       const char *kind, void *ud);

static void foreach_index_file(Stream *s, FileCb cb, void *ud) {
    if (!seek_files_array(s)) return;
    char c;
    char path[WAYER_PATH_MAX];
    char kind[32];
    char key[32];

    while (stream_next(s, &c)) {
        if (c == ']') return;
        if (c == ',' || c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;

        /* old format: plain string path */
        if (c == '"') {
            if (!parse_json_string(s, path, sizeof(path))) return;
            cb(path, 0, 0, "other", ud);
            continue;
        }
        if (c != '{') return;

        path[0] = 0;
        snprintf(kind, sizeof(kind), "other");
        long long size = 0, mtime = 0;

        while (stream_next(s, &c)) {
            if (c == '}') break;
            if (c == ',' || c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
            if (c != '"') return;
            if (!parse_json_string(s, key, sizeof(key))) return;

            /* skip to value */
            while (stream_next(s, &c)) {
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
                if (c == ':') {
                    while (stream_next(s, &c)) {
                        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
                        break;
                    }
                }
                break;
            }

            if (c == '"') {
                char val[WAYER_PATH_MAX];
                if (!parse_json_string(s, val, sizeof(val))) return;
                if (!strcmp(key, "path")) snprintf(path, sizeof(path), "%s", val);
                else if (!strcmp(key, "kind")) snprintf(kind, sizeof(kind), "%s", val);
            } else {
                char num[32];
                size_t ni = 0;
                if (c == '-' || (c >= '0' && c <= '9')) {
                    num[ni++] = c;
                    while (stream_next(s, &c)) {
                        if ((c >= '0' && c <= '9')) {
                            if (ni + 1 < sizeof(num)) num[ni++] = c;
                        } else break;
                    }
                }
                num[ni] = 0;
                long long v = atoll(num);
                if (!strcmp(key, "size")) size = v;
                else if (!strcmp(key, "mtime")) mtime = v;
                if (c == '}') break;
            }
        }
        if (path[0]) cb(path, size, mtime, kind, ud);
    }
}

/* ---------- SEARCH ---------- */
struct SearchUd {
    FILE *out;
    char q_lower[256];
    uint64_t max_results;
    uint64_t total, kept;
    int first_match;
};

static void search_cb(const char *path, long long size, long long mtime,
                      const char *kind, void *ud) {
    (void)size; (void)mtime; (void)kind;
    struct SearchUd *su = (struct SearchUd *)ud;
    char tmp[WAYER_PATH_MAX];
    snprintf(tmp, sizeof(tmp), "%s", path);
    ascii_lower_inplace(tmp);
    if (su->q_lower[0] && strstr(tmp, su->q_lower) == NULL) return;
    su->total++;
    if (su->kept >= su->max_results) return;
    if (!su->first_match) fputc(',', su->out);
    su->first_match = 0;
    fputc('"', su->out);
    json_escape_fp(su->out, path);
    fputc('"', su->out);
    su->kept++;
}

const char *wayer_search_index_to_file(const char *query, uint64_t max_results,
                                       const char *out_path, const char *index_path) {
    if (!out_path || !out_path[0] || !index_path || !index_path[0])
        return reply_fmt("{\"error\":\"bad_payload\"}");
    if (max_results == 0) max_results = 50;
    if (max_results > 200) max_results = 200;

    FILE *in = fopen(index_path, "rb");
    FILE *out = fopen(out_path, "wb");
    if (!out) {
        if (in) fclose(in);
        return reply_fmt("{\"error\":\"write_failed\"}");
    }

    struct SearchUd su;
    memset(&su, 0, sizeof(su));
    su.out = out;
    su.max_results = max_results;
    su.first_match = 1;
    if (query) {
        snprintf(su.q_lower, sizeof(su.q_lower), "%s", query);
        ascii_lower_inplace(su.q_lower);
    }

    fputs("{\"query\":\"", out);
    json_escape_fp(out, query ? query : "");
    fputs("\",\"matches\":[", out);

    if (in) {
        Stream st = {.fp = in, .pos = 0, .len = 0};
        foreach_index_file(&st, search_cb, &su);
        fclose(in);
    }

    fprintf(out, "],\"count\":%llu,\"truncated\":%s}",
            (unsigned long long)su.total,
            su.total > su.kept ? "true" : "false");
    fclose(out);
    return reply_fmt("{\"status\":\"ok\",\"path\":\"%s\"}", out_path);
}

/* ---------- GROUP BY DAY (heap — do NOT put on stack) ---------- */
struct DayFile {
    char path[WAYER_PATH_MAX];
    char name[128];
    char kind[16];
    long long size;
    long long mtime;
};

struct DayBucket {
    char day[16]; /* YYYY-MM-DD */
    int n;
    struct DayFile files[MAX_DAY_FILES];
};

struct GroupUd {
    struct DayBucket days[MAX_DAYS_CAP];
    int ndays;
    int max_per_day;
};

static void day_from_mtime(long long mtime, char *out, size_t out_sz) {
    time_t t = (time_t)mtime;
    struct tm tm;
    localtime_r(&t, &tm);
    strftime(out, out_sz, "%Y-%m-%d", &tm);
}

static void group_cb(const char *path, long long size, long long mtime,
                     const char *kind, void *ud) {
    struct GroupUd *g = (struct GroupUd *)ud;
    if (mtime <= 0 || !path || !path[0]) return;

    char day[16];
    day_from_mtime(mtime, day, sizeof(day));

    struct DayBucket *b = NULL;
    for (int i = 0; i < g->ndays; i++) {
        if (!strcmp(g->days[i].day, day)) {
            b = &g->days[i];
            break;
        }
    }
    if (!b) {
        if (g->ndays >= MAX_DAYS_CAP) return;
        b = &g->days[g->ndays++];
        memset(b, 0, sizeof(*b));
        snprintf(b->day, sizeof(b->day), "%s", day);
    }

    if (b->n < g->max_per_day) {
        struct DayFile *f = &b->files[b->n++];
        snprintf(f->path, sizeof(f->path), "%s", path);
        snprintf(f->name, sizeof(f->name), "%s", basename_c(path));
        snprintf(f->kind, sizeof(f->kind), "%s", kind ? kind : "other");
        f->size = size;
        f->mtime = mtime;
    } else {
        int oldest = 0;
        for (int i = 1; i < b->n; i++)
            if (b->files[i].mtime < b->files[oldest].mtime) oldest = i;
        if (mtime > b->files[oldest].mtime) {
            struct DayFile *f = &b->files[oldest];
            snprintf(f->path, sizeof(f->path), "%s", path);
            snprintf(f->name, sizeof(f->name), "%s", basename_c(path));
            snprintf(f->kind, sizeof(f->kind), "%s", kind ? kind : "other");
            f->size = size;
            f->mtime = mtime;
        }
    }
}

static int day_cmp_desc(const void *a, const void *b) {
    return strcmp(((const struct DayBucket *)b)->day,
                  ((const struct DayBucket *)a)->day);
}

static int file_mtime_desc(const void *a, const void *b) {
    long long da = ((const struct DayFile *)a)->mtime;
    long long db = ((const struct DayFile *)b)->mtime;
    if (db > da) return 1;
    if (db < da) return -1;
    return 0;
}

const char *wayer_group_index_by_day(const char *index_path, const char *out_path,
                                     int max_days, int max_per_day) {
    if (!index_path || !index_path[0] || !out_path || !out_path[0])
        return reply_fmt("{\"error\":\"bad_payload\"}");
    if (max_days <= 0) max_days = 14;
    if (max_days > MAX_DAYS_CAP) max_days = MAX_DAYS_CAP;
    if (max_per_day <= 0) max_per_day = 50;
    if (max_per_day > MAX_DAY_FILES) max_per_day = MAX_DAY_FILES;

    FILE *in = fopen(index_path, "rb");
    if (!in) return reply_fmt("{\"error\":\"index_missing\"}");

    /* Heap only — this struct is multi-MB; stack causes SIGSEGV on Android */
    struct GroupUd *g = (struct GroupUd *)calloc(1, sizeof(struct GroupUd));
    if (!g) {
        fclose(in);
        return reply_fmt("{\"error\":\"oom\"}");
    }
    g->max_per_day = max_per_day;

    Stream st = {.fp = in, .pos = 0, .len = 0};
    foreach_index_file(&st, group_cb, g);
    fclose(in);

    qsort(g->days, (size_t)g->ndays, sizeof(g->days[0]), day_cmp_desc);
    int use_days = g->ndays < max_days ? g->ndays : max_days;

    FILE *out = fopen(out_path, "wb");
    if (!out) {
        free(g);
        return reply_fmt("{\"error\":\"write_failed\"}");
    }

    fputs("{\"status\":\"ok\",\"days\":[", out);
    for (int d = 0; d < use_days; d++) {
        struct DayBucket *b = &g->days[d];
        qsort(b->files, (size_t)b->n, sizeof(b->files[0]), file_mtime_desc);
        if (d) fputc(',', out);
        fputs("{\"day\":\"", out);
        json_escape_fp(out, b->day);
        fputs("\",\"files\":[", out);
        for (int i = 0; i < b->n; i++) {
            if (i) fputc(',', out);
            fputs("{\"path\":\"", out);
            json_escape_fp(out, b->files[i].path);
            fputs("\",\"name\":\"", out);
            json_escape_fp(out, b->files[i].name);
            fprintf(out, "\",\"size\":%lld,\"mtime\":%lld,\"kind\":\"%s\"}",
                    b->files[i].size, b->files[i].mtime, b->files[i].kind);
        }
        fputs("]}", out);
    }
    fputs("]}", out);
    fclose(out);
    free(g);
    return reply_fmt("{\"status\":\"ok\",\"path\":\"%s\"}", out_path);
}
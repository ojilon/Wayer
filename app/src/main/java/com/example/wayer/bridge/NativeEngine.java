package com.example.wayer.bridge;

public class NativeEngine {

    // Action IDs must match native/jni/wayer_engine.cpp.
    public static final int ACTION_PING = 1;
    public static final int ACTION_GET_STATUS = 2;
    public static final int ACTION_LIST_FILES = 3;
    public static final int ACTION_GET_NETWORK_INFO = 4;
    public static final int ACTION_FILTER_DOCUMENTS = 5;
    public static final int ACTION_START_LISTENER = 6;
    public static final int ACTION_GET_STORAGE_STATS = 7;
    public static final int ACTION_SEARCH_FILES = 8;
    public static final int ACTION_FIND_LARGE_FILES = 9;
    public static final int ACTION_FIND_DUPLICATES = 10;
    public static final int ACTION_PLAN_ORGANIZE = 11;
    public static final int ACTION_APPLY_ORGANIZE = 12;
    public static final int ACTION_GET_CACHED_STATS = 13;
    public static final int ACTION_INIT_APP_PATHS = 14;
    public static final int ACTION_BUILD_INDEX = 15;
    public static final int ACTION_INVALIDATE_CACHE = 16;
    public static final int ACTION_INDEX_META = 17;
    public static final int ACTION_SEARCH_INDEX = 18;
    public static final int ACTION_READ_TEXT_FILE = 19;

    public interface Callback {
        void onResult(String result);
    }

    public static native void initEngine();
    public static native String processAction(int actionId, String payload);

    static {
        System.loadLibrary("wayer_engine");
    }

    /** Pass the private app root once so native cache/temp/logs stay off shared storage. */
    public static void initAppPathsAsync(android.content.Context context, Callback callback) {
        String root = "";
        try {
            root = AppDirs.privateRoot(context).getAbsolutePath();
        } catch (Exception ignored) {
            java.io.File filesDir = context.getFilesDir();
            root = filesDir != null ? filesDir.getAbsolutePath() : "";
        }
        processActionAsync(ACTION_INIT_APP_PATHS, root, rawJson -> {
            PathRegistry.update(context, rawJson);
            callback.onResult(rawJson);
        });
    }

    /** Walk root once, spill the listing to the native index file; returns {path, count}. */
    public static void buildIndexAsync(String root, Callback callback) {
        Bridge.run(ACTION_BUILD_INDEX, root != null ? root : "", "native-index", "index", callback);
    }

    /** Metadata about the native index file ({status, path, bytes, modified_unix}). */
    public static void indexMetaAsync(Callback callback) {
        processActionAsync(ACTION_INDEX_META, "", callback);
    }

    /** Index search; matches go to outPath, reply is {status,path}. */
    public static void searchIndexAsync(String query, int maxResults, String outPath, Callback callback) {
        Bridge.run(ACTION_SEARCH_INDEX,
                (outPath != null ? outPath : "") + "|" + maxResults + "|" + (query != null ? query : ""),
                outPath, "search", callback);
    }

    /** Live file-name search; matches go to outPath, reply is {status,path}. */
    public static void searchFilesAsync(String root, String query, String outPath, Callback callback) {
        Bridge.run(ACTION_SEARCH_FILES,
                (root != null ? root : "") + "|" + (outPath != null ? outPath : "")
                        + "|" + (query != null ? query : ""),
                outPath, "search", callback);
    }

    /** Duplicate scan with file output. */
    public static void findDuplicatesAsync(String root, String outPath, Callback callback) {
        Bridge.run(ACTION_FIND_DUPLICATES,
                (root != null ? root : "") + "|" + (outPath != null ? outPath : ""),
                outPath, "duplicates", callback);
    }

    /** Organize plan into a file; reply is {status,path}. */
    public static void planOrganizeAsync(String root, String outPath, Callback callback) {
        Bridge.run(ACTION_PLAN_ORGANIZE,
                (root != null ? root : "") + "|" + (outPath != null ? outPath : ""),
                outPath, "organize", callback);
    }

    /** Execute a plan file into a report file; reply is {status,path}. */
    public static void applyOrganizeAsync(String planPath, String reportPath, Callback callback) {
        Bridge.run(ACTION_APPLY_ORGANIZE,
                (planPath != null ? planPath : "") + "|" + (reportPath != null ? reportPath : ""),
                reportPath, "organize", callback);
    }

    /** Remove a native cache file written by an earlier action (stats snapshot, etc.). */
    public static void invalidateCacheAsync(String cachePath, Callback callback) {
        processActionAsync(ACTION_INVALIDATE_CACHE, cachePath != null ? cachePath : "", callback);
    }

    /** Read-only text preview via the wayer_preview module (capped, binary refused). */
    public static void readTextFileAsync(String path, int maxBytes, Callback callback) {
        processActionAsync(ACTION_READ_TEXT_FILE, (path != null ? path : "") + "|" + maxBytes, callback);
    }

    // Every call runs through Bridge's single executor: one native file job
    // at a time, callback back on the UI thread.
    public static void processActionAsync(int actionId, String payload, Callback callback) {
        Bridge.run(actionId, payload, callback);
    }
}
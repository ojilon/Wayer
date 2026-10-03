package com.example.wayer.core;

import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

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

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    static {
        System.loadLibrary("wayer_engine");
    }

    public interface Callback {
        void onResult(String result);
    }

    public static native void initEngine();
    public static native String processAction(int actionId, String payload);

    /** Pass context.getFilesDir() once so native cache/temp/logs resolve under app storage. */
    public static void initAppPathsAsync(android.content.Context context, Callback callback) {
        java.io.File filesDir = context.getFilesDir();
        String root = filesDir != null ? filesDir.getAbsolutePath() : "";
        processActionAsync(ACTION_INIT_APP_PATHS, root, callback);
    }

    /** Walk root once, spill the listing to the native index file; returns {path, count}. */
    public static void buildIndexAsync(String root, Callback callback) {
        processActionAsync(ACTION_BUILD_INDEX, root != null ? root : "", callback);
    }

    /** Metadata about the native index file ({status, path, bytes, modified_unix}). */
    public static void indexMetaAsync(Callback callback) {
        processActionAsync(ACTION_INDEX_META, "", callback);
    }

    /** Case-insensitive substring search over the native index (no full tree walk). */
    public static void searchIndexAsync(String query, int maxResults, Callback callback) {
        processActionAsync(ACTION_SEARCH_INDEX, (query != null ? query : "") + "|" + maxResults, callback);
    }

    /** Remove a native cache file written by an earlier action (stats snapshot, etc.). */
    public static void invalidateCacheAsync(String cachePath, Callback callback) {
        processActionAsync(ACTION_INVALIDATE_CACHE, cachePath != null ? cachePath : "", callback);
    }

    // Asynchronous wrapper: executes JNI call on background thread and posts back to UI thread
    public static void processActionAsync(int actionId, String payload, Callback callback) {
        executor.execute(() -> {
            String result = processAction(actionId, payload);
            mainHandler.post(() -> callback.onResult(result));
        });
    }
}
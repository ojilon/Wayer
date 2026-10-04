package com.example.wayer.bridge;

import android.content.Context;

/**
 * Step 5 of docs/BRIDGE_PLAN.md: one doorway for storage numbers.
 *
 * Both Home and Storage show the same snapshot file, so both go through
 * here: leased file-backed stats, stale file served when busy, plain error
 * JSON when nothing exists yet. Callers keep their existing parsers — the
 * file content shape is unchanged, only its source moved off the JNI string.
 */
public final class Stats {

    private static final int MAX_AGE_SECONDS = 300; // 5 min

    public interface SnapshotCallback {
        void onSnapshot(String json);
    }

    /**
     * Deliver the snapshot JSON. force=true recomputes even a fresh file
     * (refresh button); force=false serves a fresh file as-is.
     */
    public static void requestSnapshot(Context context, boolean force, SnapshotCallback callback) {
        if (context == null) {
            callback.onSnapshot("{\"error\":\"unavailable\"}");
            return;
        }
        String cache = NativeCache.statsSnapshotPath(context);
        String root = AppDirs.externalRoot().getPath();
        long bytes = StorageCapacity.queryDeviceBytes(context);
        String payload = cache + "|" + root + "|" + (force ? 0 : MAX_AGE_SECONDS) + "|" + bytes;
        Bridge.run(NativeEngine.ACTION_GET_CACHED_STATS, payload, cache, "stats", rawJson -> {
            String content = PathCache.readFile(PathCache.envelopePath(rawJson));
            if (content == null) {
                // Busy or failed write: a stale file with old numbers beats an error.
                content = PathCache.readFile(cache);
            }
            if (content == null) content = "{\"error\":\"unavailable\"}";
            callback.onSnapshot(content);
        });
    }

    private Stats() {}
}

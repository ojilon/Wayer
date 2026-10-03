package com.example.wayer.storage;

import android.content.Context;
import com.example.wayer.core.NativeEngine;

import java.io.File;

/**
 * Single home for the Java-side stats snapshot used with native action 13
 * (GET_CACHED_STATS). Call {@link #invalidateStatsSnapshot} after any mutation
 * (delete, rename, apply_organize) so the next stats load is recomputed instead
 * of serving the 5-minute time-based cache.
 */
public final class NativeCache {

    private static final String STATS_SNAPSHOT = "storage_snapshot.json";

    /** Cache file backing StorageFragment stats (under the app cache dir). */
    public static String statsSnapshotPath(Context context) {
        return new File(context.getCacheDir(), STATS_SNAPSHOT).getPath();
    }

    /**
     * Delete the snapshot directly (it is just a file) and, best-effort, ask
     * native to drop it too in case a later action cached under the same path.
     */
    public static boolean invalidateStatsSnapshot(Context context) {
        if (context == null) return false;
        boolean gone = true;
        try {
            File f = new File(statsSnapshotPath(context));
            gone = !f.exists() || f.delete();
        } catch (Exception ignored) {
            gone = false;
        }
        try {
            NativeEngine.invalidateCacheAsync(statsSnapshotPath(context), result -> { });
        } catch (Exception ignored) {
            // Native not loaded yet (unit tests) — file delete above is enough.
        }
        return gone;
    }

    private NativeCache() {}
}

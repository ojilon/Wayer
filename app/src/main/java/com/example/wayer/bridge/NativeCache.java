package com.example.wayer.bridge;

import android.content.Context;

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
     * Delete the snapshot directly (it is just a file), drop the native
     * index file too (moved/deleted files stale it as well), and best-effort
     * ask native to drop both in case a later action cached under same paths.
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
        String index = indexFilePath(context);
        try {
            File f = new File(index);
            if (f.exists() && !f.delete()) gone = false;
        } catch (Exception ignored) {
            gone = false;
        }
        try {
            NativeEngine.invalidateCacheAsync(statsSnapshotPath(context), result -> { });
            if (!index.isEmpty()) NativeEngine.invalidateCacheAsync(index, result -> { });
        } catch (Exception ignored) {
            // Native not loaded yet (unit tests) — file deletes above are enough.
        }
        return gone;
    }

    /** Native index file derived from the registry ("" when unknown). */
    public static String indexFilePath(Context context) {
        if (context == null) return "";
        String cache = PathRegistry.cacheDir(context);
        return cache.isEmpty() ? "" : cache + "/index/files.json";
    }

    private NativeCache() {}
}

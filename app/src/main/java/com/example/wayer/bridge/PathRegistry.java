package com.example.wayer.bridge;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;

import java.io.File;

/**
 * Step 2 of docs/BRIDGE_PLAN.md: the Java side of paths.json.
 *
 * Native owns the layout and writes the manifest; this registry remembers
 * what init reported (persisted in SharedPreferences, mirrored in memory)
 * so any Java code can ask for cacheDir()/tempDir()/logsDir()/moduleDir()
 * instead of re-deriving paths on both sides of the JNI boundary.
 * Every method is best-effort and never throws.
 */
public final class PathRegistry {

    private static final String PREFS = "wayer_paths";

    private static String manifest = "";
    private static String root = "";
    private static String cache = "";
    private static String temp = "";
    private static String logs = "";
    private static boolean loadedFromPrefs = false;

    /**
     * Called from initAppPathsAsync on every init response. Parses the
     * {manifest, root, cache, temp, logs} reply and remembers it.
     */
    public static synchronized void update(Context context, String rawJson) {
        try {
            JSONObject o = new JSONObject(rawJson);
            if (!o.has("manifest")) return;
            manifest = o.optString("manifest", "");
            root = o.optString("root", "");
            cache = o.optString("cache", "");
            temp = o.optString("temp", "");
            logs = o.optString("logs", "");
            if (context != null) {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                        .putString("manifest", manifest)
                        .putString("root", root)
                        .putString("cache", cache)
                        .putString("temp", temp)
                        .putString("logs", logs)
                        .apply();
            }
            loadedFromPrefs = true;
        } catch (Exception ignored) {
            // Malformed reply — keep whatever we had; fallbacks cover callers.
        }
    }

    public static synchronized String manifestPath(Context context) {
        ensureLoaded(context);
        return manifest;
    }

    /** Private app home. Falls back to the AppDirs convention before init. */
    public static synchronized String root(Context context) {
        ensureLoaded(context);
        if (!root.isEmpty()) return root;
        return fallbackRoot(context);
    }

    public static synchronized String cacheDir(Context context) {
        ensureLoaded(context);
        if (!cache.isEmpty()) return cache;
        return fallbackRoot(context) + "/cache";
    }

    public static synchronized String tempDir(Context context) {
        ensureLoaded(context);
        if (!temp.isEmpty()) return temp;
        return fallbackRoot(context) + "/temp";
    }

    public static synchronized String logsDir(Context context) {
        ensureLoaded(context);
        if (!logs.isEmpty()) return logs;
        return fallbackRoot(context) + "/logs";
    }

    /**
     * Per-module scratch folder (<root>/modules/<name>/), created on demand.
     * Returns "" when it cannot be established.
     */
    public static synchronized String moduleDir(Context context, String name) {
        String dir = root(context) + "/modules/" + (name != null ? name : "shared");
        try {
            File f = new File(dir);
            if (f.isDirectory() || f.mkdirs()) return dir;
        } catch (Exception ignored) {
        }
        return "";
    }

    private static void ensureLoaded(Context context) {
        if (loadedFromPrefs || context == null) return;
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            manifest = prefs.getString("manifest", "");
            root = prefs.getString("root", "");
            cache = prefs.getString("cache", "");
            temp = prefs.getString("temp", "");
            logs = prefs.getString("logs", "");
        } catch (Exception ignored) {
        }
        loadedFromPrefs = true;
    }

    private static String fallbackRoot(Context context) {
        try {
            return AppDirs.privateRoot(context).getAbsolutePath();
        } catch (Exception ignored) {
            return "";
        }
    }

    private PathRegistry() {}
}

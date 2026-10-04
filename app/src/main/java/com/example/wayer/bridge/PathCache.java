package com.example.wayer.bridge;

import org.json.JSONObject;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Map;

/**
 * Step 4 of docs/BRIDGE_PLAN.md: remembers where result files live.
 *
 * C++ writes result files; this cache remembers the current and previous
 * path per job ("search", "duplicates", ...) so the UI can show the old
 * list while the new one builds, and survive rotation (static + on disk).
 * File content is always read fresh from disk — never held in memory here.
 */
public final class PathCache {

    private static final Map<String, String> current = new HashMap<>();
    private static final Map<String, String> previous = new HashMap<>();

    /** Remember a new result path; the old current becomes previous. */
    public static synchronized void remember(String job, String path) {
        if (job == null || path == null) return;
        String old = current.get(job);
        if (old != null && !old.equals(path)) previous.put(job, old);
        current.put(job, path);
    }

    public static synchronized String current(String job) {
        String path = current.get(job);
        return path != null ? path : "";
    }

    public static synchronized String previous(String job) {
        String path = previous.get(job);
        return path != null ? path : "";
    }

    /** Result-file path when the reply status is ok, else "". */
    public static String envelopePath(String rawJson) {
        try {
            JSONObject o = new JSONObject(rawJson);
            if ("ok".equals(o.optString("status"))) return o.optString("path", "");
        } catch (Exception ignored) {
        }
        return "";
    }

    /** Machine reason from {"status":"error","reason":"..."}, else "". */
    public static String reason(String rawJson) {
        try {
            JSONObject o = new JSONObject(rawJson);
            if ("error".equals(o.optString("status"))) return o.optString("reason", "");
        } catch (Exception ignored) {
        }
        return "";
    }

    /** Whole file content, or null when missing/unreadable. */
    public static String readFile(String path) {
        if (path == null || path.isEmpty()) return null;
        try {
            File f = new File(path);
            if (!f.isFile()) return null;
            byte[] bytes = Files.readAllBytes(f.toPath());
            return new String(bytes, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    private PathCache() {}
}

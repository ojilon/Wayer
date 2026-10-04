package com.example.wayer.transfer;

import android.content.Context;
import com.example.wayer.bridge.PathRegistry;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

/**
 * B2 of docs/TRANSFER_CLEANER_PLAN.md: the multi-send queue on disk.
 *
 * Selected paths are saved to modules/transfer/queue.json (each with a
 * pending/sending/done/failed status) before the first byte moves, so the
 * queue survives rotation and the session UI (B5) reads the same file the
 * uploader writes. Plain file IO; never throws.
 */
public final class TransferQueue {

    public static String queuePath(Context context) {
        if (context == null) return "";
        String dir = PathRegistry.moduleDir(context, "transfer");
        return dir.isEmpty() ? "" : dir + "/queue.json";
    }

    /** Replace the queue with paths, all pending. False when unwritable. */
    public static boolean save(Context context, List<String> paths) {
        String queue = queuePath(context);
        if (queue.isEmpty() || paths == null) return false;
        try {
            JSONObject root = new JSONObject();
            JSONArray items = new JSONArray();
            for (String path : paths) {
                if (path == null || path.isEmpty()) continue;
                JSONObject item = new JSONObject();
                item.put("path", path);
                item.put("status", "pending");
                items.put(item);
            }
            root.put("queue", items);
            File f = new File(queue);
            File parent = f.getParentFile();
            if (parent != null && !parent.isDirectory() && !parent.mkdirs()) return false;
            try (FileWriter writer = new FileWriter(f, false)) {
                writer.write(root.toString());
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /** Mark one entry's status; no-op when the queue file is missing. */
    public static void setStatus(Context context, String path, String status) {
        String queue = queuePath(context);
        if (queue.isEmpty() || path == null || status == null) return;
        try {
            String content = readRaw(queue);
            if (content == null) return;
            JSONObject root = new JSONObject(content);
            JSONArray items = root.optJSONArray("queue");
            if (items == null) return;
            for (int i = 0; i < items.length(); i++) {
                JSONObject item = items.optJSONObject(i);
                if (item != null && path.equals(item.optString("path"))) {
                    item.put("status", status);
                }
            }
            try (FileWriter writer = new FileWriter(queue, false)) {
                writer.write(root.toString());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /** Paths currently in the queue file, in order. Empty when none. */
    public static List<String> loadPaths(Context context) {
        List<String> paths = new ArrayList<>();
        try {
            String content = readRaw(queuePath(context));
            if (content == null) return paths;
            JSONArray items = new JSONObject(content).optJSONArray("queue");
            if (items == null) return paths;
            for (int i = 0; i < items.length(); i++) {
                JSONObject item = items.optJSONObject(i);
                if (item != null) paths.add(item.optString("path", ""));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return paths;
    }

    private static String readRaw(String queue) {
        if (queue == null || queue.isEmpty()) return null;
        try {
            File f = new File(queue);
            if (!f.isFile()) return null;
            byte[] bytes = java.nio.file.Files.readAllBytes(f.toPath());
            return new String(bytes, java.nio.charset.StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    private TransferQueue() {}
}

package com.example.wayer.bridge;

import org.json.JSONObject;

/**
 * Parsed storage snapshot JSON (same file Home + Storage use).
 * Native writes the file; Java only parses it here.
 */
public final class StatsSnapshot {
    public final long totalBytes;
    public final long usedBytes;
    public final long freeBytes;
    public final int progressPercent;
    public final long images, videos, audio, documents, foreign, system, others;

    private StatsSnapshot(long total, long used, long free, int progress,
                          long images, long videos, long audio, long documents,
                          long foreign, long system, long others) {
        this.totalBytes = total;
        this.usedBytes = used;
        this.freeBytes = free;
        this.progressPercent = progress;
        this.images = images;
        this.videos = videos;
        this.audio = audio;
        this.documents = documents;
        this.foreign = foreign;
        this.system = system;
        this.others = others;
    }

    /** Sum of category breakdown (what the list shows). */
    public long categoriesTotal() {
        return images + videos + audio + documents + foreign + system + others;
    }

    public static StatsSnapshot parse(String rawJson) throws Exception {
        JSONObject data = new JSONObject(rawJson);
        if (data.has("error")) throw new Exception(data.optString("error", "error"));

        long total = data.getLong("total_bytes");
        long used = data.getLong("used_bytes");
        long free = data.optLong("free_bytes", Math.max(0, total - used));
        int progress = data.getInt("progress_percent");

        long images = 0, videos = 0, audio = 0, documents = 0, foreign = 0, system = 0, others = 0;
        if (data.has("breakdown")) {
            JSONObject b = data.getJSONObject("breakdown");
            images = b.optLong("images", 0);
            videos = b.optLong("videos", 0);
            audio = b.optLong("audio", 0);
            documents = b.optLong("documents", 0);
            foreign = b.optLong("foreign", 0);
            system = b.optLong("system", 0);
            others = b.optLong("others", 0);
        }
        return new StatsSnapshot(total, used, free, progress,
                images, videos, audio, documents, foreign, system, others);
    }

    private StatsSnapshot() {
        this(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }
}
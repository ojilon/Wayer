package com.example.wayer.transfer;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Persist last N transfer records (upload/download) for the Transfer screen.
 */
public final class RecentTransfersStore {

    private static final String PREFS = "wayer_prefs";
    private static final String KEY = "recent_transfers_json";
    private static final int MAX = 20;

    public static final class Entry {
        public final boolean download; // true = ↓ from PC
        public final String name;
        public final String detail;    // path or size hint
        public final long timeMs;

        public Entry(boolean download, String name, String detail, long timeMs) {
            this.download = download;
            this.name = name;
            this.detail = detail != null ? detail : "";
            this.timeMs = timeMs;
        }
    }

    private RecentTransfersStore() {}

    public static void add(Context context, boolean download, String name, String detail) {
        List<Entry> list = load(context);
        list.add(0, new Entry(download, name, detail, System.currentTimeMillis()));
        while (list.size() > MAX) {
            list.remove(list.size() - 1);
        }
        save(context, list);
    }

    public static List<Entry> load(Context context) {
        List<Entry> out = new ArrayList<>();
        String raw = prefs(context).getString(KEY, "[]");
        try {
            JSONArray arr = new JSONArray(raw);
            for (int i = 0; i < arr.length(); i++) {
                JSONObject o = arr.getJSONObject(i);
                out.add(new Entry(
                        o.optBoolean("dl", true),
                        o.optString("name", "?"),
                        o.optString("detail", ""),
                        o.optLong("t", 0L)
                ));
            }
        } catch (Exception ignored) {
        }
        return out;
    }

    private static void save(Context context, List<Entry> list) {
        try {
            JSONArray arr = new JSONArray();
            for (Entry e : list) {
                JSONObject o = new JSONObject();
                o.put("dl", e.download);
                o.put("name", e.name);
                o.put("detail", e.detail);
                o.put("t", e.timeMs);
                arr.put(o);
            }
            prefs(context).edit().putString(KEY, arr.toString()).apply();
        } catch (Exception ignored) {
        }
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }
}

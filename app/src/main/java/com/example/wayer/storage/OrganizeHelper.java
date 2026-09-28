// OrganizeHelper.java (new) — keeps this logic out of the fragment
package com.example.wayer.storage;

import android.content.Context;
import com.example.wayer.core.NativeEngine;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;

public final class OrganizeHelper {

    private static final int ACTION_PLAN_ORGANIZE  = 11;
    private static final int ACTION_APPLY_ORGANIZE = 12;

    public interface PlanCallback {
        void onPlan(List<String> fromPaths, List<String> toPaths);
    }

    public static void requestPlan(String root, PlanCallback cb) {
        NativeEngine.processActionAsync(ACTION_PLAN_ORGANIZE, root, rawJson -> {
            List<String> from = new ArrayList<>();
            List<String> to = new ArrayList<>();
            try {
                JSONObject obj = new JSONObject(rawJson);
                JSONArray moves = obj.optJSONArray("moves");
                if (moves != null) {
                    for (int i = 0; i < moves.length(); i++) {
                        JSONObject m = moves.getJSONObject(i);
                        from.add(m.getString("from"));
                        to.add(m.getString("to"));
                    }
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
            cb.onPlan(from, to);
        });
    }

    public static void apply(List<String> fromPaths, List<String> toPaths, Runnable onDone) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < fromPaths.size(); i++) {
            if (i > 0) sb.append('|');
            sb.append(fromPaths.get(i)).append('|').append(toPaths.get(i));
        }
        NativeEngine.processActionAsync(ACTION_APPLY_ORGANIZE, sb.toString(), rawJson -> onDone.run());
    }

    private OrganizeHelper() {}
}
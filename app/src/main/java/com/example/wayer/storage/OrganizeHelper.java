// OrganizeHelper.java — keeps this logic out of the fragment
package com.example.wayer.storage;

import android.content.Context;
import com.example.wayer.bridge.NativeCache;
import com.example.wayer.bridge.NativeEngine;
import com.example.wayer.bridge.PathCache;
import com.example.wayer.bridge.PathRegistry;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.File;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

public final class OrganizeHelper {

    public interface PlanCallback {
        void onPlan(List<String> fromPaths, List<String> toPaths);
    }

    private static String planPath(Context context) {
        String dir = PathRegistry.moduleDir(context, "organizer");
        return dir.isEmpty() ? "" : dir + "/plan.json";
    }

    private static String reportPath(Context context) {
        String dir = PathRegistry.moduleDir(context, "organizer");
        return dir.isEmpty() ? "" : dir + "/report.json";
    }

    /** Ask C++ for a plan file, then parse that file into preview lists. */
    public static void requestPlan(Context context, String root, PlanCallback cb) {
        String plan = planPath(context);
        if (plan.isEmpty()) {
            cb.onPlan(new ArrayList<>(), new ArrayList<>());
            return;
        }
        NativeEngine.planOrganizeAsync(root, plan, rawJson -> {
            List<String> from = new ArrayList<>();
            List<String> to = new ArrayList<>();
            String content = PathCache.readFile(PathCache.envelopePath(rawJson));
            if (content != null) {
                try {
                    JSONObject obj = new JSONObject(content);
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
            }
            cb.onPlan(from, to);
        });
    }

    /**
     * Write exactly the approved moves as the plan file (the UI may have
     * edited the preview), then let C++ execute it into a report file.
     * Stats/index caches drop afterwards — moved files would stale them.
     */
    public static void apply(Context context, List<String> fromPaths, List<String> toPaths, Runnable onDone) {
        if (!writePlanFile(planPath(context), fromPaths, toPaths)) {
            onDone.run();
            return;
        }
        NativeEngine.applyOrganizeAsync(planPath(context), reportPath(context), rawJson -> {
            NativeCache.invalidateStatsSnapshot(context);
            onDone.run();
        });
    }

    private static boolean writePlanFile(String plan, List<String> fromPaths, List<String> toPaths) {
        if (plan == null || plan.isEmpty() || fromPaths == null || toPaths == null) return false;
        try {
            JSONObject root = new JSONObject();
            JSONArray moves = new JSONArray();
            int count = Math.min(fromPaths.size(), toPaths.size());
            for (int i = 0; i < count; i++) {
                JSONObject move = new JSONObject();
                move.put("from", fromPaths.get(i));
                move.put("to", toPaths.get(i));
                moves.put(move);
            }
            root.put("moves", moves);
            File f = new File(plan);
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

    private OrganizeHelper() {}
}

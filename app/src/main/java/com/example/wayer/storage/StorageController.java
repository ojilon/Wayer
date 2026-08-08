package com.example.wayer.storage;

import com.example.wayer.core.NativeEngine;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;

public class StorageController {

    public interface StorageCallback {
        void onComplete(List<StorageItem> items);
    }

    public static void fetchDirectoryListing(String path, StorageCallback callback) {
        NativeEngine.processActionAsync(3, path, rawJson -> {
            List<StorageItem> result = new ArrayList<>();
            try {
                JSONObject obj = new JSONObject(rawJson);
                if (obj.has("items")) {
                    JSONArray arr = obj.getJSONArray("items");
                    for (int i = 0; i < arr.length(); i++) {
                        JSONObject item = arr.getJSONObject(i);
                        result.add(new StorageItem(
                            item.optString("name"),
                            path,
                            item.optBoolean("is_dir"),
                            item.optLong("size")
                        ));
                    }
                }
            } catch (Exception e) {
                android.util.Log.e("StorageController", "JSON Parse Error", e);
            }
            callback.onComplete(result);
        });
    }

    public static void fetchFilteredDocuments(String path, StorageCallback callback) {
        NativeEngine.processActionAsync(5, path, rawJson -> {
            List<StorageItem> result = new ArrayList<>();
            try {
                JSONObject obj = new JSONObject(rawJson);
                if (obj.has("documents")) {
                    JSONArray arr = obj.getJSONArray("documents");
                    for (int i = 0; i < arr.length(); i++) {
                        JSONObject item = arr.getJSONObject(i);
                        result.add(new StorageItem(
                            item.optString("name"),
                            item.optString("path"),
                            false,
                            item.optLong("size")
                        ));
                    }
                }
            } catch (Exception e) {
                android.util.Log.e("StorageController", "JSON Parse Error", e);
            }
            callback.onComplete(result);
        });
    }
}
package com.example.wayer.transfer;

import com.example.wayer.core.NativeEngine;
import org.json.JSONObject;

public class TransferController {

    public interface TransferCallback {
        void onComplete(NetworkStatus status);
    }

    public static void startServerListener(int port, TransferCallback callback) {
        NativeEngine.processActionAsync(6, String.valueOf(port), rawJson -> {
            NetworkStatus status = new NetworkStatus("error", 0);
            try {
                JSONObject obj = new JSONObject(rawJson);
                status = new NetworkStatus(
                    obj.optString("status", "error"),
                    obj.optInt("port", port)
                );
            } catch (Exception e) {
                android.util.Log.e("TransferController", "JSON Parse Error", e);
            }
            callback.onComplete(status);
        });
    }
}
package com.example.wayer.core;

import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class NativeEngine {
    
    private static final ExecutorService executor = Executors.newSingleThreadExecutor();
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    static {
        System.loadLibrary("wayer_engine");
    }

    public interface Callback {
        void onResult(String result);
    }

    public static native void initEngine();
    public static native String processAction(int actionId, String payload);

    // Asynchronous wrapper: executes JNI call on background thread and posts back to UI thread
    public static void processActionAsync(int actionId, String payload, Callback callback) {
        executor.execute(() -> {
            String result = processAction(actionId, payload);
            mainHandler.post(() -> callback.onResult(result));
        });
    }
}
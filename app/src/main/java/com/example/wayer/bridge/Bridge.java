package com.example.wayer.bridge;

import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Single doorway to native code (Step 1 of docs/BRIDGE_PLAN.md).
 *
 * Owns the one background executor every storage/file job runs on, so two
 * native file writes can never overlap — callers describe jobs, Bridge
 * serializes them, and the callback always returns on the UI thread.
 */
public final class Bridge {

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    /** Run a native action off the UI thread; callback fires on the UI thread. */
    public static void run(int actionId, String payload, NativeEngine.Callback callback) {
        executor.execute(() -> {
            String result = NativeEngine.processAction(actionId, payload);
            mainHandler.post(() -> callback.onResult(result));
        });
    }

    private Bridge() {}
}

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
        run(actionId, payload, null, null, callback);
    }

    /**
     * Same, but guarded by a file lease: when leasePath is given, the job
     * runs only if nobody else holds that file, and releases it after.
     * Refused jobs answer {"status":"error","reason":"busy"} on the UI thread.
     */
    public static void run(int actionId, String payload, String leasePath,
                           String leaseOwner, NativeEngine.Callback callback) {
        executor.execute(() -> {
            String result;
            String owner = leaseOwner != null ? leaseOwner : "bridge";
            if (leasePath != null && !FileLeases.acquire(leasePath, owner)) {
                result = "{\"status\":\"error\",\"reason\":\"busy\"}";
            } else {
                try {
                    result = NativeEngine.processAction(actionId, payload);
                } finally {
                    if (leasePath != null) FileLeases.release(leasePath, owner);
                }
            }
            String done = result;
            mainHandler.post(() -> callback.onResult(done));
        });
    }

    private Bridge() {}
}

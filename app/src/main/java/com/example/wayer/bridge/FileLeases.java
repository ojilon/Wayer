package com.example.wayer.bridge;

import android.util.Log;

import java.util.HashMap;
import java.util.Map;

/**
 * Step 3 of docs/BRIDGE_PLAN.md: one writer per file.
 *
 * In-memory lease table (path → owner + expiry) so two jobs never write the
 * same result file at once — e.g. a stats refresh landing while the Storage
 * screen is still reading the snapshot. Leases expire on their own, so a
 * crashed or abandoned job cannot wedge the file forever. Re-acquiring with
 * the same owner simply extends the lease (lets long jobs renew).
 * Everything is synchronized; every decision is logged at debug level.
 */
public final class FileLeases {

    private static final String TAG = "WayerBridge";
    private static final long DEFAULT_TIMEOUT_MS = 60_000;
    private static final long MIN_TIMEOUT_MS = 1_000;

    private static final class Lease {
        String owner = "";
        long expiresAt = 0;
    }

    private static final Map<String, Lease> leases = new HashMap<>();

    /** Acquire the file for owner, default timeout. False = someone else holds it. */
    public static synchronized boolean acquire(String path, String owner) {
        return acquire(path, owner, DEFAULT_TIMEOUT_MS);
    }

    /** Acquire the file for owner for timeoutMs. False = someone else holds it. */
    public static synchronized boolean acquire(String path, String owner, long timeoutMs) {
        if (path == null || path.isEmpty() || owner == null || owner.isEmpty()) return false;
        long now = System.currentTimeMillis();
        Lease current = leases.get(path);
        if (current != null && current.expiresAt > now && !current.owner.equals(owner)) {
            Log.d(TAG, "lease denied: " + path + " held by " + current.owner);
            return false;
        }
        Lease next = new Lease();
        next.owner = owner;
        long timeout = timeoutMs < MIN_TIMEOUT_MS ? MIN_TIMEOUT_MS : timeoutMs;
        next.expiresAt = now + timeout;
        leases.put(path, next);
        Log.d(TAG, "lease acquired: " + path + " by " + owner);
        return true;
    }

    /** Release only if owner still holds it; strangers cannot evict. */
    public static synchronized void release(String path, String owner) {
        if (path == null) return;
        Lease current = leases.get(path);
        if (current != null && (owner == null || current.owner.equals(owner))) {
            leases.remove(path);
            Log.d(TAG, "lease released: " + path);
        }
    }

    /** True when nobody holds the file (or the lease expired). */
    public static synchronized boolean isFree(String path) {
        if (path == null || path.isEmpty()) return false;
        Lease current = leases.get(path);
        return current == null || current.expiresAt <= System.currentTimeMillis();
    }

    private FileLeases() {}
}

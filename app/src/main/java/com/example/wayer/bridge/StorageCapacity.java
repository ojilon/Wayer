package com.example.wayer.bridge;

import android.content.Context;
import android.os.Environment;
import android.os.StatFs;
import android.os.storage.StorageManager;
import android.app.usage.StorageStatsManager;

/**
 * Queries the real device capacity for native {@code get_storage_stats}.
 *
 * Native {@code statvfs} only sees the app-visible partition, so C++ accepts a
 * {@code known_device_bytes} override (see native/storage/flags.md). This helper
 * supplies it from Java. Every lookup is best-effort: any failure returns 0 and
 * native falls back to its legacy retail-capacity floor — never crash here.
 */
public final class StorageCapacity {

    /** Total shared-storage bytes, or 0 when the platform does not reveal it. */
    public static long queryDeviceBytes(Context context) {
        if (context == null) return 0;
        try {
            StorageStatsManager stats = context.getSystemService(StorageStatsManager.class);
            if (stats != null) {
                long total = stats.getTotalBytes(StorageManager.UUID_DEFAULT);
                if (total > 0) return total;
            }
        } catch (Exception ignored) {
            // SecurityException on some ROMs / profiles — fall through to StatFs.
        }
        try {
            StatFs sf = new StatFs(Environment.getExternalStorageDirectory().getPath());
            return sf.getTotalBytes();
        } catch (Exception ignored) {
            return 0;
        }
    }

    private StorageCapacity() {}
}

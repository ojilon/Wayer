package com.example.wayer.storage;

import android.content.Context;
import android.os.Environment;

import java.io.File;

/**
 * Where Wayer keeps things — one policy for the whole app.
 *
 * <p><b>Private internals</b> (index files, stats snapshots, logs, future DB)
 * live under {@code getFilesDir()/wayer} — internal storage, invisible to file
 * explorers and other apps. This is deliberate: the native index is a full
 * inventory of the user's storage and must never leak to shared space.
 * Native receives this root once via {@code ACTION_INIT_APP_PATHS}.
 *
 * <p><b>Shared outputs</b> — files the user explicitly receives or creates
 * (transfer downloads, exported documents) — go to public directories
 * (Download, Documents, …) so other phones, PCs and gallery/document apps
 * can see them. Always resolve these via {@link Environment}, never hardcode
 * {@code /storage/emulated/0/...} (breaks on multi-user / adoptable storage).
 */
public final class AppDirs {

    private static final String PRIVATE_SUBDIR = "wayer";
    private static final String LEGACY_ROOT = "/storage/emulated/0";

    /** Private app home: {@code <filesDir>/wayer}. Unknown to external explorers. */
    public static File privateRoot(Context context) {
        return new File(context.getFilesDir(), PRIVATE_SUBDIR);
    }

    /** Shared-storage root; falls back to the legacy path when unmounted/unknown. */
    public static File externalRoot() {
        try {
            if (Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) {
                File root = Environment.getExternalStorageDirectory();
                if (root != null) return root;
            }
        } catch (Exception ignored) {
            // Fall through to legacy path.
        }
        return new File(LEGACY_ROOT);
    }

    public static File downloadDir() {
        return child(Environment.DIRECTORY_DOWNLOADS);
    }

    public static File documentsDir() {
        return child(Environment.DIRECTORY_DOCUMENTS);
    }

    public static File dcimDir() {
        return child(Environment.DIRECTORY_DCIM);
    }

    public static File moviesDir() {
        return child(Environment.DIRECTORY_MOVIES);
    }

    private static File child(String type) {
        try {
            @SuppressWarnings("deprecation")
            File dir = Environment.getExternalStoragePublicDirectory(type);
            if (dir != null) return dir;
        } catch (Exception ignored) {
            // Fall through to externalRoot() + type.
        }
        return new File(externalRoot(), type);
    }

    private AppDirs() {}
}

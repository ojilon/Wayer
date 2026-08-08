package com.example.wayer.ui;

import android.content.Context;

/**
 * Chooses the right full-window viewer for a file path.
 * Used by FilesFragment (and later Storage / search results).
 */
public final class FileOpenHelper {

    private FileOpenHelper() {}

    public static void open(Context context, String path) {
        if (path == null || path.isEmpty()) return;

        String lower = path.toLowerCase();
        int dot = lower.lastIndexOf('.');
        String ext = dot >= 0 ? lower.substring(dot + 1) : "";

        switch (ext) {
            case "jpg":
            case "jpeg":
            case "png":
            case "webp":
            case "gif":
            case "bmp":
                ImageActivity.open(context, path);
                break;

            case "mp4":
            case "mkv":
            case "webm":
            case "3gp":
            case "avi":
                VideoActivity.open(context, path);
                break;

            default:
                // Text, pdf, office, unknown → document foundation
                DocumentActivity.open(context, path);
                break;
        }
    }
}

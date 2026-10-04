// File path: com/example/wayer/storage/FileIndexer.java
package com.example.wayer.storage;

import com.example.wayer.bridge.AppDirs;

import java.io.File;

/**
 * Shared-storage roots and the default save folder.
 *
 * The old Java tree-walk cache is gone on purpose (Step 7): whole-storage
 * indexing and global search live in native (BUILD_INDEX / SEARCH_INDEX)
 * behind bridge/NativeEngine, and Transfer reads that shared index file.
 * What remains here are the path helpers screens still need.
 */
public final class FileIndexer {

    public static final String DEFAULT_ROOT = "/storage/emulated/0";

    /** Default folder for downloads from PC → phone (public, visible to other apps). */
    public static String getDefaultSavePath() {
        File dl = AppDirs.downloadDir();
        if (dl.exists() && dl.isDirectory()) return dl.getPath();
        File root = AppDirs.externalRoot();
        if (root.exists() && root.isDirectory()) return root.getPath();
        return DEFAULT_ROOT;
    }

    private FileIndexer() {}
}

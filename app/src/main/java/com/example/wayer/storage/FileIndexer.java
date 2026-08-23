// File path: com/example/wayer/storage/FileIndexer.java
package com.example.wayer.storage;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Cache engine for local storage paths.
 * Maps folder paths → immediate children; maintains flat lists for global search.
 *
 * Singleton so Transfer, Files, and future screens share one cache.
 * Call {@link #refreshCache()} (or {@link #rebuildCache(File)}) after permission grant / storage change.
 */
public class FileIndexer {

    public static final String DEFAULT_ROOT = "/storage/emulated/0";
    public static final String DEFAULT_DOWNLOADS = "/storage/emulated/0/Download";

    private static volatile FileIndexer instance;

    private final Map<String, List<String>> folderContentsCache = new HashMap<>();
    private final List<String> allFolderPaths = new ArrayList<>();
    private final List<String> allFilePaths = new ArrayList<>();

    private FileIndexer() {}

    public static FileIndexer getInstance() {
        if (instance == null) {
            synchronized (FileIndexer.class) {
                if (instance == null) {
                    instance = new FileIndexer();
                }
            }
        }
        return instance;
    }

    /**
     * Rebuild from DEFAULT_ROOT (internal storage). Safe to call from a background thread.
     */
    public void refreshCache() {
        rebuildCache(new File(DEFAULT_ROOT));
    }

    /**
     * Clears old data and recursively crawls the tree under rootDir.
     */
    public synchronized void rebuildCache(File rootDir) {
        folderContentsCache.clear();
        allFolderPaths.clear();
        allFilePaths.clear();
        if (rootDir != null) {
            traverseAndIndex(rootDir);
        }
    }

    private void traverseAndIndex(File currentFolder) {
        if (currentFolder == null || !currentFolder.exists() || !currentFolder.isDirectory()) {
            return;
        }

        File[] children = currentFolder.listFiles();
        if (children == null) return;

        String currentFolderPath = currentFolder.getAbsolutePath();
        allFolderPaths.add(currentFolderPath);

        List<String> contentsOfThisFolder = new ArrayList<>();

        for (File child : children) {
            String childPath = child.getAbsolutePath();
            contentsOfThisFolder.add(childPath);

            if (child.isDirectory()) {
                traverseAndIndex(child);
            } else {
                allFilePaths.add(childPath);
            }
        }

        folderContentsCache.put(currentFolderPath, contentsOfThisFolder);
    }

    public List<String> searchFoldersByKeyword(String keyword) {
        if (keyword == null || keyword.isEmpty()) return Collections.emptyList();
        String q = keyword.toLowerCase();
        List<String> matches = new ArrayList<>();
        for (String path : allFolderPaths) {
            File f = new File(path);
            if (f.getName().toLowerCase().contains(q)) {
                matches.add(path);
            }
        }
        return matches;
    }

    /**
     * Global file search over the cached flat list (no disk walk).
     */
    public List<String> searchFilesByKeyword(String keyword) {
        if (keyword == null || keyword.isEmpty()) return Collections.emptyList();
        String q = keyword.toLowerCase();
        List<String> matches = new ArrayList<>();
        for (String path : allFilePaths) {
            File f = new File(path);
            if (f.getName().toLowerCase().contains(q)) {
                matches.add(path);
            }
        }
        return matches;
    }

    public List<String> getContentsOfFolder(String folderPath) {
        List<String> list = folderContentsCache.get(folderPath);
        return list != null ? list : Collections.emptyList();
    }

    public boolean isCacheEmpty() {
        return allFolderPaths.isEmpty();
    }

    public int getIndexedFileCount() {
        return allFilePaths.size();
    }

    public int getIndexedFolderCount() {
        return allFolderPaths.size();
    }

    /** Default folder for downloads from PC → phone. */
    public static String getDefaultSavePath() {
        File dl = new File(DEFAULT_DOWNLOADS);
        if (dl.exists() && dl.isDirectory()) return DEFAULT_DOWNLOADS;
        return DEFAULT_ROOT;
    }
}

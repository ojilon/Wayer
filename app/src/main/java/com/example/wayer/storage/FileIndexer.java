// File path: com/example/wayer/storage/FileIndexer.java
package com.example.wayer.storage;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Requirement 2 & 3: The Cache Engine.
 * This class maps the entire storage device once and stores everything in memory.
 * Keys = Folder Names. Values = Lists of absolute paths of items inside them.
 */
public class FileIndexer {

    // The primary cache structure
    // Key: Absolute path of a folder
    // Value: A list of absolute paths of everything directly inside that folder
    private final Map<String, List<String>> folderContentsCache = new HashMap<>();

    // Secondary flat list of all folder paths for rapid skipping/jumping
    private final List<String> allFolderPaths = new ArrayList<>();
    
    // Flat list of all file paths for rapid global file selection
    private final List<String> allFilePaths = new ArrayList<>();

    /**
     * Clears old data and recursively crawls the entire storage tree.
     * Call this via a command like 'refresh' to build your cache.
     */
    public void rebuildCache(File rootDir) {
        folderContentsCache.clear();
        allFolderPaths.clear();
        allFilePaths.clear();
        
        // Start the deep background traversal loop
        traverseAndIndex(rootDir);
    }

    /**
     * Recursive function. It calls itself whenever it hits a new subfolder.
     */
    private void traverseAndIndex(File currentFolder) {
        if (currentFolder == null || !currentFolder.exists() || !currentFolder.isDirectory()) {
            return;
        }

        File[] children = currentFolder.listFiles();
        if (children == null) return; // Skip protected/system folders with access denied

        String currentFolderPath = currentFolder.getAbsolutePath();
        allFolderPaths.add(currentFolderPath);

        List<String> contentsOfThisFolder = new ArrayList<>();

        for (File child : children) {
            String childPath = child.getAbsolutePath();
            contentsOfThisFolder.add(childPath);

            if (child.isDirectory()) {
                // RECURSION: If it's a folder, dive down into it automatically
                traverseAndIndex(child);
            } else {
                // If it's a file, add it to our global file array
                allFilePaths.add(childPath);
            }
        }

        // Store this folder's immediate items inside our dictionary map
        folderContentsCache.put(currentFolderPath, contentsOfThisFolder);
    }

    /**
     * Searches through the CACHED folder paths using a simple text keyword.
     * Returns a list of matching folder paths without touching the physical storage disk.
     */
    public List<String> searchFoldersByKeyword(String keyword) {
        List<String> matches = new ArrayList<>();
        for (String path : allFolderPaths) {
            File f = new File(path);
            if (f.getName().toLowerCase().contains(keyword.toLowerCase())) {
                matches.add(path);
            }
        }
        return matches;
    }

    /**
     * Requirement 3 (Part 2): Searches cached files globally by keyword.
     */
    public List<String> searchFilesByKeyword(String keyword) {
        List<String> matches = new ArrayList<>();
        for (String path : allFilePaths) {
            File f = new File(path);
            if (f.getName().toLowerCase().contains(keyword.toLowerCase())) {
                matches.add(path);
            }
        }
        return matches;
    }

    // Getters to let other parts of the app read the map data smoothly
    public List<String> getContentsOfFolder(String folderPath) {
        return folderContentsCache.get(folderPath);
    }
    
    public boolean isCacheEmpty() {
        return allFolderPaths.isEmpty();
    }
}
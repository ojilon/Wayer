// File path: com/example/wayer/storage/FileSearcher.java
package com.example.wayer.storage;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * Isolated logic framework dedicated exclusively to searching through directories.
 * This file is prepared to drop in JNI functions directly down the line.
 */
public class FileSearcher {

    /**
     * Recursively runs through files looking for a specific match snippet pattern.
     */
    public static List<String> findFilesContainingKeyword(File directory, String keyword) {
        List<String> results = new ArrayList<>();
        File[] files = directory.listFiles();
        
        if (files != null) {
            for (File file : files) {
                if (file.getName().toLowerCase().contains(keyword.toLowerCase())) {
                    results.add(file.isDirectory() ? "[" + file.getName() + "]/" : file.getName());
                }
            }
        }
        return results;
    }
}
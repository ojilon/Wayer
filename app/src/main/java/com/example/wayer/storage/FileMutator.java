// File path: com/example/wayer/storage/FileMutator.java
package com.example.wayer.storage;

import com.example.wayer.utils.TextSanitizer;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

/**
 * Responsible for altering structural disk content (creating, renaming, writing data).
 * Excellent isolated candidate to replace with super fast C code loops via JNI later.
 */
public class FileMutator {

    /**
     * Helper to safely write a basic string (like a JSON log or test cache file) to disk.
     */
    public static boolean writeTextFile(File directory, String filename, String content, boolean append) {
        File targetFile = new File(directory, filename);
        // "Try-with-resources" automatically closes streams even if a disk error happens
        try (FileWriter writer = new FileWriter(targetFile, append)) {
            writer.write(content);
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    /**
     * Automates taking a messy file name pattern, formatting it, and renaming it.
     */
    public static String sanitizeAndRenameFile(File directory, String oldName) {
        File oldFile = new File(directory, oldName);
        if (!oldFile.exists()) {
            return "Error: Source file does not exist.";
        }

        // Use our utility class to change "my file.txt" into "my_file.txt"
        String cleanName = TextSanitizer.replaceSpacesWithUnderscores(oldName);
        File newFile = new File(directory, cleanName);

        if (oldFile.renameTo(newFile)) {
            return "Successfully renamed to: " + cleanName;
        } else {
            return "System Error: Failed to commit rename operation.";
        }
    }

    /**
     * Requirement 3 & 4: Creates a brand new directory folder on-the-spot anywhere on disk.
     */
    public static String createNewDirectory(String parentPath, String newFolderName) {
        // Clean the target folder name up immediately to protect directory structures
        String cleanFolderName = TextSanitizer.replaceSpacesWithUnderscores(newFolderName);
        File newFolder = new File(parentPath, cleanFolderName);

        if (newFolder.exists()) {
            return "Execution Stopped: Folder element '" + cleanFolderName + "' already exists here.";
        }

        // .mkdirs() creates the folder, plus any missing parent directories automatically
        if (newFolder.mkdirs()) {
            return "Success: Created directory structure at: " + newFolder.getAbsolutePath();
        } else {
            return "Failure: Disk creation operation rejected by system.";
        }
    }

    /**
     * Requirement 7: Looks through an entire directory on disk and fixes 
     * all filenames inside it to replace blank spaces with underscores.
     */
    public static String batchSanitizeFolderContents(File directory) {
        File[] targets = directory.listFiles();
        if (targets == null) return "Access Denied.";
        
        int changeCounter = 0;
        for (File file : targets) {
            String originalName = file.getName();
            if (originalName.contains(" ")) {
                String cleanName = TextSanitizer.replaceSpacesWithUnderscores(originalName);
                File destination = new File(directory, cleanName);
                if (file.renameTo(destination)) {
                    changeCounter++;
                }
            }
        }
        return "Batch Action Completed: Sanitized (" + changeCounter + ") file structures.";
    }
    
    // Future expansion point: Add custom popup triggers, deletes, moves, and copies here
}
package com.example.wayer.storage;

import com.example.wayer.utils.TextSanitizer;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

/**
 * Universal local file operations used by Files, Storage, Transfer, etc.
 *
 * Keep this the single place for create / rename / delete / write.
 * Later, heavy bulk work can move to C++ via NativeEngine; the public
 * method names can stay the same so UI code does not change.
 */
public class FileMutator {

    public static class Result {
        public final boolean ok;
        public final String message;

        public Result(boolean ok, String message) {
            this.ok = ok;
            this.message = message;
        }

        public static Result success(String msg) { return new Result(true, msg); }
        public static Result fail(String msg) { return new Result(false, msg); }
    }

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    /** Create an empty file (optionally with extension, e.g. "notes.txt"). */
    public static Result createFile(String parentPath, String fileName) {
        if (parentPath == null || fileName == null || fileName.trim().isEmpty()) {
            return Result.fail("Invalid path or name");
        }
        String clean = TextSanitizer.replaceSpacesWithUnderscores(fileName.trim());
        File target = new File(parentPath, clean);
        if (target.exists()) {
            return Result.fail("Already exists: " + clean);
        }
        try {
            File parent = target.getParentFile();
            if (parent != null && !parent.exists() && !parent.mkdirs()) {
                return Result.fail("Cannot create parent directories");
            }
            if (target.createNewFile()) {
                return Result.success("Created file: " + target.getAbsolutePath());
            }
            return Result.fail("createNewFile returned false");
        } catch (IOException e) {
            return Result.fail("IO error: " + e.getMessage());
        }
    }

    /** Create a new folder under parentPath. */
    public static Result createDirectory(String parentPath, String folderName) {
        if (parentPath == null || folderName == null || folderName.trim().isEmpty()) {
            return Result.fail("Invalid path or name");
        }
        String clean = TextSanitizer.replaceSpacesWithUnderscores(folderName.trim());
        File newFolder = new File(parentPath, clean);
        if (newFolder.exists()) {
            return Result.fail("Already exists: " + clean);
        }
        if (newFolder.mkdirs()) {
            return Result.success("Created folder: " + newFolder.getAbsolutePath());
        }
        return Result.fail("mkdirs failed (permission?)");
    }

    // -------------------------------------------------------------------------
    // Rename / move (same volume)
    // -------------------------------------------------------------------------

    public static Result rename(String fullPath, String newName) {
        if (fullPath == null || newName == null || newName.trim().isEmpty()) {
            return Result.fail("Invalid path or name");
        }
        File src = new File(fullPath);
        if (!src.exists()) {
            return Result.fail("Source does not exist");
        }
        String clean = TextSanitizer.replaceSpacesWithUnderscores(newName.trim());
        File dest = new File(src.getParent(), clean);
        if (dest.exists()) {
            return Result.fail("Target name already exists");
        }
        if (src.renameTo(dest)) {
            return Result.success("Renamed to: " + clean);
        }
        return Result.fail("renameTo failed");
    }

    // -------------------------------------------------------------------------
    // Delete (file or empty/non-empty folder)
    // -------------------------------------------------------------------------

    public static Result delete(String fullPath) {
        if (fullPath == null || fullPath.trim().isEmpty()) {
            return Result.fail("Invalid path");
        }
        File target = new File(fullPath);
        if (!target.exists()) {
            return Result.fail("Does not exist");
        }
        boolean ok = deleteRecursive(target);
        if (ok) {
            return Result.success("Deleted: " + target.getName());
        }
        return Result.fail("Delete failed (permission or in use)");
    }

    private static boolean deleteRecursive(File f) {
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) {
                for (File c : children) {
                    if (!deleteRecursive(c)) return false;
                }
            }
        }
        return f.delete();
    }

    // -------------------------------------------------------------------------
    // Write text (logs, small configs)
    // -------------------------------------------------------------------------

    public static boolean writeTextFile(File directory, String filename, String content, boolean append) {
        File targetFile = new File(directory, filename);
        try (FileWriter writer = new FileWriter(targetFile, append)) {
            writer.write(content);
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    // -------------------------------------------------------------------------
    // Legacy helpers (kept for existing callers)
    // -------------------------------------------------------------------------

    public static String sanitizeAndRenameFile(File directory, String oldName) {
        Result r = rename(new File(directory, oldName).getAbsolutePath(),
                TextSanitizer.replaceSpacesWithUnderscores(oldName));
        return r.message;
    }

    public static String createNewDirectory(String parentPath, String newFolderName) {
        return createDirectory(parentPath, newFolderName).message;
    }

    public static String batchSanitizeFolderContents(File directory) {
        File[] targets = directory.listFiles();
        if (targets == null) return "Access Denied.";

        int changeCounter = 0;
        for (File file : targets) {
            String originalName = file.getName();
            if (originalName.contains(" ")) {
                Result r = rename(file.getAbsolutePath(),
                        TextSanitizer.replaceSpacesWithUnderscores(originalName));
                if (r.ok) changeCounter++;
            }
        }
        return "Batch Action Completed: Sanitized (" + changeCounter + ") file structures.";
    }
}

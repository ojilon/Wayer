package com.example.wayer.ui;

/**
 * Simple data class for one row in the Files list / search results.
 * Java only displays; C++ supplies the data via bulk JSON.
 */
public class FileItem {

    private final String name;
    private final String path;       // full path (needed for open / browse)
    private final String details;    // e.g. "Folder" or "2.4 MB"
    private final boolean directory;
    private final long sizeBytes;    // 0 for folders

    public FileItem(String name, String path, String details, boolean directory, long sizeBytes) {
        this.name = name;
        this.path = path;
        this.details = details;
        this.directory = directory;
        this.sizeBytes = sizeBytes;
    }

    public String getName() {
        return name;
    }

    public String getPath() {
        return path;
    }

    public String getDetails() {
        return details;
    }

    public boolean isDirectory() {
        return directory;
    }

    public long getSizeBytes() {
        return sizeBytes;
    }
}

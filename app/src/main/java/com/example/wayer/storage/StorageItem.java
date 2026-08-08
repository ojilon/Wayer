package com.example.wayer.storage;

public class StorageItem {
    private final String name;
    private final String path;
    private final boolean isDirectory;
    private final long size;

    public StorageItem(String name, String path, boolean isDirectory, long size) {
        this.name = name;
        this.path = path;
        this.isDirectory = isDirectory;
        this.size = size;
    }

    public String getName() { return name; }
    public String getPath() { return path; }
    public boolean isDirectory() { return isDirectory; }
    public long getSize() { return size; }
}
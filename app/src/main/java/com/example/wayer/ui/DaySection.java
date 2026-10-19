package com.example.wayer.ui;

import java.util.ArrayList;
import java.util.List;

public class DaySection {
    public final String day;
    public final List<FileEntry> files = new ArrayList<>();

    public DaySection(String day) {
        this.day = day;
    }

    public static class FileEntry {
        public final String path;
        public final String name;
        public final String kind;
        public final long size;
        public final long mtime;

        public FileEntry(String path, String name, String kind, long size, long mtime) {
            this.path = path;
            this.name = name;
            this.kind = kind;
            this.size = size;
            this.mtime = mtime;
        }
    }
}
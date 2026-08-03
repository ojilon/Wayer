package com.example.wayer.ui;

public class FileItem  {
    private String name;
    private String details;
    private boolean deirectory;

    public FileItem(String name, String details, boolean deirectory) {
        this.name = name;
        this.details = details;
        this.deirectory = deirectory;
    }

    public String getName() {
        return name;
    }

    public String getDetials() {
        return details;
    }

    public boolean isDirectory() {
        return deirectory;
    }
    
}
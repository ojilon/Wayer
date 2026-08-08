package com.example.wayer.ui;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class FileItemTest {

    @Test
    public void holdsFields() {
        FileItem item = new FileItem("photo.jpg", "/sdcard/photo.jpg", "2.0 MB", false, 2_000_000);

        assertEquals("photo.jpg", item.getName());
        assertEquals("/sdcard/photo.jpg", item.getPath());
        assertEquals("2.0 MB", item.getDetails());
        assertFalse(item.isDirectory());
        assertEquals(2_000_000L, item.getSizeBytes());
    }

    @Test
    public void directoryFlag() {
        FileItem dir = new FileItem("DCIM", "/sdcard/DCIM", "Folder", true, 0);
        assertTrue(dir.isDirectory());
        assertEquals(0L, dir.getSizeBytes());
    }
}

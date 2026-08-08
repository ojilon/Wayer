package com.example.wayer.storage;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.nio.file.Files;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/**
 * JVM unit tests for FileMutator using a temp directory.
 * Run: ./gradlew :app:testDebugUnitTest
 */
public class FileMutatorTest {

    private File tempDir;

    @Before
    public void setUp() throws Exception {
        tempDir = Files.createTempDirectory("wayer_test_").toFile();
    }

    @After
    public void tearDown() {
        if (tempDir != null && tempDir.exists()) {
            FileMutator.delete(tempDir.getAbsolutePath());
        }
    }

    @Test
    public void createFileAndDelete() {
        FileMutator.Result created = FileMutator.createFile(tempDir.getAbsolutePath(), "note.txt");
        assertTrue(created.message, created.ok);

        File f = new File(tempDir, "note.txt");
        assertTrue(f.isFile());

        FileMutator.Result deleted = FileMutator.delete(f.getAbsolutePath());
        assertTrue(deleted.message, deleted.ok);
        assertFalse(f.exists());
    }

    @Test
    public void createDirectory() {
        FileMutator.Result r = FileMutator.createDirectory(tempDir.getAbsolutePath(), "my folder");
        assertTrue(r.message, r.ok);

        File dir = new File(tempDir, "my_folder"); // spaces sanitized
        assertTrue(dir.isDirectory());
    }

    @Test
    public void renameFile() {
        FileMutator.createFile(tempDir.getAbsolutePath(), "old.txt");
        File old = new File(tempDir, "old.txt");

        FileMutator.Result r = FileMutator.rename(old.getAbsolutePath(), "new.txt");
        assertTrue(r.message, r.ok);
        assertFalse(old.exists());
        assertTrue(new File(tempDir, "new.txt").exists());
    }

    @Test
    public void deleteNonEmptyFolder() {
        FileMutator.createDirectory(tempDir.getAbsolutePath(), "box");
        File box = new File(tempDir, "box");
        FileMutator.createFile(box.getAbsolutePath(), "inside.txt");

        FileMutator.Result r = FileMutator.delete(box.getAbsolutePath());
        assertTrue(r.message, r.ok);
        assertFalse(box.exists());
    }

    @Test
    public void createDuplicateFails() {
        FileMutator.createFile(tempDir.getAbsolutePath(), "dup.txt");
        FileMutator.Result second = FileMutator.createFile(tempDir.getAbsolutePath(), "dup.txt");
        assertFalse(second.ok);
    }
}

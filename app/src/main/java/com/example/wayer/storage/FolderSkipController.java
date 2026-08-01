// File path: com/example/wayer/storage/FolderSkipController.java
package com.example.wayer.storage;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * Manages the state when a user searches for folders/files,
 * gets a numbered list, and needs to select one via index numbers.
 */
public class FolderSkipController {

    // Keeps a temporary memory of the last keyword search matches
    private List<String> activeNumberedMatches = new ArrayList<>();
    private boolean isFileSelectionMode = false;

    public void setActiveMatches(List<String> matches, boolean isFiles) {
        this.activeNumberedMatches = matches;
        this.isFileSelectionMode = isFiles;
    }

    public boolean hasActiveMatches() {
        return !activeNumberedMatches.isEmpty();
    }

    /**
     * Validates if the user's typed number maps to a valid search item path.
     */
    public String getPathByIndex(int index) {
        if (index < 1 || index > activeNumberedMatches.size()) {
            return null;
        }
        return activeNumberedMatches.get(index - 1); // convert to 0-based index
    }

    public boolean isFileSelectionMode() {
        return isFileSelectionMode;
    }

    public void clearState() {
        activeNumberedMatches.clear();
    }
}
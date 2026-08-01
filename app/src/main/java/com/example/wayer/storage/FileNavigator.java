// File path: com/example/wayer/storage/FileNavigator.java
package com.example.wayer.storage;

import android.os.Environment;
import java.io.File;

/**
 * Manages the structural internal state of where the terminal is currently looking.
 * It is completely independent of the Android UI view hierarchy.
 */
public class FileNavigator {
 
     /*an instance variable
     Every FileNavigator object created will get its own private
     copy of this variable
     */
    private File currentDir;
 
    /*constructor ->same name as the class and no return type
    -not a standard utility method, setup function that runs only once the exact
    moment it's used to create the object using 'new' .eg in new FileNavigator(...)
    -used to build the object and initialize its starting values

    =>constructor takes the temporary 'startingDir' and saves it inside
    this specific object's permanent currentDir variable
    */ 
    public FileNavigator(File startingDir) {
        /*this-> "this exact instance of the class I am currenlty inside"
        -File startingDir: temporary variable that only exists while the constructor
        is running
        */
        this.currentDir = startingDir;
    }

    /*
    -n.getCurrentDir(): asks the n object folder it "points to"
    -returns the File object
    */
    public File getCurrentDir() {
        return currentDir;
    }

    /**
     * Changes directory state using standard logic.
     * Returns a status log string or null if successful.
     */
    public String changeDirectory(String target) {
        if (target.isEmpty()) {
            return "Usage: cd (directory_name) or cd ..";
        }

        if (target.equals("..")) {
            File parent = currentDir.getParentFile();
            if (parent != null) {
                currentDir = parent;
                return null; // Navigation successful
            } else {
                return "Already mapping structural root node.";
            }
        }

        File nextTarget = new File(currentDir, target);
        if (nextTarget.exists() && nextTarget.isDirectory()) {
            currentDir = nextTarget;
            return null; // Navigation successful
        } else {
            return "System Error: Path element '" + target + "' not found.";
        }
    }


    /**
     * Requirement 1: Method to immediately pull up the absolute structural root node path.
     */
    public File getRootDirectory() {
        return Environment.getExternalStorageDirectory();
    }

    /**
     * Directly forces the navigation engine to jump instantly to a hidden deep path.
     */
    public void forceJumpToPath(String absolutePath) {
        File target = new File(absolutePath);
        if (target.exists() && target.isDirectory()) {
            this.currentDir = target;
        }
    }
}
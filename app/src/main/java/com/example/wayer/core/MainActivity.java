// File path: com/example/wayer/core/MainActivity.java
package com.example.wayer.core;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Environment;
import android.view.KeyEvent;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.view.KeyEvent;
import android.widget.TextView;

import com.example.wayer.R;
import com.example.wayer.network.NetworkCallback;
import com.example.wayer.network.NetworkManager;
import com.example.wayer.storage.FileMutator;
import com.example.wayer.storage.FileNavigator;
import com.example.wayer.storage.FileSearcher;
import com.example.wayer.storage.FileIndexer;
import com.example.wayer.storage.FolderSkipController;

import java.io.File;
import java.util.List;

public class MainActivity extends Activity {

    private TextView tvCurrentPath;
    private TextView tvTerminalOutput;
    private EditText etCommandInput;

    //fore more complex file navigation
    private FileIndexer indexer = new FileIndexer();
    private FolderSkipController skipController = new FolderSkipController();
    private String appDownloadPath = null; // Stores your downloadable target variable
    
    // Core engine module states
    private FileNavigator navigator;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Connects to layout tree inside res/layout/activity_main.xml file
        setContentView(R.layout.activity_main);

        tvCurrentPath = findViewById(R.id.tv_current_path);
        tvTerminalOutput = findViewById(R.id.tv_terminal_output);
        etCommandInput = findViewById(R.id.et_command_input);

        // Initialize file structural navigator controller state

        /*
        get absolute path to external storage (/storage/emulate/0)
        or root of internal storage folder when plug into computer
        Environment: built in android framework utility class that knows about the device's layout
        .getExternalStorageDirectory() asks for the user's main storage location

        =>Save the location pointer to variable called initialDir(storage directory path)
        =>initialDir assigned to currentDir(this.currentDir) inside FileNavigator
        =>"navigator", 'remembers' where to look inside device's storage disk
        */
        File initialDir = Environment.getExternalStorageDirectory(); 
        navigator = new FileNavigator(initialDir);
        updatePathDisplay();

        // validate storage permissions
        String[] permissions = {
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        };
        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(permissions, 101);
        }

        // Watching keyboard enter actions
        /*
        -etCommand: EditText view, input box where you type commmands
        -.setOnEditAcctionListener(...): android method that tells the iput box to for keyboard
          actions.
        -new TextView.OneditorAcctionListener(){...}: an Anonymous inner class => creates a 
            temporary nameless implementation of the listener just for the current input box.
        */
        etCommandInput.setOnEditorActionListener(new TextView.OnEditorActionListener() {

            /*
            function is called whenever user is interacting with the keyboard
            -TextView v: view the user is typing into when they trigggered the action
               It points right back to etCommandInput in this case
            -int actionId: simple number representing the software action button pressed on the 
              screens digital keyboard .eg the checkmark icon
            -java.lang.KeyEvent event: when user is utilizing physcial hardware keyboard 
              eg. bluetooth keyboard. Androip wraps the physical hardware event inside the 
              'KeyEvent' object. contains data like which exact physical switch was pushed down

            */
            @Override
            public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
                
                /*
                Catching the "Enter" key
                the 'if' ignores other standard keys such as 'A','B'
                -EditorInfo: Android class containing predefined constant ID numbers for
                  digital keyboard buttons
                -EditorInfo.IME_ACTION_DONE: the universal ID number for the "Done" button
                  n soft keyboard
                -event != null: checks if a physical key event happened, avoids crash if no
                hardware keyboard is plugged in.
                -event.getKeyCode(): Method that asks the physical event -> numerical code 
                  for physical key that was interacted with.
                -KeyEvent.KEYCODE_ENTER: standardized standard Id for the physical "return/Enter"
                  key on keyboard
                -event.getAction() == KeyEvent.ACTION_DOWN: keys have two physical phases,
                  ACTION_DOWN when press it down, and ACTION_UP when you let it go.
                  Makes sure the command runs only once(exact instant key is pressed down)
                */
                if (actionId == EditorInfo.IME_ACTION_DONE || (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER && event.getAction() == KeyEvent.ACTION_DOWN)) {
                    
                    /*
                    -etCommandInput.getText(): Fetches the text out of the input field, returned as
                     an editable object type, not a standard text string.
                    -.toString(): converts the editable object into a standard Java String.
                    -.trim(): removes blank spaces
                    */
                    String rawCommand = etCommandInput.getText().toString().trim();
                    if (!rawCommand.isEmpty()) {
                        executeCommand(rawCommand);
                        etCommandInput.setText("");//cleans the text box to make ready for next command 
                    }
                    return true; //gracefully handback the keyboard process
                }
                return false;
            }
        });
    }
    
    /*
    make sure the Android UI shows the actual internal java state
    .getAbsolutePath(): extracts the exact file system text path string eg "/storage/emulated/0"
    tvCurrentPath.setText(...): pushes the combined text directly into the TextView layout element
       (R.id.tv_current_path) for the user to read it.
    */
    private void updatePathDisplay() {
        tvCurrentPath.setText("Path: " + navigator.getCurrentDir().getAbsolutePath());
    }

    private void appendToConsole(final String text) {
        // Run on UI Thread ensures that background threads can safely report logs here
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tvTerminalOutput.append(text + "\n");
            }
        });
    }

    private void executeCommand(String input) {
        appendToConsole("> " + input);

        String[] parts = input.split(" ", 2);
        String command = parts[0];
        String argument = parts.length > 1 ? parts[1] : "";

        // 1. ROUTE NETWORK COMMAND PROCESSING LAYER
        if (command.startsWith("/")) {
            if (command.equalsIgnoreCase("/ask") || command.equalsIgnoreCase("/upload")) {
                NetworkManager.processProtocolCommand(input, navigator.getCurrentDir(), new NetworkCallback() {
                    @Override
                    public void onConsoleUpdate(String outputText) {
                        appendToConsole(outputText);
                    }

                    @Override
                    public void onOperationComplete(String finalResult) {
                        appendToConsole(finalResult);
                    }
                });
            } else {
                appendToConsole("Protocol Error: Unsupported networking rule '" + command + "'");
            }
            return;
        }

        // 2. ROUTE LOCAL STORAGE OPERATIONS COMMAND LAYER
        String standardCommand = command.toLowerCase();
        switch (standardCommand) {
            case "ls":
                handleListCommand();
                break;
            case "cd":
                String navigationError = navigator.changeDirectory(argument);
                if (navigationError != null) {
                    appendToConsole(navigationError);
                } else {
                    updatePathDisplay();
                }
                break;
            case "cls":
                tvTerminalOutput.setText("");
                break;
            case "stz":
                // Custom scaling command: converts text string spaces to underscores on disk file targets
                String mutationResult = FileMutator.sanitizeAndRenameFile(navigator.getCurrentDir(), argument);
                appendToConsole(mutationResult);
                break;
            case "find":
                // Custom scaling command: searches for target match patterns
                List<String> foundFiles = FileSearcher.findFilesContainingKeyword(navigator.getCurrentDir(), argument);
                if (foundFiles.isEmpty()) {
                    appendToConsole("No matching files found.");
                } else {
                    for (String match : foundFiles) appendToConsole(match);
                }
                break;

            case "refresh":
                appendToConsole("Traversing internal storage volumes... Please wait...");
                // Spin up a thread to avoid freezing the screen animation layer during deep IO crawl
                new Thread(new Runnable() {
                    @Override
                    public void run() {
                        indexer.rebuildCache(navigator.getRootDirectory());
                        appendToConsole("Cache built successfully! Storage mapped into HashMap indexes.");
                    }
                }).start();
                break;

            case "jump": // Requirement 3: Fast folder search and list matching numbers
                if (indexer.isCacheEmpty()) {
                    appendToConsole("Error: Cache database empty. Please execute 'refresh' command first.");
                    break;
                }
                if (argument.isEmpty()) {
                    appendToConsole("Usage: jump (folder_keyword)");
                    break;
                }
                
                List<String> matchedFolders = indexer.searchFoldersByKeyword(argument);
                if (matchedFolders.isEmpty()) {
                   appendToConsole("No matching directories located in the cache map.");
                } else {
                    skipController.setActiveMatches(matchedFolders, false); // Set mode to folder
                    appendToConsole("Matching Directories Found. Enter 'choose (number)' to jump instantly:");
                    for (int i = 0; i < matchedFolders.size(); i++) {
                        appendToConsole("[" + (i + 1) + "] " + matchedFolders.get(i));
                    }
                }
                break;

            case "findfile": // Requirement 3 (Part 3): Global instant numbered file search
                if (indexer.isCacheEmpty()) {
                    appendToConsole("Error: Cache empty. Run 'refresh' first.");
                break;
                }
                
                List<String> matchedFiles = indexer.searchFilesByKeyword(argument);
                if (matchedFiles.isEmpty()) {
                    appendToConsole("No matching files found.");
                } else {
                    skipController.setActiveMatches(matchedFiles, true); // Set mode to files
                    appendToConsole("Matching Files Located. Enter 'choose (number)' to act on it:");
                    for (int i = 0; i < matchedFiles.size(); i++) {
                         appendToConsole("[" + (i + 1) + "] " + matchedFiles.get(i));
                    }
                }
                break;

            case "choose": // Interactive index option processor
                if (!skipController.hasActiveMatches()) {
                     appendToConsole("Error: No active search items to select from.");
                     break;
                }
                try {
                    int selectionIndex = Integer.parseInt(argument);
                    String selectedPath = skipController.getPathByIndex(selectionIndex);
                    if (selectedPath == null) {
                        appendToConsole("Invalid selection range.");
                        break;
                    }

                    if (!skipController.isFileSelectionMode()) {
                        // It's a folder: Jump instantly there and print items under it
                        navigator.forceJumpToPath(selectedPath);
                        updatePathDisplay();
                        skipController.clearState(); // Clear temporary selection state
                        appendToConsole("Jump Complete. Content inside folder:\n");
                        handleListCommand();

                    } else {
                        // It's a file: Show options or trigger networking automated upload!
                        appendToConsole("File Selected: " + selectedPath);
                        appendToConsole("Automating upload initialization sequence...");
                    
                        // Requirement 6: Analyze and clean filename before triggering Network transaction
                        File fileObject = new File(selectedPath);
                        String cleanedName = com.example.wayer.utils.TextSanitizer.replaceSpacesWithUnderscores(fileObject.getName());
                    
                        if (!fileObject.getName().equals(cleanedName)) {
                            appendToConsole("Analyzer Alert: Name contains spaces. Auto-sanitizing path elements...");
                            File fixedFile = new File(fileObject.getParentFile(), cleanedName);
                            fileObject.renameTo(fixedFile);
                            selectedPath = fixedFile.getAbsolutePath();
                        }

                        // Trigger your existing NetworkManager directly using the indexed path
                        com.example.wayer.network.NetworkManager.processProtocolCommand("/upload " + fileObject.getName(), fileObject.getParentFile(), new com.example.wayer.network.NetworkCallback() {
                        @Override
                        public void onConsoleUpdate(String o) { appendToConsole(o); }
                        @Override
                        public void onOperationComplete(String f) { appendToConsole(f); }
                        });
                        skipController.clearState();
                    }
                } catch (NumberFormatException e) {
                    appendToConsole("Error: Please provide a valid integer selection number.");
                }
                break;

            case "mkdir": // Requirement 4: Create folder on the fly in the active workspace directory
                String mkDirResult = FileMutator.createNewDirectory(navigator.getCurrentDir().getAbsolutePath(), argument);
                appendToConsole(mkDirResult);
                break;

            case "setdownloadpath": // Requirement 5: Set customized download storage paths
                 if (argument.isEmpty()) {
                     appendToConsole("Current download path pointer: " + (appDownloadPath == null ? "Default Workspace" : appDownloadPath));
                }else {
                    File targetLocation = new File(argument);
                    if (targetLocation.exists() && targetLocation.isDirectory()) {
                        appDownloadPath = targetLocation.getAbsolutePath();
                        appendToConsole("Download target modified to: " + appDownloadPath);
                    } else {
                         appendToConsole("Error: Specified directory does not exist.");
                    }
                }
                break;

            case "sanitizepath": // Requirement 7: Batch clean spaces inside current view space folder
                String batchResult = FileMutator.batchSanitizeFolderContents(navigator.getCurrentDir());
                appendToConsole(batchResult);
                 break;


            default:
                appendToConsole("Error: Unknown utility command '" + command + "'");
                break;
        }
    }

    private void handleListCommand() {
        try {
            File[] files = navigator.getCurrentDir().listFiles();
            if (files == null) {
                appendToConsole("Access Denied: Path target cannot be opened.");
                return;
            }
            if (files.length == 0) {
                appendToConsole("(empty directory)");
                return;
            }
            for (File file : files) {
                appendToConsole(file.isDirectory() ? "[" + file.getName() + "]/" : file.getName());
            }
        } catch (Exception e) {
            appendToConsole("System File Error: " + e.getMessage());
        }
    }
}
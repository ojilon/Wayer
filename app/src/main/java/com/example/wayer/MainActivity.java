package com.example.wayer;

//SECURITY AND STORAGE SETTINGS

/*gives access to android system constants; the storage
permissions
*/
import android.Manifest;

/*checks whether permissions have been granted by the
user or the OS
*/
import android.content.pm.PackageManager;

/*provides access to environment variables and root
paths for device storage locations
*/
import android.os.Environment;

//INBUILT JAVA UTILITIES

/*used to list, enter and read directories*/
import java.io.File;

//THE UI AND LIFECYCLE COMPONENTS

import android.app.Activity; //provides the class for creating windowed UI in android

/*os.Bundle passes data between android activities
also saves screen configuration changes such as rotating the screen
*/
import android.os.Bundle;

/*capture hardware keyboard events such as when one presses a key*/
import android.view.KeyEvent;

/*defines soft keyboard actions*/
import android.view.inputmethod.EditorInfo;

/*provides an editable text field component where a person
can type his or her commands */
import android.widget.EditText;

/*provides the text views for displaying data
example is terminal history, regarding this
project*/
import android.widget.TextView;


public class MainActivity extends Activity {

    /*
    GLOBAL CLASS VARIABLES:
     - tvCurrentPath -> From .TextView; displays the path string
    of the folder user is looking for
     -tvTerminalOutput -> From .TextView; acts as a monitor for 
     the scrolling, example when viewing output history.
     -etCommandInput -> From .EditText; the input box where users
     type the commands
     -currentDir -> From .File; A state pointer which tracks the
     directory which user is navigating.  
    */

    private TextView tvCurrentPath;
    private TextView tvTerminalOutput;
    private EditText etCommandInput;
    private File currentDir;

    /*Overriden lifecycle method
    - Initializes screen when app starts; links the layout
    definitions to the xml layout configurations 
    (R.layout.activity_main).
    -Sets the initial ddirectory to the primary external storage.
    -Asks the phone permissions to read and write files
    -Configures an event listener on the input box to wait for 
    the "enter" key
    */
    @Override
    protected void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tvCurrentPath = findViewById(R.id.tv_current_path);
        tvTerminalOutput = findViewById(R.id.tv_terminal_output);
        etCommandInput = findViewById(R.id.et_command_input);

        // Map primary storage environment node path pointer
        currentDir = Environment.getExternalStorageDirectory();
        updatePathDisplay();

        // Boot validation storage safety pass verification routine
        String[] permissions = {
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        };

        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(permissions, 101);
        }

        // Action input handler watching keyboard command confirmations
        etCommandInput.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
                if (actionId == EditorInfo.IME_ACTION_DONE || 
                    (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER && event.getAction() == KeyEvent.ACTION_DOWN)) {
                    
                    String rawCommand = etCommandInput.getText().toString().trim();
                    if (!rawCommand.isEmpty()) {
                        executeCommand(rawCommand);
                        etCommandInput.setText(""); 
                    }
                    return true;
                }
                return false;
            }
        });
    }
    

    /*Helper method
    -Gets the absolute path of the string of currentDirand changes the 
    text on tvCurrentPath, 
    Allows user to know the folder in which he or she is in*/
    private void updatePathDisplay() {
        tvCurrentPath.setText("Path: " + currentDir.getAbsolutePath());
    }

    /*Helper method: param -> String text
    - Adds a string line to the tvTerminalOutput view
    -moves to a new line (\n)
    */
    private void appendToConsole(String text) {
        tvTerminalOutput.append(text + "\n");
    }

    /*Method for decision logic
    -splits the entered text into two pieces:
      ->the main command word eg /ask, /upload
      ->the modifiers words after the main command
    -If starts with '/', treats the command as a special networking task
    -If a system string eg ls, initiates the internal directory helpers
    */
    private void executeCommand(String input) {
        appendToConsole("> " + input);

        String[] parts = input.split(" ", 2);
        String command = parts[0];
        String argument = parts.length > 1 ? parts[1] : "";

        // Route Custom Application Protocol Networking Tasks
        if (command.startsWith("/")) {
            if (command.equalsIgnoreCase("/ask") || command.equalsIgnoreCase("/upload")) {
                new NetworkEngine(currentDir, new NetworkEngine.OnNetworkResultListener() {
                    @Override
                    public void onUpdateConsole(String text) {
                        appendToConsole(text);
                    }
                }).execute(input);
            } else {
                appendToConsole("Protocol Error: Unsupported networking rule '" + command + "'");
            }
            return;
        }

        // Core Native Local Directory Parsing Layout Logic
        String standardCommand = command.toLowerCase();
        if (standardCommand.equals("ls")) {
            handleListCommand();
        } else if (standardCommand.equals("cd")) {
            handleChangeDirectoryCommand(argument);
        } else if (standardCommand.equals("clear")) {
            tvTerminalOutput.setText("");
        } else {
            appendToConsole("Error: Unknown utility command '" + command + "'");
        }
    }

    private void handleListCommand() {
        try {
            File[] files = currentDir.listFiles();
            if (files == null) {
                appendToConsole("Access Denied: Path target cannot be opened.");
                return;
            }
            if (files.length == 0) {
                appendToConsole("(empty directory)");
                return;
            }
            for (File file : files) {
                if (file.isDirectory()) {
                    appendToConsole("[" + file.getName() + "]/");
                } else {
                    appendToConsole(file.getName());
                }
            }
        } catch (Exception e) {
            appendToConsole("System File Error: " + e.getMessage());
        }
    }

    private void handleChangeDirectoryCommand(String target) {
        if (target.isEmpty()) {
            appendToConsole("Usage: cd (directory_name) or cd ..");
            return;
        }

        if (target.equals("..")) {
            File parent = currentDir.getParentFile();
            if (parent != null) {
                currentDir = parent;
                updatePathDisplay();
            } else {
                appendToConsole("Already mapping structural root node.");
            }
            return;
        }

        File nextTarget = new File(currentDir, target);
        if (nextTarget.exists() && nextTarget.isDirectory()) {
            currentDir = nextTarget;
            updatePathDisplay();
        } else {
            appendToConsole("System Error: Path element '" + target + "' not found.");
        }
    }
}
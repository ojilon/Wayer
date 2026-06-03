package com.example.wayer;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Environment;
import android.view.KeyEvent;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.TextView;
import java.io.File;

public class MainActivity extends Activity {

    private TextView tvCurrentPath;
    private TextView tvTerminalOutput;
    private EditText etCommandInput;
    private File currentDir;

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

    private void updatePathDisplay() {
        tvCurrentPath.setText("Path: " + currentDir.getAbsolutePath());
    }

    private void appendToConsole(String text) {
        tvTerminalOutput.append(text + "\n");
    }

    private void executeCommand(String input) {
        appendToConsole("> " + input);

        String[] parts = input.split(" ", 2);
        String command = parts[0];
        String argument = parts.length > 1 ? parts[1] : "";

        // Route Custom Application Protocol Networking Tasks
        if (command.startsWith("/")) {
            if (command.equalsIgnoreCase("/ask") || command.equalsIgnoreCase("/upload") || command.equalsIgnoreCase("/push")) {
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
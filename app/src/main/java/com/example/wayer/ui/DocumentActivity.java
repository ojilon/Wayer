package com.example.wayer.ui;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.example.wayer.databinding.ActivityDocumentBinding;
import com.example.wayer.core.NativeEngine;

/**
 * Full-window document viewer / editor.
 *
 * How to launch from FilesFragment (or anywhere):
 *
 *   DocumentActivity.open(context, fullFilePath);
 *
 * Later:
 *   - Java will send the path to C++ (bulk or single open request)
 *   - C++ (with chosen libraries) will produce pages / text / preview
 *   - Java only displays the result inside document_container
 */
public class DocumentActivity extends AppCompatActivity {

    public static final String EXTRA_FILE_PATH = "file_path";

    private ActivityDocumentBinding binding;
    private String filePath;

    /** Convenience launcher */
    public static void open(Context context, String filePath) {
        Intent intent = new Intent(context, DocumentActivity.class);
        intent.putExtra(EXTRA_FILE_PATH, filePath);
        context.startActivity(intent);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        binding = ActivityDocumentBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        filePath = getIntent().getStringExtra(EXTRA_FILE_PATH);
        if (filePath == null || filePath.isEmpty()) {
            Toast.makeText(this, "No file path provided", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        setupToolbar();
        showFileInfo();

        // Future: ask C++ to open / prepare the document
        // NativeEngine.processActionAsync(ACTION_OPEN_DOCUMENT, filePath, result -> { ... });
    }

    private void setupToolbar() {
        binding.toolbar.setNavigationOnClickListener(v -> finish());
        binding.btnClose.setOnClickListener(v -> finish());

        // Show only the file name in the toolbar
        String name = filePath;
        int slash = filePath.lastIndexOf('/');
        if (slash >= 0 && slash < filePath.length() - 1) {
            name = filePath.substring(slash + 1);
        }
        binding.toolbar.setTitle(name);
    }

    private void showFileInfo() {
        binding.docPath.setText(filePath);
        binding.placeholder.setText(
                "Document viewer foundation\n\n" +
                "File: " + filePath + "\n\n" +
                "C++ rendering will appear here\n" +
                "after libraries are chosen"
        );
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        binding = null;
    }
}

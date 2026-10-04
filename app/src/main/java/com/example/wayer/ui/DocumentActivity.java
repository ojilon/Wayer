package com.example.wayer.ui;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.example.wayer.databinding.ActivityDocumentBinding;
import com.example.wayer.bridge.NativeEngine;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Full-window document viewer (read-only).
 *
 * How to launch from FilesFragment (or anywhere):
 *
 *   DocumentActivity.open(context, fullFilePath);
 *
 * Text-like files are rendered through the C++ wayer_preview module
 * (capped, binary refused). Rich rendering via third_party engines
 * remains a later step; Java only displays what native returns.
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
        loadPreview();
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
    }

    /** Read-only preview through wayer_preview (action 19). No writes, ever. */
    private void loadPreview() {
        binding.placeholder.setMovementMethod(new ScrollingMovementMethod());
        binding.placeholder.setText("Reading…");
        NativeEngine.readTextFileAsync(filePath, 64 * 1024, rawJson -> {
            if (isFinishing() || binding == null) return;
            try {
                JSONObject data = new JSONObject(rawJson);
                if (data.has("error")) {
                    binding.placeholder.setText("Cannot preview: " + data.optString("error"));
                    return;
                }
                if (data.optBoolean("binary", false)) {
                    binding.placeholder.setText(
                            "Binary file — content withheld.\n\nSize: " + data.optLong("size", 0) + " bytes");
                    return;
                }
                JSONArray lines = data.optJSONArray("lines");
                StringBuilder sb = new StringBuilder();
                if (lines != null) {
                    for (int i = 0; i < lines.length(); i++) {
                        if (i > 0) sb.append('\n');
                        sb.append(lines.optString(i));
                    }
                }
                if (data.optBoolean("truncated", false)) {
                    sb.append("\n\n… truncated after ").append(data.optLong("size", 0)).append(" bytes");
                }
                binding.placeholder.setText(sb.length() == 0 ? "(empty file)" : sb.toString());
            } catch (JSONException e) {
                binding.placeholder.setText("Cannot preview this file.");
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        binding = null;
    }
}

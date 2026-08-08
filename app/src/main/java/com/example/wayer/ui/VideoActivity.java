package com.example.wayer.ui;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.MediaController;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.example.wayer.databinding.ActivityVideoBinding;

import java.io.File;

/**
 * Full-window video viewer.
 * Uses Android VideoView for now.
 * Later: optional C++ / third_party pipeline for advanced codecs.
 */
public class VideoActivity extends AppCompatActivity {

    public static final String EXTRA_FILE_PATH = "file_path";

    private ActivityVideoBinding binding;

    public static void open(Context context, String filePath) {
        Intent intent = new Intent(context, VideoActivity.class);
        intent.putExtra(EXTRA_FILE_PATH, filePath);
        context.startActivity(intent);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityVideoBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        String path = getIntent().getStringExtra(EXTRA_FILE_PATH);
        if (path == null || path.isEmpty()) {
            Toast.makeText(this, "No video path", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        binding.toolbar.setNavigationOnClickListener(v -> finish());
        binding.btnClose.setOnClickListener(v -> finish());
        binding.videoPath.setText(path);

        String name = path.substring(path.lastIndexOf('/') + 1);
        binding.toolbar.setTitle(name);

        playVideo(path);
    }

    private void playVideo(String path) {
        File file = new File(path);
        if (!file.exists()) {
            binding.placeholder.setText("File not found\n" + path);
            return;
        }

        MediaController controller = new MediaController(this);
        controller.setAnchorView(binding.videoView);
        binding.videoView.setMediaController(controller);
        binding.videoView.setVideoURI(Uri.fromFile(file));
        binding.videoView.setOnPreparedListener(mp -> {
            binding.placeholder.setVisibility(View.GONE);
            binding.videoView.start();
        });
        binding.videoView.setOnErrorListener((mp, what, extra) -> {
            binding.placeholder.setText("Cannot play this video\n" + path);
            binding.placeholder.setVisibility(View.VISIBLE);
            return true;
        });
    }

    @Override
    protected void onDestroy() {
        if (binding != null) {
            binding.videoView.stopPlayback();
        }
        super.onDestroy();
        binding = null;
    }
}

package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import com.example.wayer.R;
import com.example.wayer.databinding.FragmentHomeBinding;
import com.example.wayer.core.NativeEngine;
import com.example.wayer.core.MainActivity;

import org.json.JSONObject;
import org.json.JSONException;

public class HomeFragment extends Fragment {

    private FragmentHomeBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        setupUI();
        return binding.getRoot();
    }

    private void setupUI() {
        // C++ Action 7 → full storage stats + category breakdown (one big JSON)
        NativeEngine.processActionAsync(7, "/storage/emulated/0", rawJson -> {
            try {
                JSONObject data = new JSONObject(rawJson);

                int progress = data.getInt("progress_percent");
                long usedBytes = data.getLong("used_bytes");
                long totalBytes = data.getLong("total_bytes");

                binding.storageProgress.setProgress(progress);
                binding.storageSummary.setText(
                    formatSize(usedBytes) + " used of " + formatSize(totalBytes)
                );

                // Category breakdown
                if (data.has("breakdown")) {
                    JSONObject b = data.getJSONObject("breakdown");
                    binding.catImages.setText(formatSize(b.optLong("images", 0)));
                    binding.catVideos.setText(formatSize(b.optLong("videos", 0)));
                    binding.catAudio.setText(formatSize(b.optLong("audio", 0)));
                    binding.catDocuments.setText(formatSize(b.optLong("documents", 0)));
                    binding.catOthers.setText(formatSize(b.optLong("others", 0)));
                }
            } catch (JSONException e) {
                e.printStackTrace();
                binding.storageSummary.setText("Failed to load storage info");
            }
        });

        // Quick actions → bottom navigation
        binding.actionFiles.setOnClickListener(v ->
            ((MainActivity) requireActivity()).navigateTo(R.id.nav_files)
        );

        binding.actionTransfer.setOnClickListener(v ->
            ((MainActivity) requireActivity()).navigateTo(R.id.nav_transfer)
        );

        binding.actionStorage.setOnClickListener(v ->
            ((MainActivity) requireActivity()).navigateTo(R.id.nav_storage)
        );

        binding.actionTerminal.setOnClickListener(v ->
            Toast.makeText(getContext(), "Terminal – coming soon", Toast.LENGTH_SHORT).show()
        );
    }

    /** Convert bytes → human readable (KB / MB / GB) */
    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
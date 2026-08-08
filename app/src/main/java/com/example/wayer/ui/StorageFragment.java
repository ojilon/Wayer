package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentStorageBinding;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Storage overview + cleanup entry points.
 * Heavy stats come from C++ (Action 7). Java only displays.
 */
public class StorageFragment extends Fragment {

    private static final int ACTION_STORAGE_STATS = 7;
    private static final String ROOT = "/storage/emulated/0";

    private FragmentStorageBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentStorageBinding.inflate(inflater, container, false);
        setupButtons();
        loadStats();
        return binding.getRoot();
    }

    private void setupButtons() {
        binding.btnRefreshStorage.setOnClickListener(v -> loadStats());

        binding.btnScanLarge.setOnClickListener(v ->
                Toast.makeText(getContext(),
                        "Large-file scan will use C++ next (bulk JSON)",
                        Toast.LENGTH_SHORT).show()
        );
    }

    private void loadStats() {
        binding.storageSummary.setText("Calculating…");

        NativeEngine.processActionAsync(ACTION_STORAGE_STATS, ROOT, rawJson -> {
            if (binding == null) return;

            try {
                JSONObject data = new JSONObject(rawJson);
                if (data.has("error")) {
                    binding.storageSummary.setText("Error loading storage");
                    return;
                }

                long used = data.getLong("used_bytes");
                long total = data.getLong("total_bytes");
                long free = data.optLong("free_bytes", total - used);
                int progress = data.getInt("progress_percent");

                binding.storageProgress.setProgress(progress);
                binding.storageSummary.setText(formatSize(used) + " used of " + formatSize(total));
                binding.storageFree.setText(formatSize(free) + " free");

                if (data.has("breakdown")) {
                    JSONObject b = data.getJSONObject("breakdown");
                    long images = b.optLong("images", 0);
                    long videos = b.optLong("videos", 0);
                    long audio = b.optLong("audio", 0);
                    long docs = b.optLong("documents", 0);
                    long others = b.optLong("others", 0);

                    binding.catImages.setText(formatSize(images));
                    binding.catVideos.setText(formatSize(videos));
                    binding.catAudio.setText(formatSize(audio));
                    binding.catDocuments.setText(formatSize(docs));
                    binding.catOthers.setText(formatSize(others));

                    updateBarWeights(images, videos, audio, docs, others);
                }
            } catch (JSONException e) {
                e.printStackTrace();
                binding.storageSummary.setText("Failed to parse storage data");
            }
        });
    }

    /** Set LinearLayout weights so the stacked bar reflects real proportions. */
    private void updateBarWeights(long images, long videos, long audio, long docs, long others) {
        long sum = images + videos + audio + docs + others;
        if (sum <= 0) sum = 1;

        setWeight(binding.barImages, images, sum);
        setWeight(binding.barVideos, videos, sum);
        setWeight(binding.barAudio, audio, sum);
        setWeight(binding.barDocs, docs, sum);
        setWeight(binding.barOthers, others, sum);
    }

    private void setWeight(View view, long value, long total) {
        ViewGroup.LayoutParams lp = view.getLayoutParams();
        if (lp instanceof android.widget.LinearLayout.LayoutParams) {
            android.widget.LinearLayout.LayoutParams llp =
                    (android.widget.LinearLayout.LayoutParams) lp;
            // Minimum visible weight so empty categories still show a thin line
            float w = value <= 0 ? 0.02f : (float) value / (float) total;
            llp.weight = w;
            view.setLayoutParams(llp);
        }
    }

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

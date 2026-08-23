package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.core.view.GravityCompat;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.wayer.core.GlassBlur;
import com.example.wayer.core.NativeEngine;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.databinding.FragmentStorageBinding;
import com.example.wayer.storage.FileMutator;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class StorageFragment extends Fragment {

    private static final int ACTION_STORAGE_STATS = 7;
    private static final int ACTION_FIND_LARGE    = 9;
    private static final String ROOT = "/storage/emulated/0";
    private static final long MIN_BYTES = 10L * 1024 * 1024;

    private FragmentStorageBinding binding;
    private FileAdapter largeAdapter;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentStorageBinding.inflate(inflater, container, false);
        setupLargeList();
        setupButtons();
        setupSidebar();
        loadStats();
        return binding.getRoot();
    }

    private void setupSidebar() {
        binding.btnOpenStorageDrawer.setOnClickListener(v ->
                binding.storageDrawerLayout.openDrawer(GravityCompat.END));

        View panel = binding.storageOptionsSidebar.getRoot();
        binding.storageOptionsSidebar.sidebarTitle.setText("Storage options");
        refreshAppearanceLabels();
        GlassBlur.applyFromPrefs(panel, requireContext());

        binding.storageOptionsSidebar.btnTheme.setOnClickListener(v -> {
            String label = ThemePrefs.cycle(requireContext());
            refreshAppearanceLabels();
            if (getActivity() != null) UiChrome.apply(getActivity());
            Toast.makeText(getContext(), "Theme: " + label, Toast.LENGTH_SHORT).show();
        });

        binding.storageOptionsSidebar.btnBlur.setOnClickListener(v -> {
            if (!GlassBlur.isSupported()) {
                Toast.makeText(getContext(), "Blur needs Android 12+", Toast.LENGTH_SHORT).show();
                return;
            }
            boolean on = ThemePrefs.toggleBlur(requireContext());
            GlassBlur.applyFromPrefs(panel, requireContext());
            refreshAppearanceLabels();
            Toast.makeText(getContext(), on ? "Glass blur on" : "Glass blur off", Toast.LENGTH_SHORT).show();
        });
    }

    private void refreshAppearanceLabels() {
        if (binding == null) return;
        String theme = ThemePrefs.currentLabel(requireContext());
        binding.storageOptionsSidebar.themeLabel.setText("Theme: " + theme);
        binding.storageOptionsSidebar.btnTheme.setText("Cycle theme (" + theme + ")");

        boolean blur = ThemePrefs.isBlurEnabled(requireContext());
        String blurTxt = !GlassBlur.isSupported()
                ? "Glass blur: N/A (API < 31)"
                : (blur ? "Glass blur: On" : "Glass blur: Off");
        binding.storageOptionsSidebar.blurLabel.setText(blurTxt);
        binding.storageOptionsSidebar.btnBlur.setText(
                GlassBlur.isSupported() ? "Toggle glass blur" : "Blur unavailable");
    }

    private void setupLargeList() {
        largeAdapter = new FileAdapter();
        binding.largeFilesList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.largeFilesList.setAdapter(largeAdapter);

        largeAdapter.setOnItemClickListener(new FileAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FileItem item) {
                FileOpenHelper.open(requireContext(), item.getPath());
            }

            @Override
            public void onItemLongClick(FileItem item) {
                new AlertDialog.Builder(requireContext())
                        .setTitle(item.getName())
                        .setItems(new String[]{"Open", "Delete", "Cancel"}, (d, which) -> {
                            if (which == 0) {
                                FileOpenHelper.open(requireContext(), item.getPath());
                            } else if (which == 1) {
                                confirmDeleteLarge(item);
                            }
                        })
                        .show();
            }
        });
    }

    private void confirmDeleteLarge(FileItem item) {
        new AlertDialog.Builder(requireContext())
                .setTitle("Delete large file?")
                .setMessage(item.getName() + "\n" + item.getDetails())
                .setPositiveButton("Delete", (d, w) -> {
                    FileMutator.Result r = FileMutator.delete(item.getPath());
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) {
                        scanLargeFiles();
                        loadStats();
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void setupButtons() {
        binding.btnRefreshStorage.setOnClickListener(v -> loadStats());
        binding.btnScanLarge.setOnClickListener(v -> scanLargeFiles());
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

    private void scanLargeFiles() {
        binding.largeFilesEmpty.setText("Scanning…");
        binding.largeFilesEmpty.setVisibility(View.VISIBLE);
        binding.btnScanLarge.setEnabled(false);

        String payload = ROOT + "|" + MIN_BYTES + "|50";

        NativeEngine.processActionAsync(ACTION_FIND_LARGE, payload, rawJson -> {
            if (binding == null) return;
            binding.btnScanLarge.setEnabled(true);

            List<FileItem> items = parseLargeFiles(rawJson);
            if (items.isEmpty()) {
                binding.largeFilesEmpty.setText("No files ≥ " + formatSize(MIN_BYTES));
                binding.largeFilesEmpty.setVisibility(View.VISIBLE);
                largeAdapter.submitList(null);
            } else {
                binding.largeFilesEmpty.setVisibility(View.GONE);
                largeAdapter.submitList(items);
            }
        });
    }

    private List<FileItem> parseLargeFiles(String rawJson) {
        List<FileItem> result = new ArrayList<>();
        try {
            JSONObject root = new JSONObject(rawJson);
            if (root.has("error")) {
                Toast.makeText(getContext(), root.getString("error"), Toast.LENGTH_SHORT).show();
                return result;
            }
            JSONArray files = root.optJSONArray("files");
            if (files == null) return result;

            for (int i = 0; i < files.length(); i++) {
                JSONObject o = files.getJSONObject(i);
                long size = o.optLong("size", 0);
                result.add(new FileItem(
                        o.getString("name"),
                        o.getString("path"),
                        formatSize(size),
                        false,
                        size
                ));
            }
        } catch (JSONException e) {
            e.printStackTrace();
            Toast.makeText(getContext(), "Failed to parse large files", Toast.LENGTH_SHORT).show();
        }
        return result;
    }

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

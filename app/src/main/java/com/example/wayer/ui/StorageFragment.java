package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.view.GravityCompat;
import androidx.fragment.app.Fragment;

import com.example.wayer.core.GlassBlur;
import com.example.wayer.bridge.Stats;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.databinding.FragmentStorageBinding;
import com.example.wayer.bridge.StatsSnapshot;

import org.json.JSONException;
import org.json.JSONObject;

public class StorageFragment extends Fragment {

    private FragmentStorageBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentStorageBinding.inflate(inflater, container, false);
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

    private void setupButtons() {
        binding.btnRefreshStorage.setOnClickListener(v -> loadStats(true));
    }

    private void loadStats() {
        loadStats(false);
    }

    private void loadStats(boolean force) {
        binding.storageSummary.setText("Calculating…");
        Stats.requestSnapshot(getContext(), force, this::handleStatsResult);
    }

    private void handleStatsResult(String rawJson) {
        if (binding == null) return;
        try {
            StatsSnapshot s = StatsSnapshot.parse(rawJson);
    
            binding.storageSummary.setText(
                    formatSize(s.usedBytes) + " used of " + formatSize(s.totalBytes));
            binding.storageFree.setText(formatSize(s.freeBytes) + " free");
    
            if (binding.catImages != null) binding.catImages.setText(formatSize(s.images));
            if (binding.catVideos != null) binding.catVideos.setText(formatSize(s.videos));
            if (binding.catAudio != null) binding.catAudio.setText(formatSize(s.audio));
            if (binding.catDocuments != null) binding.catDocuments.setText(formatSize(s.documents));
            if (binding.catSystem != null) binding.catSystem.setText(formatSize(s.system));
            if (binding.catOthers != null) binding.catOthers.setText(formatSize(s.others));
            // foreign if you still show it:
            // if (binding.catForeign != null) binding.catForeign.setText(formatSize(s.foreign));
    
            if (binding.catTotal != null) {
                binding.catTotal.setText(formatSize(s.categoriesTotal()));
            }
    
            if (binding.storageRing != null) {
                binding.storageRing.setCategoryBytes(
                        s.images, s.videos, s.audio, s.documents, s.system, s.others);
            }
        } catch (Exception e) {
            e.printStackTrace();
            binding.storageSummary.setText("Failed to load storage data");
        }
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

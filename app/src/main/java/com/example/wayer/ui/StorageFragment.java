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
            JSONObject data = new JSONObject(rawJson);
            if (data.has("error")) {
                binding.storageSummary.setText("Error loading storage");
                return;
            }

            int progress = data.getInt("progress_percent");
            long used = data.getLong("used_bytes");
            long total = data.getLong("total_bytes");
            long free = data.optLong("free_bytes", total - used);
            

            binding.storageProgress.setProgress(progress);
            binding.storageSummary.setText(formatSize(used) + " used of " + formatSize(total));
            binding.storageFree.setText(formatSize(free) + " free");

            if (data.has("breakdown")) {
                JSONObject b = data.getJSONObject("breakdown");
                long images = b.optLong("images", 0);
                long videos = b.optLong("videos", 0);
                long audio = b.optLong("audio", 0);
                long docs = b.optLong("documents", 0);
                long sys = b.optLong("system", 0);
                long others = b.optLong("others", 0);

                if(binding.catImages != null) binding.catImages.setText(formatSize(images));
                if(binding.catVideos != null) binding.catVideos.setText(formatSize(videos));
                if(binding.catAudio != null) binding.catAudio.setText(formatSize(audio));
                if(binding.catDocuments != null) binding.catDocuments.setText(formatSize(docs));
                if(binding.catSystem != null) binding.catSystem.setText(formatSize(sys));
                if(binding.catOthers != null) binding.catOthers.setText(formatSize(others));

                updateBarWeights(images, videos, audio, docs, sys, others);
            }
        } catch (JSONException e) {
            e.printStackTrace();
            binding.storageSummary.setText("Failed to parse storage data");
        }
    }

    private void updateBarWeights(long images, long videos, long audio, long docs,long sys, long others) {
        long sum = images + videos + audio + docs + sys +  others;
        if (sum <= 0) sum = 1;

        setWeight(binding.barImages, images, sum);
        setWeight(binding.barVideos, videos, sum);
        setWeight(binding.barAudio, audio, sum);
        setWeight(binding.barDocs, docs, sum);
        setWeight(binding.barSys, sys, sum);
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

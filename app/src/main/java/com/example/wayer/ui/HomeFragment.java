package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.view.GravityCompat;
import androidx.fragment.app.Fragment;

import com.example.wayer.R;
import com.example.wayer.core.GlassBlur;
import com.example.wayer.core.MainActivity;
import com.example.wayer.core.NativeEngine;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.databinding.FragmentHomeBinding;
import com.example.wayer.transfer.RecentTransfersStore;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.List;

public class HomeFragment extends Fragment {

    private FragmentHomeBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        setupUI();
        setupSidebar();
        return binding.getRoot();
    }

    private void setupSidebar() {
        binding.btnOpenHomeDrawer.setOnClickListener(v ->
                binding.homeDrawerLayout.openDrawer(GravityCompat.END));

        View panel = binding.homeOptionsSidebar.getRoot();
        binding.homeOptionsSidebar.sidebarTitle.setText("Home options");
        refreshAppearanceLabels();
        GlassBlur.applyFromPrefs(panel, requireContext());

        binding.homeOptionsSidebar.btnTheme.setOnClickListener(v -> {
            String label = ThemePrefs.cycle(requireContext());
            refreshAppearanceLabels();
            if (getActivity() != null) UiChrome.apply(getActivity());
            Toast.makeText(getContext(), "Theme: " + label, Toast.LENGTH_SHORT).show();
        });

        binding.homeOptionsSidebar.btnBlur.setOnClickListener(v -> {
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
        binding.homeOptionsSidebar.themeLabel.setText("Theme: " + theme);
        binding.homeOptionsSidebar.btnTheme.setText("Cycle theme (" + theme + ")");

        boolean blur = ThemePrefs.isBlurEnabled(requireContext());
        String blurTxt = !GlassBlur.isSupported()
                ? "Glass blur: N/A (API < 31)"
                : (blur ? "Glass blur: On" : "Glass blur: Off");
        binding.homeOptionsSidebar.blurLabel.setText(blurTxt);
        binding.homeOptionsSidebar.btnBlur.setText(
                GlassBlur.isSupported() ? "Toggle glass blur" : "Blur unavailable");
    }

    private void setupUI() {
        NativeEngine.processActionAsync(7, "/storage/emulated/0", rawJson -> {
            if (binding == null) return;
            try {
                JSONObject data = new JSONObject(rawJson);

                int progress = data.getInt("progress_percent");
                long usedBytes = data.getLong("used_bytes");
                long totalBytes = data.getLong("total_bytes");

                binding.storageProgress.setProgress(progress);
                binding.storageSummary.setText(
                    formatSize(usedBytes) + " used of " + formatSize(totalBytes)
                );

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

        refreshRecentTransfersHint();
    }

    private void refreshRecentTransfersHint() {
        List<RecentTransfersStore.Entry> list = RecentTransfersStore.load(requireContext());
        if (list.isEmpty()) {
            binding.recentTransfersEmpty.setText("No recent transfers");
        } else {
            RecentTransfersStore.Entry e = list.get(0);
            binding.recentTransfersEmpty.setText(
                    (e.download ? "↓ " : "↑ ") + e.name + " · and " + Math.max(0, list.size() - 1) + " more");
        }
    }

    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }

    @Override
    public void onResume() {
        super.onResume();
        if (binding != null) refreshRecentTransfersHint();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}

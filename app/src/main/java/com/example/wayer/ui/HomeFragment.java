package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.view.GravityCompat;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.wayer.R;
import com.example.wayer.bridge.AppDirs;
import com.example.wayer.bridge.NativeCache;
import com.example.wayer.bridge.NativeEngine;
import com.example.wayer.bridge.PathCache;
import com.example.wayer.bridge.Stats;
import com.example.wayer.core.GlassBlur;
import com.example.wayer.core.MainActivity;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.databinding.FragmentHomeBinding;
import com.example.wayer.transfer.RecentTransfersStore;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class HomeFragment extends Fragment implements DaySectionAdapter.Listener {

    private FragmentHomeBinding binding;
    private DaySectionAdapter daysAdapter;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
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
        
        // --- day grid ---
        daysAdapter = new DaySectionAdapter(this);
        binding.homeDaysList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.homeDaysList.setAdapter(daysAdapter);
        binding.homeDaysStatus.setText("Indexing files…");

        loadFilesByDay();

        // shortcuts (unchanged)
        binding.actionFiles.setOnClickListener(v ->
                ((MainActivity) requireActivity()).navigateTo(R.id.nav_files));
        binding.actionTransfer.setOnClickListener(v ->
                ((MainActivity) requireActivity()).navigateTo(R.id.nav_transfer));
        binding.actionStorage.setOnClickListener(v ->
                ((MainActivity) requireActivity()).navigateTo(R.id.nav_storage));
        binding.actionTerminal.setOnClickListener(v ->
                Toast.makeText(getContext(), "Terminal – coming soon", Toast.LENGTH_SHORT).show());

        refreshRecentTransfersHint();
    }

    /**
     * 1) Build / refresh index (paths + size + mtime) into cache/index/files.json
     * 2) Group that file by day into cache/index/files_by_day.json
     * 3) Read the by-day JSON and show it
     */
    private void loadFilesByDay() {
        String root = AppDirs.externalRoot().getPath();

        NativeEngine.buildIndexAsync(requireContext(), root, buildRaw -> {
            if (binding == null || getActivity() == null) return;

            NativeEngine.groupIndexByDayAsync(requireContext(), 14, 50, groupRaw -> {
                if (binding == null || getActivity() == null) return;

                String path = PathCache.envelopePath(groupRaw);
                String json = PathCache.readFile(path);
                if (json == null) {
                    json = PathCache.readFile(NativeCache.filesByDayPath(requireContext()));
                }
                final String content = json;
                getActivity().runOnUiThread(() -> applyDaysJson(content));
            });
        });
    }

    private void applyDaysJson(String json) {
        if (binding == null) return;
        if (json == null || json.isEmpty()) {
            binding.homeDaysStatus.setText("No day data yet");
            daysAdapter.submit(new ArrayList<>());
            return;
        }
        try {
            JSONObject root = new JSONObject(json);
            if (root.has("error")) {
                binding.homeDaysStatus.setText("Error: " + root.optString("error"));
                return;
            }
            JSONArray days = root.optJSONArray("days");
            List<DaySection> list = new ArrayList<>();
            if (days != null) {
                for (int i = 0; i < days.length(); i++) {
                    JSONObject d = days.getJSONObject(i);
                    DaySection section = new DaySection(d.optString("day", ""));
                    JSONArray files = d.optJSONArray("files");
                    if (files != null) {
                        for (int j = 0; j < files.length(); j++) {
                            JSONObject f = files.getJSONObject(j);
                            section.files.add(new DaySection.FileEntry(
                                    f.optString("path", ""),
                                    f.optString("name", ""),
                                    f.optString("kind", "other"),
                                    f.optLong("size", 0),
                                    f.optLong("mtime", 0)
                            ));
                        }
                    }
                    list.add(section);
                }
            }
            daysAdapter.submit(list);
            binding.homeDaysStatus.setText(
                    list.isEmpty() ? "No recent files" : (list.size() + " day(s)"));
        } catch (Exception e) {
            binding.homeDaysStatus.setText("Failed to parse day list");
        }
    }

    @Override
    public void onSeeMore(DaySection section) {
        // v1: toast; later open a full list fragment with section.day
        Toast.makeText(getContext(),
                "See more: " + section.day + " (" + section.files.size() + " files)",
                Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onFileClick(DaySection.FileEntry file) {
        FileOpenHelper.open(requireContext(), file.path);
    }

    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }

    private void refreshRecentTransfersHint() {
        if (binding == null) return;
        List<RecentTransfersStore.Entry> list = RecentTransfersStore.load(requireContext());
        if (list.isEmpty()) {
            binding.recentTransfersEmpty.setText("No recent transfers");
        } else {
            RecentTransfersStore.Entry e = list.get(0);
            binding.recentTransfersEmpty.setText(
                    (e.download ? "↓ " : "↑ ") + e.name + " · and "
                            + Math.max(0, list.size() - 1) + " more");
        }
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
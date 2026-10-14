// CleanerFragment.java — home of the file-cleaner utilities.
// Today it hosts the duplicates scan directly; per TRANSFER_CLEANER_PLAN.md
// it grows a card grid + sideways utility tabs (duplicates first).
package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.core.view.GravityCompat;


import com.example.wayer.R;
import com.example.wayer.core.GlassBlur;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.bridge.NativeCache;
import com.example.wayer.bridge.NativeEngine;
import com.example.wayer.bridge.PathCache;
import com.example.wayer.bridge.PathRegistry;
import com.example.wayer.databinding.FragmentCleanerBinding;
import com.example.wayer.storage.FileMutator;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class CleanerFragment extends Fragment {

    private static final String ROOT = "/storage/emulated/0";
    private static final String DUPLICATES_JOB = "duplicates";
    private static final String LARGE_JOB = "large-files";
    private static final long LARGE_MIN_BYTES = 10L * 1024 * 1024;

    private FragmentCleanerBinding binding;
    private FileAdapter adapter;
    // groups[i] = exact duplicates (identical bytes, byte-verified in C++).
    // related groups are display-only and never auto-deleted (see render below).
    private final List<List<DupEntry>> groups = new ArrayList<>();
    // Keep rule for theSuggested keeper: "newest" | "oldest" | "shortest".
    // Change this constant (or wire to a spinner) — C++ stays unchanged.
    private String keepRule = "newest";
    private FileAdapter largeAdapter;
    private CleanerCardAdapter cardAdapter;
    private final List<CleanerCardAdapter.Card> cards = new ArrayList<>();

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle saved) {
        binding = FragmentCleanerBinding.inflate(inflater, container, false);

        adapter = new FileAdapter();
        binding.duplicatesList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.duplicatesList.setAdapter(adapter);

        adapter.setOnItemClickListener(new FileAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FileItem item) {
                FileOpenHelper.open(requireContext(), item.getPath());
            }

            @Override
            public void onItemLongClick(FileItem item) {
                confirmDeleteOne(item);
            }
        });

        setupSidebar();

        setupCardGrid();
        setupTabs();

        binding.btnScanDuplicates.setOnClickListener(v -> scan());
        scan();

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
                confirmDeleteLarge(item);
            }
        });

        binding.btnScanLarge.setOnClickListener(v -> scanLargeFiles());
        scanLargeFiles();
        return binding.getRoot();
    }

    private void scan() {
        String dir = PathRegistry.moduleDir(getContext(), "cleaner");
        if (dir.isEmpty()) {
            binding.duplicatesEmpty.setText("Storage not ready");
            binding.duplicatesEmpty.setVisibility(View.VISIBLE);
            return;
        }
        String out = dir + "/duplicates.json";
        PathCache.remember(DUPLICATES_JOB, out);

        binding.duplicatesEmpty.setText("Scanning…");
        binding.duplicatesEmpty.setVisibility(View.VISIBLE);

        NativeEngine.findDuplicatesAsync(ROOT, out, rawJson -> {
            if (binding == null) return;
            if ("busy".equals(PathCache.reason(rawJson))) {
                Toast.makeText(getContext(), "Scan already running", Toast.LENGTH_SHORT).show();
                return;
            }
            String content = PathCache.readFile(PathCache.envelopePath(rawJson));
            if (content == null) {
                binding.duplicatesEmpty.setText("Scan failed");
                binding.duplicatesEmpty.setVisibility(View.VISIBLE);
                return;
            }
            renderDuplicatesContent(content);
        });
    }

    private void renderDuplicatesContent(String content) {
            groups.clear();
            List<FileItem> flat = new ArrayList<>();

            try {
                JSONObject root = new JSONObject(content);
                JSONArray dupGroups = root.optJSONArray("duplicate_groups");
                if (dupGroups != null) {
                    for (int g = 0; g < dupGroups.length(); g++) {
                        JSONArray group = dupGroups.getJSONArray(g);
                        List<DupEntry> entries = new ArrayList<>();
                        for (int i = 0; i < group.length(); i++) {
                            Object raw = group.opt(i);
                            DupEntry e;
                            if (raw instanceof JSONObject) {
                                JSONObject o = (JSONObject) raw;
                                e = new DupEntry(o.optString("path", ""),
                                        o.optLong("size", 0), o.optLong("mtime", 0));
                            } else {
                                // Legacy v1 shape: bare path strings.
                                e = new DupEntry(group.getString(i), 0, 0);
                            }
                            if (e.path.isEmpty()) continue;
                            entries.add(e);
                        }
                        if (entries.size() < 2) continue;
                        groups.add(entries);
                        int keeper = pickKeeper(entries, keepRule);
                        for (int i = 0; i < entries.size(); i++) {
                            DupEntry e = entries.get(i);
                            String name = e.path.substring(e.path.lastIndexOf('/') + 1);
                            String mark = (i == keeper) ? "KEEP? " : "Copy " + (i + 1) + " of " + entries.size();
                            flat.add(new FileItem(name, e.path,
                                    mark + " · " + formatSize(e.size) + " · " + formatDate(e.mtime),
                                    false, e.size));
                        }
                    }
                }
                // Related files: same normalized name, different versions.
                // Display only — no keeper, no delete affordance beyond open.
                JSONArray related = root.optJSONArray("related_groups");
                if (related != null) {
                    for (int g = 0; g < related.length(); g++) {
                        JSONObject rg = related.optJSONObject(g);
                        if (rg == null) continue;
                        String key = rg.optString("key", "");
                        JSONArray files = rg.optJSONArray("files");
                        if (files == null || files.length() < 2) continue;
                        for (int i = 0; i < files.length(); i++) {
                            JSONObject o = files.optJSONObject(i);
                            if (o == null) continue;
                            String path = o.optString("path", "");
                            if (path.isEmpty()) continue;
                            long size = o.optLong("size", 0);
                            long mtime = o.optLong("mtime", 0);
                            String name = path.substring(path.lastIndexOf('/') + 1);
                            flat.add(new FileItem(name, path,
                                    "Related to '" + key + "' · " + formatSize(size)
                                            + " · " + formatDate(mtime) + " · review only",
                                    false, size));
                        }
                    }
                }
            } catch (JSONException e) {
                e.printStackTrace();
                Toast.makeText(getContext(), "Failed to parse duplicates", Toast.LENGTH_SHORT).show();
            }

            if (flat.isEmpty()) {
                binding.duplicatesEmpty.setText("No duplicates found");
                binding.duplicatesEmpty.setVisibility(View.VISIBLE);
                adapter.submitList(null);
            } else {
                binding.duplicatesEmpty.setVisibility(View.GONE);
                adapter.submitList(flat);
            }
            updateCardStatus();
    }

    // add this method to CleanerFragment.java, called from onCreateView
    // (add `setupSidebar();` right after the adapter/RecyclerView setup, before `scan();`)
    private void setupCardGrid() {
        cards.add(new CleanerCardAdapter.Card(
                "Duplicates", R.drawable.ic_nav_cleaner, "Find repeated files", true));
        cards.add(new CleanerCardAdapter.Card(
                "Large files", R.drawable.ic_file, "Files over 10 MB", true));
        cards.add(new CleanerCardAdapter.Card(
                "More soon", android.R.drawable.ic_menu_add, "New utilities land here", false));

        cardAdapter = new CleanerCardAdapter();
        binding.cleanerGrid.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        binding.cleanerGrid.setAdapter(cardAdapter);
        cardAdapter.submitCards(cards);
        cardAdapter.setOnCardClickListener(position -> {
            if (position == 0) {
                binding.cleanerTabs.check(R.id.tab_duplicates);
                scan();
            } else if (position == 1) {
                binding.cleanerTabs.check(R.id.tab_large);
                scanLargeFiles();
            } else {
                Toast.makeText(getContext(), "More utilities coming", Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void setupTabs() {
        binding.cleanerTabs.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
            if (!isChecked) return;
            if (checkedId == R.id.tab_duplicates) binding.cleanerFlipper.setDisplayedChild(1);
            else if (checkedId == R.id.tab_large) binding.cleanerFlipper.setDisplayedChild(2);
            else binding.cleanerFlipper.setDisplayedChild(0);
        });
        binding.cleanerTabs.check(R.id.tab_utilities);
    }

    private void setupSidebar() {
        binding.btnOpenDuplicatesDrawer.setOnClickListener(v ->
                binding.duplicatesDrawerLayout.openDrawer(GravityCompat.END));

        View panel = binding.duplicatesOptionsSidebar.getRoot();
        binding.duplicatesOptionsSidebar.sidebarTitle.setText("Cleaner options");
        refreshAppearanceLabels();
        GlassBlur.applyFromPrefs(panel, requireContext());

        binding.duplicatesOptionsSidebar.btnTheme.setOnClickListener(v -> {
            String label = ThemePrefs.cycle(requireContext());
            refreshAppearanceLabels();
            if (getActivity() != null) UiChrome.apply(getActivity());
            Toast.makeText(getContext(), "Theme: " + label, Toast.LENGTH_SHORT).show();
        });

        binding.duplicatesOptionsSidebar.btnBlur.setOnClickListener(v -> {
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
        binding.duplicatesOptionsSidebar.themeLabel.setText("Theme: " + theme);
        binding.duplicatesOptionsSidebar.btnTheme.setText("Cycle theme (" + theme + ")");

        boolean blur = ThemePrefs.isBlurEnabled(requireContext());
        String blurTxt = !GlassBlur.isSupported()
                ? "Glass blur: N/A (API < 31)"
                : (blur ? "Glass blur: On" : "Glass blur: Off");
        binding.duplicatesOptionsSidebar.blurLabel.setText(blurTxt);
        binding.duplicatesOptionsSidebar.btnBlur.setText(
                GlassBlur.isSupported() ? "Toggle glass blur" : "Blur unavailable");
    }

    private void confirmDeleteOne(FileItem item) {
        new AlertDialog.Builder(requireContext())
                .setTitle("Move this copy to holding?")
                .setMessage(item.getPath() + "\nHeld 30 days under files/wayer/trash — not permanent.")
                .setPositiveButton("Move to holding", (d, w) -> {
                    String trashRoot = PathRegistry.root(requireContext()) + "/trash";
                    FileMutator.Result r = FileMutator.moveToTrash(item.getPath(), trashRoot);
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) {
                        NativeCache.invalidateStatsSnapshot(getContext());
                        scan();
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void scanLargeFiles() {
        String dir = PathRegistry.moduleDir(getContext(), "cleaner");
        if (dir.isEmpty()) {
            binding.largeFilesEmpty.setText("Storage not ready");
            binding.largeFilesEmpty.setVisibility(View.VISIBLE);
            return;
        }
        String out = dir + "/large-files.json";
        PathCache.remember(LARGE_JOB, out);

        binding.largeFilesEmpty.setText("Scanning…");
        binding.largeFilesEmpty.setVisibility(View.VISIBLE);
        binding.btnScanLarge.setEnabled(false);

        NativeEngine.findLargeFilesAsync(ROOT, LARGE_MIN_BYTES, 50, out, rawJson -> {
            if (binding == null) return;
            binding.btnScanLarge.setEnabled(true);
            if ("busy".equals(PathCache.reason(rawJson))) {
                Toast.makeText(getContext(), "Scan already running", Toast.LENGTH_SHORT).show();
                return;
            }
            String content = PathCache.readFile(PathCache.envelopePath(rawJson));
            if (content == null) {
                binding.largeFilesEmpty.setText("Scan failed");
                binding.largeFilesEmpty.setVisibility(View.VISIBLE);
                return;
            }
            renderLargeFilesContent(content);
        });
    }

    private void renderLargeFilesContent(String content) {
        List<FileItem> items = new ArrayList<>();
        try {
            JSONObject root = new JSONObject(content);
            JSONArray files = root.optJSONArray("files");
            if (files != null) {
                for (int i = 0; i < files.length(); i++) {
                    JSONObject o = files.getJSONObject(i);
                    long size = o.optLong("size", 0);
                    items.add(new FileItem(
                            o.getString("name"),
                            o.getString("path"),
                            formatSize(size),
                            false,
                            size
                    ));
                }
            }
        } catch (JSONException e) {
            e.printStackTrace();
            Toast.makeText(getContext(), "Failed to parse large files", Toast.LENGTH_SHORT).show();
        }

        if (items.isEmpty()) {
            binding.largeFilesEmpty.setText("No files ≥ " + formatSize(LARGE_MIN_BYTES));
            binding.largeFilesEmpty.setVisibility(View.VISIBLE);
            largeAdapter.submitList(null);
        } else {
            binding.largeFilesEmpty.setVisibility(View.GONE);
            largeAdapter.submitList(items);
        }
        updateCardStatus();
    }

    private void updateCardStatus() {
        if (cardAdapter == null) return;
        int dupFiles = 0;
        for (List<DupEntry> group : groups) dupFiles += group.size();
        cardAdapter.setStatus(0, groups.isEmpty()
                ? "No duplicates"
                : groups.size() + " groups · " + dupFiles + " files");
        int largeCount = largeAdapter != null ? largeAdapter.getItemCount() : 0;
        cardAdapter.setStatus(1, largeCount == 0
                ? "Files over 10 MB"
                : largeCount + " files ≥ 10 MB");
    }

    private void confirmDeleteLarge(FileItem item) {
        new AlertDialog.Builder(requireContext())
                .setTitle("Move large file to holding?")
                .setMessage(item.getName() + "\n" + item.getDetails())
                .setPositiveButton("Move to holding", (d, w) -> {
                    String trashRoot = PathRegistry.root(requireContext()) + "/trash";
                    FileMutator.Result r = FileMutator.moveToTrash(item.getPath(), trashRoot);
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) {
                        NativeCache.invalidateStatsSnapshot(getContext());
                        scanLargeFiles();
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private static String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }

    private static String formatDate(long mtimeUnix) {
        if (mtimeUnix <= 0) return "unknown date";
        try {
            java.text.SimpleDateFormat f = new java.text.SimpleDateFormat("yyyy-MM-dd",
                    java.util.Locale.US);
            return f.format(new java.util.Date(mtimeUnix * 1000));
        } catch (Exception e) {
            return "unknown date";
        }
    }

    /** One exact-duplicate file with eraser info. Chosen-folder rule is done by path prefix in UI. */
    private static class DupEntry {
        final String path;
        final long size;
        final long mtime;
        DupEntry(String path, long size, long mtime) {
            this.path = path; this.size = size; this.mtime = mtime;
        }
    }

    /** Keeper suggestion only — user still confirms. shortest = shortest full path. */
    private static int pickKeeper(List<DupEntry> entries, String rule) {
        if (entries.isEmpty()) return 0;
        int best = 0;
        for (int i = 1; i < entries.size(); i++) {
            DupEntry a = entries.get(best);
            DupEntry b = entries.get(i);
            if ("oldest".equals(rule)) {
                long am = a.mtime == 0 ? Long.MAX_VALUE : a.mtime;
                long bm = b.mtime == 0 ? Long.MAX_VALUE : b.mtime;
                if (bm < am) best = i;
            } else if ("shortest".equals(rule)) {
                if (b.path.length() < a.path.length()) best = i;
            } else { // "newest" default
                if (b.mtime > a.mtime) best = i;
            }
        }
        return best;
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
// DuplicatesFragment.java (new)
package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.core.view.GravityCompat;


import com.example.wayer.core.GlassBlur;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentDuplicatesBinding;
import com.example.wayer.storage.FileMutator;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class DuplicatesFragment extends Fragment {

    private static final int ACTION_FIND_DUPLICATES = 10;
    private static final String ROOT = "/storage/emulated/0";

    private FragmentDuplicatesBinding binding;
    private FileAdapter adapter;
    // groups[i] = list of full paths that are duplicates of each other
    private final List<List<String>> groups = new ArrayList<>();

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle saved) {
        binding = FragmentDuplicatesBinding.inflate(inflater, container, false);

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

        binding.btnScanDuplicates.setOnClickListener(v -> scan());
        scan();
        return binding.getRoot();
    }

    private void scan() {
        binding.duplicatesEmpty.setText("Scanning…");
        binding.duplicatesEmpty.setVisibility(View.VISIBLE);

        NativeEngine.processActionAsync(ACTION_FIND_DUPLICATES, ROOT, rawJson -> {
            if (binding == null) return;

            groups.clear();
            List<FileItem> flat = new ArrayList<>();

            try {
                JSONObject root = new JSONObject(rawJson);
                JSONArray dupGroups = root.optJSONArray("duplicate_groups");
                if (dupGroups != null) {
                    for (int g = 0; g < dupGroups.length(); g++) {
                        JSONArray group = dupGroups.getJSONArray(g);
                        List<String> paths = new ArrayList<>();
                        for (int i = 0; i < group.length(); i++) {
                            String path = group.getString(i);
                            paths.add(path);
                            String name = path.substring(path.lastIndexOf('/') + 1);
                            flat.add(new FileItem(
                                    name, path,
                                    "Copy " + (i + 1) + " of " + group.length(),
                                    false, 0));
                        }
                        groups.add(paths);
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
        });
    }

    // add this method to DuplicatesFragment.java, called from onCreateView
    // (add `setupSidebar();` right after the adapter/RecyclerView setup, before `scan();`)
    private void setupSidebar() {
        binding.btnOpenDuplicatesDrawer.setOnClickListener(v ->
                binding.duplicatesDrawerLayout.openDrawer(GravityCompat.END));

        View panel = binding.duplicatesOptionsSidebar.getRoot();
        binding.duplicatesOptionsSidebar.sidebarTitle.setText("Duplicates options");
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
                .setTitle("Delete this copy?")
                .setMessage(item.getPath())
                .setPositiveButton("Delete", (d, w) -> {
                    FileMutator.Result r = FileMutator.delete(item.getPath());
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) scan();
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
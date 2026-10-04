package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentInternalBinding;
import com.example.wayer.storage.AppDirs;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/**
 * Read-only browser for the private app home (index, cache, logs, manifest).
 *
 * Listing is plain java.io (the app can read its own files directly); opening
 * a file goes through DocumentActivity, which renders via the C++ preview
 * module. No create / rename / delete here — navigation clamps at the root.
 */
public class InternalFragment extends Fragment {

    private FragmentInternalBinding binding;
    private FileAdapter adapter;
    private File root;
    private File current;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentInternalBinding.inflate(inflater, container, false);
        root = AppDirs.privateRoot(requireContext());
        current = root;

        adapter = new FileAdapter();
        binding.fileList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.fileList.setAdapter(adapter);
        adapter.setOnItemClickListener(new FileAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FileItem item) {
                File f = new File(item.getPath());
                if (f.isDirectory()) {
                    current = f;
                    loadDirectory();
                } else {
                    DocumentActivity.open(requireContext(), item.getPath());
                }
            }

            @Override
            public void onItemLongClick(FileItem item) {
                Toast.makeText(getContext(), "Read-only — no actions here", Toast.LENGTH_SHORT).show();
            }
        });

        binding.btnUp.setOnClickListener(v -> {
            File parent = current.getParentFile();
            if (parent != null && isUnderRoot(parent)) {
                current = parent;
                loadDirectory();
            }
        });

        // Ensure the native tree (and paths.json) exists, then list it.
        NativeEngine.initAppPathsAsync(requireContext(), result -> {
            if (binding == null || getContext() == null) return;
            root = AppDirs.privateRoot(requireContext());
            if (!isUnderRoot(current)) current = root;
            loadDirectory();
        });
        return binding.getRoot();
    }

    private boolean isUnderRoot(File f) {
        try {
            String r = root.getCanonicalPath();
            String c = f.getCanonicalPath();
            return c.equals(r) || c.startsWith(r + File.separator);
        } catch (Exception e) {
            return false;
        }
    }

    private void loadDirectory() {
        if (binding == null) return;
        binding.currentPath.setText(current.getAbsolutePath());
        binding.btnUp.setEnabled(!current.equals(root));

        List<FileItem> rows = new ArrayList<>();
        File[] children = current.listFiles();
        if (children != null) {
            Arrays.sort(children, (a, b) -> {
                if (a.isDirectory() != b.isDirectory()) return a.isDirectory() ? -1 : 1;
                return a.getName().compareToIgnoreCase(b.getName());
            });
            for (File c : children) {
                boolean dir = c.isDirectory();
                rows.add(new FileItem(c.getName(), c.getAbsolutePath(),
                        dir ? "Folder" : formatSize(c.length()), dir, dir ? 0 : c.length()));
            }
        }
        adapter.submitList(rows);
        binding.emptyState.setVisibility(rows.isEmpty() ? View.VISIBLE : View.GONE);
        binding.fileList.setVisibility(rows.isEmpty() ? View.GONE : View.VISIBLE);
    }

    private static String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format(Locale.US, "%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format(Locale.US, "%.1f MB", bytes / (1024.0 * 1024));
        return String.format(Locale.US, "%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}

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
import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentFilesBinding;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Files screen.
 * - Left drawer for specialised browse locations
 * - Search bar (results area ready)
 * - Current path indicator
 * - RecyclerView list of files/folders
 * - Empty state when nothing to show
 *
 * C++ does the heavy work (list / search). Java only displays the bulk JSON.
 */
public class FilesFragment extends Fragment {

    private FragmentFilesBinding binding;
    private FileAdapter adapter;

    // Current directory we are browsing
    private String currentPath = "/storage/emulated/0";

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentFilesBinding.inflate(inflater, container, false);
        setupRecycler();
        setupDrawer();
        setupSearch();
        loadDirectory(currentPath);
        return binding.getRoot();
    }

    private void setupRecycler() {
        adapter = new FileAdapter();
        binding.fileList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.fileList.setAdapter(adapter);

        adapter.setOnItemClickListener(new FileAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FileItem item) {
                if (item.isDirectory()) {
                    // Enter folder
                    loadDirectory(item.getPath());
                } else {
                    // Later: open document viewer
                    DocumentActivity.open(requireContext(), item.getPath());
                }
            }

            @Override
            public void onItemLongClick(FileItem item) {
                // Later: show options dialog (Open folder / Open file / ...)
                Toast.makeText(getContext(), "Long press: " + item.getName(), Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void setupDrawer() {
        // Open drawer button
        binding.btnOpenDrawer.setOnClickListener(v ->
                binding.drawerLayout.openDrawer(GravityCompat.START)
        );

        // Sidebar item clicks
        binding.leftDrawer.setNavigationItemSelectedListener(menuItem -> {
            int id = menuItem.getItemId();

            if (id == R.id.nav_browse || id == R.id.nav_internal) {
                loadDirectory("/storage/emulated/0");
            } else if (id == R.id.nav_downloads) {
                loadDirectory("/storage/emulated/0/Download");
            } else if (id == R.id.nav_images) {
                loadDirectory("/storage/emulated/0/DCIM");
            } else if (id == R.id.nav_videos) {
                loadDirectory("/storage/emulated/0/Movies");
            } else if (id == R.id.nav_documents) {
                loadDirectory("/storage/emulated/0/Documents");
            } else if (id == R.id.nav_refresh) {
                loadDirectory(currentPath);
            } else if (id == R.id.nav_external) {
                Toast.makeText(getContext(), "External / SD – coming soon", Toast.LENGTH_SHORT).show();
            }

            binding.drawerLayout.closeDrawer(GravityCompat.START);
            return true;
        });
    }

    private void setupSearch() {
        // Basic: when user presses search on keyboard we will later call C++ search.
        // For now just hide results header until real search is wired.
        binding.searchResultsHeader.setVisibility(View.GONE);
    }

    /**
     * Ask C++ for the content of a directory (Action ID 3).
     * Expected JSON shape (simple for now):
     * { "files": [ "name1", "name2", ... ] }
     * Later we will upgrade C++ to return richer objects (is_dir, size, path).
     */
    private void loadDirectory(String path) {
        currentPath = path;
        binding.currentPath.setText(path);

        // Show loading state
        showEmpty(false);
        binding.fileList.setVisibility(View.VISIBLE);

        NativeEngine.processActionAsync(3, path, rawJson -> {
            if (binding == null) return; // fragment already destroyed

            List<FileItem> items = parseSimpleFileList(rawJson, path);

            if (items.isEmpty()) {
                showEmpty(true);
            } else {
                showEmpty(false);
                adapter.submitList(items);
            }
        });
    }

    /**
     * Temporary parser for the current simple C++ response:
     * {"files":["file1","folder2",...]}
     * Treats everything as unknown type for now.
     * When C++ returns richer JSON we will upgrade this method only.
     */
    private List<FileItem> parseSimpleFileList(String rawJson, String parentPath) {
        List<FileItem> result = new ArrayList<>();
        try {
            JSONObject root = new JSONObject(rawJson);
            if (root.has("error")) {
                Toast.makeText(getContext(), "Error: " + root.getString("error"), Toast.LENGTH_SHORT).show();
                return result;
            }

            JSONArray files = root.optJSONArray("files");
            if (files == null) return result;

            for (int i = 0; i < files.length(); i++) {
                String name = files.getString(i);
                String fullPath = parentPath.endsWith("/")
                        ? parentPath + name
                        : parentPath + "/" + name;

                // Heuristic until C++ gives is_dir: no extension → treat as folder
                boolean isDir = !name.contains(".");
                String details = isDir ? "Folder" : "File";

                result.add(new FileItem(name, fullPath, details, isDir, 0));
            }
        } catch (JSONException e) {
            e.printStackTrace();
            Toast.makeText(getContext(), "Failed to parse file list", Toast.LENGTH_SHORT).show();
        }
        return result;
    }

    private void showEmpty(boolean empty) {
        if (empty) {
            binding.fileList.setVisibility(View.GONE);
            binding.emptyState.setVisibility(View.VISIBLE);
            adapter.submitList(null);
        } else {
            binding.emptyState.setVisibility(View.GONE);
            binding.fileList.setVisibility(View.VISIBLE);
        }
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}

package com.example.wayer.ui;

import android.os.Bundle;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
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
 * - Search bar → C++ bulk search (exact + related)
 * - Current path indicator
 * - RecyclerView list of files/folders
 * - Empty state when nothing to show
 *
 * C++ does the heavy work (list / search). Java only displays the bulk JSON.
 */
public class FilesFragment extends Fragment {

    private static final int ACTION_LIST_FILES   = 3;
    private static final int ACTION_SEARCH_FILES = 8;

    private FragmentFilesBinding binding;
    private FileAdapter adapter;

    private String currentPath = "/storage/emulated/0";
    private boolean showingSearchResults = false;

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
                    // Leave search mode and browse into the folder
                    showingSearchResults = false;
                    binding.searchResultsHeader.setVisibility(View.GONE);
                    loadDirectory(item.getPath());
                } else {
                    DocumentActivity.open(requireContext(), item.getPath());
                }
            }

            @Override
            public void onItemLongClick(FileItem item) {
                showItemOptions(item);
            }
        });
    }

    private void showItemOptions(FileItem item) {
        String[] options;
        if (item.isDirectory()) {
            options = new String[]{"Browse folder", "Cancel"};
        } else {
            options = new String[]{"Open file", "Open parent folder", "Cancel"};
        }

        new AlertDialog.Builder(requireContext())
                .setTitle(item.getName())
                .setItems(options, (dialog, which) -> {
                    if (item.isDirectory()) {
                        if (which == 0) {
                            showingSearchResults = false;
                            binding.searchResultsHeader.setVisibility(View.GONE);
                            loadDirectory(item.getPath());
                        }
                    } else {
                        if (which == 0) {
                            DocumentActivity.open(requireContext(), item.getPath());
                        } else if (which == 1) {
                            // Open parent folder
                            String parent = item.getPath();
                            int slash = parent.lastIndexOf('/');
                            if (slash > 0) {
                                showingSearchResults = false;
                                binding.searchResultsHeader.setVisibility(View.GONE);
                                loadDirectory(parent.substring(0, slash));
                            }
                        }
                    }
                })
                .show();
    }

    private void setupDrawer() {
        binding.btnOpenDrawer.setOnClickListener(v ->
                binding.drawerLayout.openDrawer(GravityCompat.START)
        );

        binding.leftDrawer.setNavigationItemSelectedListener(menuItem -> {
            int id = menuItem.getItemId();

            showingSearchResults = false;
            binding.searchResultsHeader.setVisibility(View.GONE);

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
                if (showingSearchResults) {
                    // re-run last search not stored yet → just refresh dir
                    loadDirectory(currentPath);
                } else {
                    loadDirectory(currentPath);
                }
            } else if (id == R.id.nav_external) {
                Toast.makeText(getContext(), "External / SD – coming soon", Toast.LENGTH_SHORT).show();
            }

            binding.drawerLayout.closeDrawer(GravityCompat.START);
            return true;
        });
    }

    private void setupSearch() {
        binding.searchResultsHeader.setVisibility(View.GONE);

        binding.searchInput.setOnEditorActionListener((v, actionId, event) -> {
            boolean isSearch = actionId == EditorInfo.IME_ACTION_SEARCH
                    || (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER);

            if (isSearch) {
                String query = binding.searchInput.getText() != null
                        ? binding.searchInput.getText().toString().trim()
                        : "";
                if (!query.isEmpty()) {
                    performSearch(query);
                }
                return true;
            }
            return false;
        });
    }

    /**
     * Bulk search via C++ (Action 8).
     * Payload format: "root_path|query"
     * Response: { "exact_matches":[...], "related_matches":[...] }
     */
    private void performSearch(String query) {
        String payload = currentPath + "|" + query;

        binding.searchResultsHeader.setVisibility(View.VISIBLE);
        binding.searchResultsHeader.setText("Searching…");
        showEmpty(false);

        NativeEngine.processActionAsync(ACTION_SEARCH_FILES, payload, rawJson -> {
            if (binding == null) return;

            List<FileItem> items = parseSearchResults(rawJson);
            showingSearchResults = true;

            if (items.isEmpty()) {
                binding.searchResultsHeader.setText("No results for \"" + query + "\"");
                showEmpty(true);
            } else {
                binding.searchResultsHeader.setText("Results for \"" + query + "\"");
                showEmpty(false);
                adapter.submitList(items);
            }
        });
    }

    private List<FileItem> parseSearchResults(String rawJson) {
        List<FileItem> result = new ArrayList<>();
        try {
            JSONObject root = new JSONObject(rawJson);

            // Exact matches first (100%)
            JSONArray exact = root.optJSONArray("exact_matches");
            if (exact != null) {
                for (int i = 0; i < exact.length(); i++) {
                    JSONObject o = exact.getJSONObject(i);
                    boolean isDir = o.optBoolean("is_dir", false);
                    result.add(new FileItem(
                            o.getString("name"),
                            o.getString("path"),
                            isDir ? "Folder · exact match" : "File · exact match",
                            isDir,
                            0
                    ));
                }
            }

            // Related matches (~50%)
            JSONArray related = root.optJSONArray("related_matches");
            if (related != null) {
                for (int i = 0; i < related.length(); i++) {
                    JSONObject o = related.getJSONObject(i);
                    boolean isDir = o.optBoolean("is_dir", false);
                    result.add(new FileItem(
                            o.getString("name"),
                            o.getString("path"),
                            isDir ? "Folder · related" : "File · related",
                            isDir,
                            0
                    ));
                }
            }
        } catch (JSONException e) {
            e.printStackTrace();
            Toast.makeText(getContext(), "Failed to parse search results", Toast.LENGTH_SHORT).show();
        }
        return result;
    }

    private void loadDirectory(String path) {
        currentPath = path;
        binding.currentPath.setText(path);
        showingSearchResults = false;
        binding.searchResultsHeader.setVisibility(View.GONE);

        showEmpty(false);
        binding.fileList.setVisibility(View.VISIBLE);

        NativeEngine.processActionAsync(ACTION_LIST_FILES, path, rawJson -> {
            if (binding == null) return;

            List<FileItem> items = parseSimpleFileList(rawJson, path);

            if (items.isEmpty()) {
                showEmpty(true);
            } else {
                showEmpty(false);
                adapter.submitList(items);
            }
        });
    }

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

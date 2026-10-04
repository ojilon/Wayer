package com.example.wayer.ui;

import android.os.Bundle;
import android.text.InputType;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.core.view.GravityCompat;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.wayer.R;
import com.example.wayer.bridge.AppDirs;
import com.example.wayer.bridge.NativeCache;
import com.example.wayer.bridge.NativeEngine;
import com.example.wayer.bridge.PathCache;
import com.example.wayer.bridge.PathRegistry;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.databinding.FragmentFilesBinding;
import com.example.wayer.storage.FileMutator;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Files screen.
 * List/search via C++; create/rename/delete via FileMutator (shared).
 * Open routes through FileOpenHelper → Image / Video / Document.
 * Left drawer includes Appearance → Theme (System / Dark / Light).
 */
public class FilesFragment extends Fragment {

    private static final int ACTION_LIST_FILES   = 3;
    private static final String SEARCH_JOB = "search";

    private FragmentFilesBinding binding;
    private FileAdapter adapter;

    private String currentPath = BrowseSession.filesCurrentPath;
    private boolean showingSearchResults = false;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentFilesBinding.inflate(inflater, container, false);
        if (currentPath == null) currentPath = AppDirs.externalRoot().getPath();
        setupRecycler();
        setupDrawer();
        setupSearch();
        setupPathActions();
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
                    showingSearchResults = false;
                    binding.searchResultsHeader.setVisibility(View.GONE);
                    loadDirectory(item.getPath());
                } else {
                    FileOpenHelper.open(requireContext(), item.getPath());
                }
            }

            @Override
            public void onItemLongClick(FileItem item) {
                showItemOptions(item);
            }
        });
    }

    private void setupPathActions() {
        binding.currentPath.setOnLongClickListener(v -> {
            showCreateMenu();
            return true;
        });
        binding.btnFilesUp.setOnClickListener(v -> {
            java.io.File parent = new java.io.File(currentPath).getParentFile();
            if (parent != null) {
                showingSearchResults = false;
                binding.searchResultsHeader.setVisibility(View.GONE);
                loadDirectory(parent.getAbsolutePath());
            } else {
                Toast.makeText(getContext(), "Already at the top", Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void showCreateMenu() {
        String[] options = {"New folder", "New file", "Cancel"};
        new AlertDialog.Builder(requireContext())
                .setTitle("In " + currentPath)
                .setItems(options, (d, which) -> {
                    if (which == 0) promptCreate(true);
                    else if (which == 1) promptCreate(false);
                })
                .show();
    }

    private void promptCreate(boolean folder) {
        final EditText input = new EditText(requireContext());
        input.setInputType(InputType.TYPE_CLASS_TEXT);
        input.setHint(folder ? "Folder name" : "File name (e.g. notes.txt)");

        new AlertDialog.Builder(requireContext())
                .setTitle(folder ? "New folder" : "New file")
                .setView(input)
                .setPositiveButton("Create", (d, w) -> {
                    String name = input.getText().toString().trim();
                    FileMutator.Result r = folder
                            ? FileMutator.createDirectory(currentPath, name)
                            : FileMutator.createFile(currentPath, name);
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) loadDirectory(currentPath);
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void showItemOptions(FileItem item) {
        final String[] options = item.isDirectory()
                ? new String[]{"Browse folder", "Rename", "Delete", "Cancel"}
                : new String[]{"Open file", "Open parent folder", "Rename", "Delete", "Cancel"};

        new AlertDialog.Builder(requireContext())
                .setTitle(item.getName())
                .setItems(options, (dialog, which) -> {
                    if (item.isDirectory()) {
                        switch (which) {
                            case 0 -> {
                                showingSearchResults = false;
                                binding.searchResultsHeader.setVisibility(View.GONE);
                                loadDirectory(item.getPath());
                            }
                            case 1 -> promptRename(item);
                            case 2 -> confirmDelete(item);
                        }
                    } else {
                        switch (which) {
                            case 0 -> FileOpenHelper.open(requireContext(), item.getPath());
                            case 1 -> {
                                String parent = item.getPath();
                                int slash = parent.lastIndexOf('/');
                                if (slash > 0) {
                                    showingSearchResults = false;
                                    binding.searchResultsHeader.setVisibility(View.GONE);
                                    loadDirectory(parent.substring(0, slash));
                                }
                            }
                            case 2 -> promptRename(item);
                            case 3 -> confirmDelete(item);
                        }
                    }
                })
                .show();
    }

    private void promptRename(FileItem item) {
        final EditText input = new EditText(requireContext());
        input.setInputType(InputType.TYPE_CLASS_TEXT);
        input.setText(item.getName());

        new AlertDialog.Builder(requireContext())
                .setTitle("Rename")
                .setView(input)
                .setPositiveButton("Rename", (d, w) -> {
                    String newName = input.getText().toString().trim();
                    FileMutator.Result r = FileMutator.rename(item.getPath(), newName);
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) loadDirectory(currentPath);
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void confirmDelete(FileItem item) {
        new AlertDialog.Builder(requireContext())
                .setTitle("Delete?")
                .setMessage(item.getName() + (item.isDirectory()
                        ? "\n\nFolder and all contents will be removed."
                        : ""))
                .setPositiveButton("Delete", (d, w) -> {
                    FileMutator.Result r = FileMutator.delete(item.getPath());
                    Toast.makeText(getContext(), r.message, Toast.LENGTH_SHORT).show();
                    if (r.ok) {
                        NativeCache.invalidateStatsSnapshot(getContext());
                        loadDirectory(currentPath);
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void setupDrawer() {
        binding.btnOpenDrawer.setOnClickListener(v ->
                binding.drawerLayout.openDrawer(GravityCompat.START)
        );

        refreshThemeMenuTitle();

        binding.leftDrawer.setNavigationItemSelectedListener(menuItem -> {
            int id = menuItem.getItemId();

            if (id == R.id.nav_theme) {
                String label = ThemePrefs.cycle(requireContext());
                Toast.makeText(getContext(), "Theme: " + label, Toast.LENGTH_SHORT).show();
                refreshThemeMenuTitle();
                // keep drawer open so user can cycle again
                return true;
            }

            showingSearchResults = false;
            binding.searchResultsHeader.setVisibility(View.GONE);

            if (id == R.id.nav_browse || id == R.id.nav_internal) {
                loadDirectory(AppDirs.externalRoot().getPath());
            } else if (id == R.id.nav_downloads) {
                loadDirectory(AppDirs.downloadDir().getPath());
            } else if (id == R.id.nav_images) {
                loadDirectory(AppDirs.dcimDir().getPath());
            } else if (id == R.id.nav_videos) {
                loadDirectory(AppDirs.moviesDir().getPath());
            } else if (id == R.id.nav_documents) {
                loadDirectory(AppDirs.documentsDir().getPath());
            } else if (id == R.id.nav_refresh) {
                loadDirectory(currentPath);
            } else if (id == R.id.nav_external) {
                Toast.makeText(getContext(), "External / SD – coming soon", Toast.LENGTH_SHORT).show();
            }

            binding.drawerLayout.closeDrawer(GravityCompat.START);
            return true;
        });
    }

    private void refreshThemeMenuTitle() {
        if (binding == null) return;
        Menu menu = binding.leftDrawer.getMenu();
        MenuItem themeItem = menu.findItem(R.id.nav_theme);
        if (themeItem != null) {
            themeItem.setTitle("Theme: " + ThemePrefs.currentLabel(requireContext()));
        }
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

    private void performSearch(String query) {
        String dir = PathRegistry.moduleDir(getContext(), "search");
        if (dir.isEmpty()) {
            Toast.makeText(getContext(), "Storage not ready", Toast.LENGTH_SHORT).show();
            return;
        }
        String out = dir + "/results.json";
        PathCache.remember(SEARCH_JOB, out);

        // Show the previous results instantly while the fresh scan builds.
        renderSearchFile(PathCache.previous(SEARCH_JOB), query, true);

        binding.searchResultsHeader.setVisibility(View.VISIBLE);
        binding.searchResultsHeader.setText("Searching…");
        showEmpty(false);

        runSearch(query, out, true);
    }

    private void runSearch(final String query, final String out, final boolean mayRetry) {
        NativeEngine.searchFilesAsync(currentPath, query, out, rawJson -> {
            if (binding == null) return;
            if ("busy".equals(PathCache.reason(rawJson))) {
                // A scan is still running — retry once shortly; the user is
                // usually still typing, so this resolves on its own.
                if (mayRetry) {
                    binding.searchResultsHeader.postDelayed(() -> {
                        if (binding == null) return;
                        String now = binding.searchInput.getText() != null
                                ? binding.searchInput.getText().toString().trim() : "";
                        if (now.equals(query)) runSearch(query, out, false);
                    }, 400);
                }
                return;
            }
            String content = PathCache.readFile(PathCache.envelopePath(rawJson));
            if (content == null) {
                Toast.makeText(getContext(), "Search failed", Toast.LENGTH_SHORT).show();
                return;
            }
            renderSearchContent(content, query);
        });
    }

    private void renderSearchFile(String path, String query, boolean cached) {
        String content = PathCache.readFile(path);
        if (content == null) return;
        List<FileItem> items = parseSearchResults(content);
        if (items.isEmpty()) return;
        showingSearchResults = true;
        binding.searchResultsHeader.setVisibility(View.VISIBLE);
        binding.searchResultsHeader.setText("Results for \"" + query + "\"" + (cached ? " (cached)" : ""));
        showEmpty(false);
        adapter.submitList(items);
    }

    private void renderSearchContent(String content, String query) {
        List<FileItem> items = parseSearchResults(content);
        showingSearchResults = true;

        if (items.isEmpty()) {
            binding.searchResultsHeader.setText("No results for \"" + query + "\"");
            showEmpty(true);
        } else {
            binding.searchResultsHeader.setText("Results for \"" + query + "\"");
            showEmpty(false);
            adapter.submitList(items);
        }
    }

    private List<FileItem> parseSearchResults(String rawJson) {
        List<FileItem> result = new ArrayList<>();
        try {
            JSONObject root = new JSONObject(rawJson);

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
        BrowseSession.filesCurrentPath = path;
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

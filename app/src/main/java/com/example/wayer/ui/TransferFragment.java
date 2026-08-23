package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.core.view.GravityCompat;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.example.wayer.R;
import com.example.wayer.core.Config;
import com.example.wayer.core.GlassBlur;
import com.example.wayer.core.ThemePrefs;
import com.example.wayer.core.UiChrome;
import com.example.wayer.databinding.FragmentTransferBinding;
import com.example.wayer.network.NetworkCallback;
import com.example.wayer.network.NetworkManager;
import com.example.wayer.storage.FileIndexer;
import com.example.wayer.transfer.RecentTransfersStore;
import com.example.wayer.transfer.TransferController;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;

public class TransferFragment extends Fragment {

    private FragmentTransferBinding binding;

    private long sessionSentBytes = 0;
    private long sessionReceivedBytes = 0;

    private String savePath = FileIndexer.getDefaultSavePath();
    private String browsePath = FileIndexer.getDefaultSavePath();

    private FileAdapter browseAdapter;
    private FileAdapter recentAdapter;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentTransferBinding.inflate(inflater, container, false);
        setupUI();
        ensureIndexWarm();
        return binding.getRoot();
    }

    private void setupUI() {
        binding.connectionDetails.setText("Target: " + Config.HOST + ":" + Config.PORT);
        binding.connectionStatus.setText("Not tested");
        updateSessionStats();
        updateSavePathLabel();
        updateThemeLabel();

        binding.btnTestConnection.setOnClickListener(v -> testConnection());
        binding.btnStartListener.setOnClickListener(v -> startListener());
        binding.btnDownload.setOnClickListener(v -> runDownload());
        binding.btnUpload.setOnClickListener(v -> runUploadSearch());

        binding.btnOpenTransferDrawer.setOnClickListener(v ->
                binding.transferDrawerLayout.openDrawer(GravityCompat.END));

        binding.btnChangeSave.setOnClickListener(v -> showBrowseTab());
        binding.btnRefreshIndexer.setOnClickListener(v -> refreshIndexer());
        binding.btnTheme.setOnClickListener(v -> {
            String label = ThemePrefs.cycle(requireContext());
            updateThemeLabel();
            if (getActivity() != null) UiChrome.apply(getActivity());
            Toast.makeText(getContext(), "Theme: " + label, Toast.LENGTH_SHORT).show();
        });
        binding.btnBlur.setOnClickListener(v -> {
            if (!GlassBlur.isSupported()) {
                Toast.makeText(getContext(), "Blur needs Android 12+", Toast.LENGTH_SHORT).show();
                return;
            }
            boolean on = ThemePrefs.toggleBlur(requireContext());
            GlassBlur.applyFromPrefs(binding.transferSidebarRoot, requireContext());
            updateThemeLabel();
            Toast.makeText(getContext(), on ? "Glass blur on" : "Glass blur off", Toast.LENGTH_SHORT).show();
        });
        binding.btnBackToTransfer.setOnClickListener(v -> showTransferTab());
        binding.btnUseThisFolder.setOnClickListener(v -> {
            savePath = browsePath;
            updateSavePathLabel();
            Toast.makeText(getContext(), "Save folder set", Toast.LENGTH_SHORT).show();
            showTransferTab();
            binding.transferDrawerLayout.closeDrawer(GravityCompat.END);
        });

        setupBrowseList();
        setupRecentList();
        GlassBlur.applyFromPrefs(binding.transferSidebarRoot, requireContext());
        showTransferTab();
    }

    private void setupRecentList() {
        recentAdapter = new FileAdapter();
        binding.recentTransfersList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.recentTransfersList.setAdapter(recentAdapter);
        recentAdapter.setOnItemClickListener(new FileAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FileItem item) {
                // name only; optional fill filename field
                binding.transferFilename.setText(item.getName());
            }

            @Override
            public void onItemLongClick(FileItem item) {
                // no-op
            }
        });
        refreshRecentUi();
    }

    private void refreshRecentUi() {
        if (binding == null) return;
        List<RecentTransfersStore.Entry> entries = RecentTransfersStore.load(requireContext());
        if (entries.isEmpty()) {
            binding.recentTransfersEmpty.setVisibility(View.VISIBLE);
            binding.recentTransfersEmpty.setText("No transfers yet");
            binding.recentTransfersList.setVisibility(View.GONE);
            recentAdapter.submitList(null);
            return;
        }
        binding.recentTransfersEmpty.setVisibility(View.GONE);
        binding.recentTransfersList.setVisibility(View.VISIBLE);
        List<FileItem> items = new ArrayList<>();
        for (RecentTransfersStore.Entry e : entries) {
            String details = (e.download ? "Download" : "Upload") + " · " + e.detail;
            items.add(new FileItem(e.name, e.detail, details, false, 0));
        }
        recentAdapter.submitList(items);
    }

    private void recordSuccess(boolean download, String name, String detail) {
        RecentTransfersStore.add(requireContext(), download, name, detail);
        refreshRecentUi();
    }

    private void updateThemeLabel() {
        if (binding == null) return;
        binding.themeLabel.setText("Theme: " + ThemePrefs.currentLabel(requireContext()));
        binding.btnTheme.setText("Cycle theme (" + ThemePrefs.currentLabel(requireContext()) + ")");
        boolean blur = ThemePrefs.isBlurEnabled(requireContext());
        String blurTxt = !GlassBlur.isSupported()
                ? "Glass blur: N/A (API < 31)"
                : (blur ? "Glass blur: On" : "Glass blur: Off");
        binding.blurLabel.setText(blurTxt);
        binding.btnBlur.setText(GlassBlur.isSupported() ? "Toggle glass blur" : "Blur unavailable");
    }

    private void setupBrowseList() {
        browseAdapter = new FileAdapter();
        binding.browseFolderList.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.browseFolderList.setAdapter(browseAdapter);

        browseAdapter.setOnItemClickListener(new FileAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FileItem item) {
                if (item.isDirectory()) {
                    browsePath = item.getPath();
                    loadBrowseDirectory(browsePath);
                }
            }

            @Override
            public void onItemLongClick(FileItem item) {
                if (item.isDirectory()) {
                    savePath = item.getPath();
                    updateSavePathLabel();
                    Toast.makeText(getContext(), "Save folder: " + item.getName(), Toast.LENGTH_SHORT).show();
                }
            }
        });
    }

    private void showTransferTab() {
        binding.transferViewFlipper.setDisplayedChild(0);
    }

    private void showBrowseTab() {
        binding.transferViewFlipper.setDisplayedChild(1);
        loadBrowseDirectory(browsePath);
        if (!binding.transferDrawerLayout.isDrawerOpen(GravityCompat.END)) {
            binding.transferDrawerLayout.openDrawer(GravityCompat.END);
        }
    }

    private void loadBrowseDirectory(String path) {
        browsePath = path;
        binding.browseCurrentPath.setText(path);

        List<FileItem> items = new ArrayList<>();
        FileIndexer indexer = FileIndexer.getInstance();

        List<String> cached = indexer.getContentsOfFolder(path);
        if (cached.isEmpty() && !indexer.isCacheEmpty()) {
            File dir = new File(path);
            File[] children = dir.listFiles();
            if (children != null) {
                for (File c : children) {
                    if (c.isDirectory()) {
                        items.add(new FileItem(c.getName(), c.getAbsolutePath(), "Folder", true, 0));
                    }
                }
            }
        } else {
            for (String p : cached) {
                File f = new File(p);
                if (f.isDirectory()) {
                    items.add(new FileItem(f.getName(), p, "Folder", true, 0));
                }
            }
        }

        if (!path.equals(FileIndexer.DEFAULT_ROOT) && path.contains("/")) {
            int slash = path.lastIndexOf('/');
            if (slash > 0) {
                String parent = path.substring(0, slash);
                items.add(0, new FileItem("..", parent, "Parent", true, 0));
            }
        }

        browseAdapter.submitList(items);
    }

    private void ensureIndexWarm() {
        FileIndexer indexer = FileIndexer.getInstance();
        if (indexer.isCacheEmpty()) {
            appendLog("Indexing local storage (background)…");
            new Thread(() -> {
                indexer.refreshCache();
                runOnUi(() -> appendLog("Index ready · "
                        + indexer.getIndexedFileCount() + " files, "
                        + indexer.getIndexedFolderCount() + " folders"));
            }).start();
        }
    }

    private void refreshIndexer() {
        appendLog("Refreshing FileIndexer cache…");
        binding.btnRefreshIndexer.setEnabled(false);
        new Thread(() -> {
            FileIndexer.getInstance().refreshCache();
            FileIndexer idx = FileIndexer.getInstance();
            runOnUi(() -> {
                binding.btnRefreshIndexer.setEnabled(true);
                appendLog("Cache refreshed · " + idx.getIndexedFileCount() + " files");
                Toast.makeText(getContext(), "Index refreshed", Toast.LENGTH_SHORT).show();
                if (binding.transferViewFlipper.getDisplayedChild() == 1) {
                    loadBrowseDirectory(browsePath);
                }
            });
        }).start();
    }

    private void updateSavePathLabel() {
        if (binding == null) return;
        binding.savePathHint.setText("Save downloads to: " + savePath);
        binding.drawerSavePath.setText(savePath);
    }

    private void testConnection() {
        appendLog("Testing connection to " + Config.HOST + ":" + Config.PORT + "…");
        binding.connectionStatus.setText("Testing…");

        new Thread(() -> {
            boolean ok = false;
            String message;
            long start = System.currentTimeMillis();

            try (Socket socket = new Socket()) {
                socket.connect(new InetSocketAddress(Config.HOST, Config.PORT), 3000);
                ok = socket.isConnected();
                long ms = System.currentTimeMillis() - start;
                message = ok ? "Connected (" + ms + " ms)" : "Not connected";
            } catch (Exception e) {
                message = "Failed: " + e.getMessage();
            }

            boolean finalOk = ok;
            String finalMessage = message;

            runOnUi(() -> {
                binding.connectionStatus.setText(finalMessage);
                binding.connectionStatus.setTextColor(
                        getResources().getColor(
                                finalOk ? R.color.wayer_success : R.color.wayer_error, null));
                appendLog(finalMessage);
            });
        }).start();
    }

    private void startListener() {
        appendLog("Starting listener on port 8080…");
        TransferController.startServerListener(8080, status -> runOnUi(() -> {
            String line = "Listener: " + status.getStatus() + " port=" + status.getPort();
            appendLog(line);
        }));
    }

    private void runDownload() {
        String name = binding.transferFilename.getText() != null
                ? binding.transferFilename.getText().toString().trim()
                : "";

        if (name.isEmpty()) {
            Toast.makeText(getContext(), "Enter a file name", Toast.LENGTH_SHORT).show();
            return;
        }

        File workingDir = new File(savePath);
        if (!workingDir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            workingDir.mkdirs();
        }

        String command = "/ask " + name;
        appendLog("Download: " + name + " → " + savePath);
        setTransferButtonsEnabled(false);

        long started = System.currentTimeMillis();

        NetworkManager.processProtocolCommand(command, workingDir, new NetworkCallback() {
            @Override
            public void onConsoleUpdate(String outputText) {
                runOnUi(() -> appendLog(outputText));
            }

            @Override
            public void onOperationComplete(String finalResult) {
                long elapsed = Math.max(1, System.currentTimeMillis() - started);
                runOnUi(() -> {
                    appendLog(finalResult);
                    setTransferButtonsEnabled(true);

                    if (finalResult != null && finalResult.toLowerCase().contains("success")) {
                        File f = new File(workingDir, name);
                        long bytes = f.exists() ? f.length() : 0;
                        sessionReceivedBytes += bytes;
                        updateSessionStats();
                        if (bytes > 0) {
                            double kbps = (bytes / 1024.0) / (elapsed / 1000.0);
                            binding.bandwidthHint.setText(
                                    String.format("Last transfer ~ %.1f KB/s (%d ms)", kbps, elapsed));
                        }
                        recordSuccess(true, name, savePath);
                    }
                });
            }
        });
    }

    private void runUploadSearch() {
        String name = binding.transferFilename.getText() != null
                ? binding.transferFilename.getText().toString().trim()
                : "";

        if (name.isEmpty()) {
            Toast.makeText(getContext(), "Enter a file name to search", Toast.LENGTH_SHORT).show();
            return;
        }

        FileIndexer indexer = FileIndexer.getInstance();
        if (indexer.isCacheEmpty()) {
            Toast.makeText(getContext(), "Index empty — refreshing…", Toast.LENGTH_SHORT).show();
            refreshIndexer();
            return;
        }

        appendLog("Searching index for \"" + name + "\"…");
        setTransferButtonsEnabled(false);

        new Thread(() -> {
            List<String> matches = indexer.searchFilesByKeyword(name);
            runOnUi(() -> {
                setTransferButtonsEnabled(true);
                if (matches.isEmpty()) {
                    appendLog("No local files matched \"" + name + "\"");
                    Toast.makeText(getContext(), "No matches — try Refresh index", Toast.LENGTH_SHORT).show();
                    return;
                }
                if (matches.size() == 1) {
                    confirmSingleUpload(matches.get(0));
                } else {
                    showMatchPicker(matches);
                }
            });
        }).start();
    }

    private void confirmSingleUpload(String absolutePath) {
        File f = new File(absolutePath);
        new AlertDialog.Builder(requireContext())
                .setTitle("Upload this file?")
                .setMessage(f.getName() + "\n\n" + absolutePath)
                .setPositiveButton("Confirm upload", (d, w) -> performUpload(absolutePath))
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void showMatchPicker(List<String> matches) {
        String[] labels = new String[matches.size()];
        for (int i = 0; i < matches.size(); i++) {
            File f = new File(matches.get(i));
            labels[i] = f.getName() + "  ·  " + f.getParent();
        }

        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                requireContext(),
                android.R.layout.simple_list_item_1,
                labels
        );

        new AlertDialog.Builder(requireContext())
                .setTitle("Choose file to upload (" + matches.size() + ")")
                .setAdapter(adapter, (dialog, which) -> performUpload(matches.get(which)))
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void performUpload(String absolutePath) {
        File local = new File(absolutePath);
        String command = "/upload " + absolutePath;
        appendLog("Upload: " + local.getName() + " ← " + absolutePath);
        setTransferButtonsEnabled(false);

        long started = System.currentTimeMillis();
        File parent = local.getParentFile() != null ? local.getParentFile() : requireContext().getFilesDir();

        NetworkManager.processProtocolCommand(command, parent, new NetworkCallback() {
            @Override
            public void onConsoleUpdate(String outputText) {
                runOnUi(() -> appendLog(outputText));
            }

            @Override
            public void onOperationComplete(String finalResult) {
                long elapsed = Math.max(1, System.currentTimeMillis() - started);
                runOnUi(() -> {
                    appendLog(finalResult);
                    setTransferButtonsEnabled(true);

                    if (finalResult != null && finalResult.toLowerCase().contains("success")) {
                        long bytes = local.exists() ? local.length() : 0;
                        sessionSentBytes += bytes;
                        updateSessionStats();
                        if (bytes > 0) {
                            double kbps = (bytes / 1024.0) / (elapsed / 1000.0);
                            binding.bandwidthHint.setText(
                                    String.format("Last transfer ~ %.1f KB/s (%d ms)", kbps, elapsed));
                        }
                        recordSuccess(false, local.getName(), absolutePath);
                    }
                });
            }
        });
    }

    private void setTransferButtonsEnabled(boolean enabled) {
        if (binding == null) return;
        binding.btnDownload.setEnabled(enabled);
        binding.btnUpload.setEnabled(enabled);
    }

    private void updateSessionStats() {
        if (binding == null) return;
        binding.sessionStats.setText(
                "Sent: " + formatSize(sessionSentBytes)
                        + " · Received: " + formatSize(sessionReceivedBytes));
    }

    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        return String.format("%.1f MB", bytes / (1024.0 * 1024));
    }

    private void appendLog(String line) {
        if (binding == null) return;
        binding.transferLog.setText(binding.transferLog.getText() + line + "\n");
    }

    private void runOnUi(Runnable r) {
        if (getActivity() == null) return;
        getActivity().runOnUiThread(() -> {
            if (binding != null) r.run();
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}

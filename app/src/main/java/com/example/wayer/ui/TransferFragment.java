package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.example.wayer.R;
import com.example.wayer.core.Config;
import com.example.wayer.databinding.FragmentTransferBinding;
import com.example.wayer.network.NetworkCallback;
import com.example.wayer.network.NetworkManager;
import com.example.wayer.transfer.TransferController;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.Socket;

/**
 * Transfer screen.
 * - Test TCP link to WayerPC (Java)
 * - Download (/ask) and Upload via NetworkManager (Java sockets)
 * - Optional C++ listener (Action 6)
 */
public class TransferFragment extends Fragment {

    private FragmentTransferBinding binding;

    private long sessionSentBytes = 0;
    private long sessionReceivedBytes = 0;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentTransferBinding.inflate(inflater, container, false);
        setupUI();
        return binding.getRoot();
    }

    private void setupUI() {
        binding.connectionDetails.setText("Target: " + Config.HOST + ":" + Config.PORT);
        binding.connectionStatus.setText("Not tested");
        updateSessionStats();

        binding.btnTestConnection.setOnClickListener(v -> testConnection());
        binding.btnStartListener.setOnClickListener(v -> startListener());
        binding.btnDownload.setOnClickListener(v -> runTransfer(true));
        binding.btnUpload.setOnClickListener(v -> runTransfer(false));
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

    /**
     * @param download true → /ask from PC; false → /upload to PC
     */
    private void runTransfer(boolean download) {
        String name = binding.transferFilename.getText() != null
                ? binding.transferFilename.getText().toString().trim()
                : "";

        if (name.isEmpty()) {
            Toast.makeText(getContext(), "Enter a file name", Toast.LENGTH_SHORT).show();
            return;
        }

        File workingDir = requireContext().getFilesDir();
        String command = (download ? "/ask " : "/upload ") + name;

        appendLog((download ? "Download" : "Upload") + ": " + name);
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

                    // Rough session accounting (exact sizes come later from protocol)
                    if (finalResult != null && finalResult.toLowerCase().contains("success")) {
                        File f = new File(workingDir, name);
                        long bytes = f.exists() ? f.length() : 0;
                        if (download) sessionReceivedBytes += bytes;
                        else sessionSentBytes += bytes;

                        updateSessionStats();
                        if (bytes > 0) {
                            double kbps = (bytes / 1024.0) / (elapsed / 1000.0);
                            binding.bandwidthHint.setText(
                                    String.format("Last transfer ~ %.1f KB/s (%d ms)", kbps, elapsed));
                        }
                        binding.recentTransfersEmpty.setText("Last: " + (download ? "↓ " : "↑ ") + name);
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

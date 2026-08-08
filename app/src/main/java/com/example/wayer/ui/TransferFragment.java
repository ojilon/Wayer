package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.example.wayer.core.Config;
import com.example.wayer.databinding.FragmentTransferBinding;
import com.example.wayer.network.NetworkCallback;
import com.example.wayer.transfer.TransferController;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;

/**
 * Transfer screen.
 * - Shows connection status to WayerPC
 * - Test connection (Java socket – networking stays on Java side)
 * - Optional C++ listener (Action 6)
 * - Activity log for the user
 */
public class TransferFragment extends Fragment {

    private FragmentTransferBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentTransferBinding.inflate(inflater, container, false);
        setupUI();
        return binding.getRoot();
    }

    private void setupUI() {
        binding.connectionDetails.setText("Target: " + Config.HOST + ":" + Config.PORT);
        binding.connectionStatus.setText("Not tested");

        binding.btnTestConnection.setOnClickListener(v -> testConnection());
        binding.btnStartListener.setOnClickListener(v -> startListener());
    }

    /**
     * Lightweight TCP test to WayerPC.
     * Networking stays in Java (as requested). Runs off the UI thread.
     */
    private void testConnection() {
        appendLog("Testing connection to " + Config.HOST + ":" + Config.PORT + "…");
        binding.connectionStatus.setText("Testing…");

        new Thread(() -> {
            boolean ok = false;
            String message;
            long start = System.currentTimeMillis();

            try (Socket socket = new Socket()) {
                socket.connect(new InetSocketAddress(Config.HOST, Config.PORT), 3000);
                // Optional tiny handshake if the PC protocol supports a ping later
                ok = socket.isConnected();
                long ms = System.currentTimeMillis() - start;
                message = ok
                        ? "Connected (" + ms + " ms)"
                        : "Socket opened but not connected";
            } catch (Exception e) {
                message = "Failed: " + e.getMessage();
            }

            boolean finalOk = ok;
            String finalMessage = message;

            if (getActivity() == null) return;
            getActivity().runOnUiThread(() -> {
                if (binding == null) return;
                binding.connectionStatus.setText(finalMessage);
                binding.connectionStatus.setTextColor(
                        getResources().getColor(
                                finalOk ? com.example.wayer.R.color.wayer_success
                                        : com.example.wayer.R.color.wayer_error,
                                null
                        )
                );
                appendLog(finalMessage);
            });
        }).start();
    }

    /** Ask C++ / TransferController to start a listener (Action 6). */
    private void startListener() {
        appendLog("Starting listener on port 8080…");
        TransferController.startServerListener(8080, status -> {
            if (binding == null) return;
            String line = "Listener: " + status.getStatus() + " port=" + status.getPort();
            appendLog(line);
            if ("listening".equalsIgnoreCase(status.getStatus())
                    || "ready".equalsIgnoreCase(status.getStatus())) {
                binding.connectionStatus.setText("Listener active");
            }
        });
    }

    private void appendLog(String line) {
        if (binding == null) return;
        CharSequence current = binding.transferLog.getText();
        binding.transferLog.setText(current + line + "\n");
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}

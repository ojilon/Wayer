package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import com.example.wayer.databinding.FragmentTransferBinding;
import com.example.wayer.transfer.TransferController;

public class TransferFragment extends Fragment {

    private FragmentTransferBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentTransferBinding.inflate(inflater, container, false);
        startTransferServer();
        return binding.getRoot();
    }

    private void startTransferServer() {
        TransferController.startServerListener(8080, status -> {
            if (binding != null) {
                android.util.Log.i("TransferFragment", "Server Status: " + status.getStatus() + " on Port: " + status.getPort());
            }
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
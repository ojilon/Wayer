package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentTransferBinding;

public class TransferFragment extends Fragment {
    
    // Hold the UI struct pointer
    private FragmentTransferBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout
        binding = FragmentTransferBinding.inflate(inflater, container, false);
        
        loadTransferInfo();
        
        return binding.getRoot();
    }

    // Isolate UI event bindings here
    private void loadTransferInfo() {
        // Query C++ action ID 4 for network/transfer engine state
        String networkInfo = NativeEngine.processAction(4, "");
        android.util.Log.i("TransferFragment", "C++ Network Response: " + networkInfo);
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // CRITICAL: Clear the pointer to prevent memory leaks when the fragment is in the backstack
        //Free layout memory
        binding = null; 
    }
}
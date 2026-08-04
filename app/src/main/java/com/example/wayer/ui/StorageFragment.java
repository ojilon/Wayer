package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentStorageBinding;

public class StorageFragment extends Fragment {
    
    // Hold the UI struct pointer
    private FragmentStorageBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout
        binding = FragmentStorageBinding.inflate(inflater, container, false);
        
        loadStorageData();
        
        return binding.getRoot();
    }

    // Isolate UI event bindings here
    private void loadStorageData() {
        if (getContext() == null) return;

        // Query app internal files directory via C++ Action ID 3
        String path = getContext().getFilesDir().getAbsolutePath();
        String resultJson = NativeEngine.processAction(3, path);

        // If your XML layout contains a TextView with id @+id/txtStorageInfo:
        // binding.txtStorageInfo.setText(resultJson);
        
        android.util.Log.i("StorageFragment", "C++ Storage Response: " + resultJson);

    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // CRITICAL: Clear the pointer to prevent memory leaks when the fragment is in the backstack
        binding = null; 
    }
}
package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.example.wayer.core.NativeEngine;
import com.example.wayer.databinding.FragmentFilesBinding;

public class FilesFragment extends Fragment {
    
    // Hold the UI struct pointer
    private FragmentFilesBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout
        binding = FragmentFilesBinding.inflate(inflater, container, false);
        loadFiles();        
        return binding.getRoot();
    }

    // Isolate UI event bindings here
    private void loadFiles() {
        if (getContext() == null) return;

        String path = getContext().getFilesDir().getAbsolutePath();
        NativeEngine.processActionAsync(3, path, result -> {
            if(binding != null) {
                android.util.Log.i("FilesFragment", "Files Response: " + result);
            }
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // CRITICAL: Clear the pointer to prevent memory leaks when the fragment is in the backstack
        binding = null; 
    }
}
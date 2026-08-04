package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import com.example.wayer.databinding.FragmentHomeBinding;

public class HomeFragment extends Fragment {
    
    // Hold the UI struct pointer
    private FragmentHomeBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        
        setupUI();
        
        return binding.getRoot();
    }

    // Isolate UI event bindings here
    private void setupUI() {
        // Example: binding.refreshButton.setOnClickListener(v -> NativeEngine.triggerRefresh());
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // CRITICAL: Clear the pointer to prevent memory leaks when the fragment is in the backstack
        binding = null; 
    }
}
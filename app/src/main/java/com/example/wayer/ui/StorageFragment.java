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

    private FragmentStorageBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentStorageBinding.inflate(inflater, container, false);
        loadStorageData();
        return binding.getRoot();
    }

    private void loadStorageData() {
        if (getContext() == null) return;

        String path = getContext().getFilesDir().getAbsolutePath();
        NativeEngine.processActionAsync(3, path, result -> {
            if (binding != null) {
                android.util.Log.i("StorageFragment", "Storage Response: " + result);
            }
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
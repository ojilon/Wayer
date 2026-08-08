package com.example.wayer.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import com.example.wayer.R;
import com.example.wayer.databinding.FragmentHomeBinding;
import com.example.wayer.core.NativeEngine;
import com.example.wayer.core.MainActivity;

import org.json.JSONObject;
import org.json.JSONException;

public class HomeFragment extends Fragment {

    private FragmentHomeBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        setupUI();
        return binding.getRoot();
    }

    private void setupUI() {
        // Fetch and display storage stats (Action ID 7)
        NativeEngine.processActionAsync(7, "/storage/emulated/0", rawJson -> {
            try {
                JSONObject data = new JSONObject(rawJson);
                int progress = data.getInt("progress_percent");
                long usedGb = data.getLong("used_bytes") / (1024L * 1024L * 1024L);
                long totalGb = data.getLong("total_bytes") / (1024L * 1024L * 1024L);

                binding.storageProgress.setProgress(progress);
                binding.storageSummary.setText(usedGb + " GB used of " + totalGb + " GB");
            } catch (JSONException e) {
                e.printStackTrace();
            }
        });

        // Navigate via MainActivity's binding instead of findViewById
        binding.actionFiles.setOnClickListener(v ->
            ((MainActivity) requireActivity()).navigateTo(R.id.nav_files)
        );

        binding.actionTransfer.setOnClickListener(v ->
            ((MainActivity) requireActivity()).navigateTo(R.id.nav_transfer)
        );

        binding.actionTerminal.setOnClickListener(v ->
            Toast.makeText(getContext(), "Terminal button clicked!", Toast.LENGTH_SHORT).show()
        );

        binding.actionStorage.setOnClickListener(v ->
            ((MainActivity) requireActivity()).navigateTo(R.id.nav_storage)
        );
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
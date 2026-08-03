package com.example.wayer.ui;

import android.os.Bundle;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.wayer.R;


public class HomeFragment extends Fragment {
    public HomeFragment() {
        super(R.layout.fragment_home);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        View filesButton = view.findViewById(R.id.action_files);
        View transferButton = view.findViewById(R.id.action_transfer);
        View documentsButton = view.findViewById(R.id.action_documents);
        View terminalButton = view.findViewById(R.id.action_terminal);

        filesButton.setOnClickListener(v -> {
            openScreen(new FilesFragment());
        });

        transferButton.setOnClickListener(v -> {
            openScreen(new TransferFragment());
        });

        documentsButton.setOnClickListener(v -> {
            openScreen(new TerminalFragment());
        });
    }

    private void openScreen(Fragment fragment) {

        requireActivity()
        .getSupportFragmentManager()
        .beginTransaction()
        .replace(R.id.fragment_container, fragment)
        .addToBackStack(null)
        .commit();
    }
}
package com.example.wayer.ui;

import android.os.Bundle;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.wayer.R;

import java.util.ArrayList;
import java.util.List;

public class FilesFragment extends Fragment {

    public FilesFragment() {
        super(R.layout.fragment_files);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {

        super.onViewCreated(view, savedInstanceState);

        RecyclerView fileList = view.findViewById(R.id.file_list);

        fileList.setLayoutManager( new LinearLayoutManager(requireContext()) );

        List<FileItem> files = new ArrayList<>();

        files.add( new FileItem( "Documents", "Folder", true) );

        files.add(
                new FileItem(
                        "Download",
                        "Folder",
                        true
                )
        );

        files.add(
                new FileItem(
                        "Pictures",
                        "Folder",
                        true
                )
        );

        files.add(
                new FileItem(
                        "notes.txt",
                        "12 KB",
                        false
                )
        );

        FileAdapter adapter = new FileAdapter(files);

        fileList.setAdapter(adapter);
    }
}
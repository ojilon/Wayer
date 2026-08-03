package com.example.wayer.ui;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.wayer.R;

import java.util.List;

public class FileAdapter
        extends RecyclerView.Adapter<FileAdapter.FileViewHolder> {

    private List<FileItem> files;

    public FileAdapter(List<FileItem> files) {
        this.files = files;
    }

    @NonNull
    @Override
    public FileViewHolder onCreateViewHolder(
            @NonNull ViewGroup parent,
            int viewType) {

        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_file, parent, false);

        return new FileViewHolder(view);
    }

    @Override
    public void onBindViewHolder(
            @NonNull FileViewHolder holder,
            int position) {

        FileItem file = files.get(position);

        holder.fileName.setText(file.getName());
        holder.fileDetails.setText(file.getDetails());
    }

    @Override
    public int getItemCount() {
        return files.size();
    }

    static class FileViewHolder extends RecyclerView.ViewHolder {

        TextView fileName;
        TextView fileDetails;

        public FileViewHolder(@NonNull View itemView) {
            super(itemView);

            fileName = itemView.findViewById(R.id.file_name);
            fileDetails = itemView.findViewById(R.id.file_details);
        }
    }
}
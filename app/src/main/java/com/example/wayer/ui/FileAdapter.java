package com.example.wayer.ui;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.wayer.R;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Displays FileItem rows with compact sizing and simple type icons.
 */
public class FileAdapter extends RecyclerView.Adapter<FileAdapter.ViewHolder> {

    public interface OnItemClickListener {
        void onItemClick(FileItem item);
        void onItemLongClick(FileItem item);
    }

    public interface OnSelectionChangedListener {
        void onSelectionChanged(int count);
    }

    private final List<FileItem> items = new ArrayList<>();
    private final Set<String> selectedPaths = new LinkedHashSet<>();
    private boolean selectionMode = false;
    private OnItemClickListener listener;
    private OnSelectionChangedListener selectionListener;

    public void setOnItemClickListener(OnItemClickListener listener) {
        this.listener = listener;
    }

    public void setOnSelectionChangedListener(OnSelectionChangedListener listener) {
        this.selectionListener = listener;
    }

    /** Selection mode shows checkboxes; row taps toggle instead of opening. */
    public void setSelectionMode(boolean on) {
        selectionMode = on;
        if (!on) selectedPaths.clear();
        notifyDataSetChanged();
    }

    public boolean isSelectionMode() {
        return selectionMode;
    }

    public void toggleSelection(String path) {
        if (path == null) return;
        if (!selectedPaths.remove(path)) {
            selectedPaths.add(path);
        }
        notifyDataSetChanged();
        if (selectionListener != null) selectionListener.onSelectionChanged(selectedPaths.size());
    }

    public List<String> getSelectedPaths() {
        return new ArrayList<>(selectedPaths);
    }

    public void submitList(List<FileItem> newItems) {
        items.clear();
        if (newItems != null) {
            items.addAll(newItems);
        }
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_file, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        FileItem item = items.get(position);
        holder.name.setText(item.getName());
        holder.details.setText(item.getDetails());
        holder.icon.setImageResource(iconFor(item));
        holder.selectBox.setVisibility(selectionMode ? View.VISIBLE : View.GONE);
        holder.selectBox.setChecked(selectedPaths.contains(item.getPath()));

        holder.itemView.setOnClickListener(v -> {
            if (selectionMode) {
                toggleSelection(item.getPath());
            } else if (listener != null) {
                listener.onItemClick(item);
            }
        });

        holder.itemView.setOnLongClickListener(v -> {
            if (listener != null) listener.onItemLongClick(item);
            return true;
        });
    }

    private static int iconFor(FileItem item) {
        if (item.isDirectory()) return R.drawable.ic_folder;
        String name = item.getName().toLowerCase(Locale.US);
        int dot = name.lastIndexOf('.');
        String ext = dot >= 0 ? name.substring(dot + 1) : "";
        return switch (ext) {
            case "png", "jpg", "jpeg", "gif", "webp", "bmp", "heic" -> R.drawable.ic_file_image;
            case "mp4", "mkv", "avi", "mov", "webm", "3gp" -> R.drawable.ic_file_video;
            case "mp3", "wav", "flac", "aac", "ogg", "m4a" -> R.drawable.ic_file_audio;
            case "pdf", "doc", "docx", "txt", "md", "rtf", "odt" -> R.drawable.ic_file_doc;
            default -> R.drawable.ic_file;
        };
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        final ImageView icon;
        final TextView name;
        final TextView details;
        final CheckBox selectBox;

        ViewHolder(@NonNull View itemView) {
            super(itemView);
            icon = itemView.findViewById(R.id.file_icon);
            name = itemView.findViewById(R.id.file_name);
            details = itemView.findViewById(R.id.file_details);
            selectBox = itemView.findViewById(R.id.row_checkbox);
        }
    }
}

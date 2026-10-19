package com.example.wayer.ui;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.wayer.R;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class DaySectionAdapter extends RecyclerView.Adapter<DaySectionAdapter.VH> {

    public interface Listener {
        void onSeeMore(DaySection section);
        void onFileClick(DaySection.FileEntry file);
    }

    private final List<DaySection> data = new ArrayList<>();
    private final Listener listener;

    public DaySectionAdapter(Listener listener) {
        this.listener = listener;
    }

    public void submit(List<DaySection> sections) {
        data.clear();
        if (sections != null) data.addAll(sections);
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_day_section, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH h, int position) {
        DaySection section = data.get(position);
        h.dayLabel.setText(section.day);
        h.dayMore.setOnClickListener(v -> {
            if (listener != null) listener.onSeeMore(section);
        });

        ImageView[] slots = { h.prev0, h.prev1, h.prev2, h.prev3 };
        for (ImageView slot : slots) {
            slot.setImageDrawable(null);
            slot.setOnClickListener(null);
            slot.setVisibility(View.INVISIBLE);
        }

        int n = Math.min(4, section.files.size());
        for (int i = 0; i < n; i++) {
            DaySection.FileEntry f = section.files.get(i);
            ImageView slot = slots[i];
            slot.setVisibility(View.VISIBLE);
            bindPreview(slot, f);
            slot.setOnClickListener(v -> {
                if (listener != null) listener.onFileClick(f);
            });
        }
    }

    private void bindPreview(ImageView slot, DaySection.FileEntry f) {
        if ("image".equals(f.kind)) {
            // small decode off the UI thread would be better later; OK for few thumbs
            try {
                BitmapFactory.Options o = new BitmapFactory.Options();
                o.inSampleSize = 8;
                Bitmap bmp = BitmapFactory.decodeFile(f.path, o);
                if (bmp != null) {
                    slot.setImageBitmap(bmp);
                    return;
                }
            } catch (Exception ignored) { }
        }
        // non-image or failed decode → generic icon
        int icon = R.drawable.ic_file;
        if ("video".equals(f.kind)) {
            // use ic_file if you have no video icon yet
            icon = R.drawable.ic_file;
        } else if ("document".equals(f.kind)) {
            icon = R.drawable.ic_file;
        }
        slot.setImageResource(icon);
        slot.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
    }

    @Override
    public int getItemCount() {
        return data.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        final TextView dayLabel;
        final ImageButton dayMore;
        final ImageView prev0, prev1, prev2, prev3;

        VH(@NonNull View v) {
            super(v);
            dayLabel = v.findViewById(R.id.day_label);
            dayMore = v.findViewById(R.id.day_more);
            prev0 = v.findViewById(R.id.prev0);
            prev1 = v.findViewById(R.id.prev1);
            prev2 = v.findViewById(R.id.prev2);
            prev3 = v.findViewById(R.id.prev3);
        }
    }
}
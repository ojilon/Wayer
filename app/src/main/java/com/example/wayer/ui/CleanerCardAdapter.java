package com.example.wayer.ui;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.wayer.R;

import java.util.ArrayList;
import java.util.List;

/**
 * Square shortcut cards for the Cleaner home grid. One item per utility;
 * future utilities from docs/CLEANER_IDEAS.md plug in as one more Card.
 */
public class CleanerCardAdapter extends RecyclerView.Adapter<CleanerCardAdapter.ViewHolder> {

    public static final class Card {
        public final String title;
        public final int iconRes;
        public final boolean enabled;
        public String status;

        public Card(String title, int iconRes, String status, boolean enabled) {
            this.title = title;
            this.iconRes = iconRes;
            this.status = status;
            this.enabled = enabled;
        }
    }

    public interface OnCardClickListener {
        void onCardClick(int position);
    }

    private final List<Card> cards = new ArrayList<>();
    private OnCardClickListener listener;

    public void setOnCardClickListener(OnCardClickListener listener) {
        this.listener = listener;
    }

    public void submitCards(List<Card> newCards) {
        cards.clear();
        if (newCards != null) {
            cards.addAll(newCards);
        }
        notifyDataSetChanged();
    }

    public void setStatus(int position, String status) {
        if (position < 0 || position >= cards.size()) return;
        cards.get(position).status = status;
        notifyItemChanged(position);
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_cleaner_card, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Card card = cards.get(position);
        holder.icon.setImageResource(card.iconRes);
        holder.title.setText(card.title);
        holder.status.setText(card.status);
        holder.itemView.setAlpha(card.enabled ? 1.0f : 0.45f);
        holder.itemView.setOnClickListener(v -> {
            if (listener != null) listener.onCardClick(position);
        });
    }

    @Override
    public int getItemCount() {
        return cards.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        final ImageView icon;
        final TextView title;
        final TextView status;

        ViewHolder(@NonNull View itemView) {
            super(itemView);
            icon = itemView.findViewById(R.id.card_icon);
            title = itemView.findViewById(R.id.card_title);
            status = itemView.findViewById(R.id.card_status);
        }
    }
}

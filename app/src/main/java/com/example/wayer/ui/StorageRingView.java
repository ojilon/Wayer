package com.example.wayer.ui;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;

import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.example.wayer.R;

/**
 * Simple donut chart: each category is an arc.
 * Colors match the category rows in fragment_storage.
 */
public class StorageRingView extends View {

    private final Paint arcPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint holePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF oval = new RectF();

    // bytes per slice; order matches colors[]
    private long[] values = new long[6];
    private int[] colors;

    public StorageRingView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        arcPaint.setStyle(Paint.Style.STROKE);
        arcPaint.setStrokeCap(Paint.Cap.BUTT);
        holePaint.setStyle(Paint.Style.FILL);
        holePaint.setColor(ContextCompat.getColor(context, R.color.wayer_surface));

        colors = new int[] {
                ContextCompat.getColor(context, R.color.wayer_cat_images),
                ContextCompat.getColor(context, R.color.wayer_cat_videos),
                ContextCompat.getColor(context, R.color.wayer_cat_audio),
                ContextCompat.getColor(context, R.color.wayer_cat_documents),
                ContextCompat.getColor(context, R.color.wayer_cat_system),
                ContextCompat.getColor(context, R.color.wayer_cat_others),
        };
    }

    /** images, videos, audio, documents, system, others */
    public void setCategoryBytes(long images, long videos, long audio,
                                 long documents, long system, long others) {
        values[0] = Math.max(0, images);
        values[1] = Math.max(0, videos);
        values[2] = Math.max(0, audio);
        values[3] = Math.max(0, documents);
        values[4] = Math.max(0, system);
        values[5] = Math.max(0, others);
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float w = getWidth();
        float h = getHeight();
        float size = Math.min(w, h);
        float stroke = size * 0.14f;
        float pad = stroke / 2f + 2f;
        oval.set(pad, pad, size - pad, size - pad);
        arcPaint.setStrokeWidth(stroke);

        long sum = 0;
        for (long v : values) sum += v;
        if (sum <= 0) {
            arcPaint.setColor(ContextCompat.getColor(getContext(), R.color.wayer_outline_glass));
            canvas.drawArc(oval, -90f, 360f, false, arcPaint);
            return;
        }

        float start = -90f; // 12 o'clock
        for (int i = 0; i < values.length; i++) {
            if (values[i] <= 0) continue;
            float sweep = 360f * ((float) values[i] / (float) sum);
            arcPaint.setColor(colors[i]);
            canvas.drawArc(oval, start, sweep, false, arcPaint);
            start += sweep;
        }
    }
}
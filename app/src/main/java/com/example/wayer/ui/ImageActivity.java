package com.example.wayer.ui;

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.view.View;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.example.wayer.databinding.ActivityImageBinding;

/**
 * Full-window image viewer.
 * Java loads a downsampled bitmap for now.
 * Later: optional C++ decode path via native/third_party libraries.
 */
public class ImageActivity extends AppCompatActivity {

    public static final String EXTRA_FILE_PATH = "file_path";

    private ActivityImageBinding binding;

    public static void open(Context context, String filePath) {
        Intent intent = new Intent(context, ImageActivity.class);
        intent.putExtra(EXTRA_FILE_PATH, filePath);
        context.startActivity(intent);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityImageBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        String path = getIntent().getStringExtra(EXTRA_FILE_PATH);
        if (path == null || path.isEmpty()) {
            Toast.makeText(this, "No image path", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        binding.toolbar.setNavigationOnClickListener(v -> finish());
        binding.btnClose.setOnClickListener(v -> finish());
        binding.imagePath.setText(path);

        String name = path.substring(path.lastIndexOf('/') + 1);
        binding.toolbar.setTitle(name);

        loadImage(path);
    }

    private void loadImage(String path) {
        // Downsample large images to avoid OOM
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, bounds);

        int sample = 1;
        int maxSide = 2048;
        while (bounds.outWidth / sample > maxSide || bounds.outHeight / sample > maxSide) {
            sample *= 2;
        }

        BitmapFactory.Options opts = new BitmapFactory.Options();
        opts.inSampleSize = sample;
        Bitmap bmp = BitmapFactory.decodeFile(path, opts);

        if (bmp != null) {
            binding.imageView.setImageBitmap(bmp);
            binding.placeholder.setVisibility(View.GONE);
        } else {
            binding.placeholder.setText("Could not load image\n" + path);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        binding = null;
    }
}

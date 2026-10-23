package com.example.wayer.core;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.content.Intent;
import android.provider.Settings;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.example.wayer.R;
import com.example.wayer.bridge.NativeEngine;
import com.example.wayer.databinding.ActivityMainBinding;
import com.example.wayer.ui.*;

/**
 * MainActivity — updated Oct 2025 for standard Material3 navigation.
 *
 * Changes from previous HorizontalScrollView+ToggleGroup hack:
 *   * Bottom bar is now a NavigationBarView (Material3) with 6 items from
 *     menu_bottom_nav.xml. No custom scroll, no 120dp fixed buttons.
 *   * Listener is setOnItemSelectedListener (not addOnButtonCheckedListener).
 *   * navigateTo() and scrollBarTo() simplified — no scroll offset needed,
 *     NavigationBarView handles indicator animation and accessibility.
 *   * Bottom nav supports badge API (future: show new transfer count).
 *
 * Permission flow unchanged (Android 10 legacy vs Android 11+ MANAGE_ALL_FILES).
 */
public class MainActivity extends AppCompatActivity {

    private ActivityMainBinding binding;

    private final ActivityResultLauncher<Intent> manageFilesAccessLauncher =
        registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                if (android.os.Environment.isExternalStorageManager()) {
                    android.util.Log.i("WayerStorage", "Manage All Files access granted by user.");
                } else {
                    android.util.Log.w("WayerStorage", "Manage All Files access denied by user.");
                }
            }
        });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        ThemePrefs.applyStored(this);
        super.onCreate(savedInstanceState);

        NativeEngine.initEngine();
        NativeEngine.initAppPathsAsync(this, result -> android.util.Log.i("WayerNative", "initAppPaths: " + result));

        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        UiChrome.apply(this);

        checkStoragePermissions();
        setupNavigation();

        if (savedInstanceState == null) {
            binding.bottomNavigation.setSelectedItemId(R.id.nav_home);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        UiChrome.apply(this);
    }

    private void checkStoragePermissions() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            if (!android.os.Environment.isExternalStorageManager()) {
                try {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                    intent.addCategory("android.intent.category.DEFAULT");
                    intent.setData(android.net.Uri.parse(String.format("package:%s", getPackageName())));
                    manageFilesAccessLauncher.launch(intent);
                } catch (Exception e) {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                    manageFilesAccessLauncher.launch(intent);
                }
            }
        } else {
            if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {

                requestPermissions(new String[]{
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                }, 101);
            }
        }
    }

    private void setupNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.nav_home) showFragment(new HomeFragment());
            else if (id == R.id.nav_storage) showFragment(new StorageFragment());
            else if (id == R.id.nav_transfer) showFragment(new TransferFragment());
            else if (id == R.id.nav_files) showFragment(new FilesFragment());
            else if (id == R.id.nav_cleaner) showFragment(new CleanerFragment());
            else if (id == R.id.nav_internals) showFragment(new InternalFragment());
            else return false;
            return true;
        });
    }

    private void showFragment(Fragment fragment) {
        getSupportFragmentManager().beginTransaction()
            .replace(R.id.fragment_container, fragment)
            .commit();
    }

    /** Navigate to a bottom-nav destination (used by Home quick actions). */
    public void navigateTo(int itemId) {
        binding.bottomNavigation.setSelectedItemId(itemId);
    }

    /** @deprecated no-op since Oct 2025 — bottom bar no longer scrolls */
    @Deprecated
    private void scrollBarTo(int itemId) {
        // NavigationBarView handles visibility; no scroll needed.
    }
}

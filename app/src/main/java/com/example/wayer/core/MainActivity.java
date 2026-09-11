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
import com.example.wayer.databinding.ActivityMainBinding;
import com.example.wayer.ui.*;

public class MainActivity extends AppCompatActivity {
    
    private ActivityMainBinding binding;
    
    // NEW: Register the launcher for the Manage All Files permission settings screen
    private final ActivityResultLauncher<Intent> manageFilesAccessLauncher = 
        registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
            // This callback triggers when the user returns from the settings screen
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                if (android.os.Environment.isExternalStorageManager()) {
                    android.util.Log.i("WayerStorage", "Manage All Files access granted by user.");
                    // Optional: Call your logic here to start using storage right away
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
        
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        UiChrome.apply(this);

        checkStoragePermissions();
        setupNavigation();

        if (savedInstanceState == null) {
            showFragment(new HomeFragment());
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        UiChrome.apply(this);
    }

    private void checkStoragePermissions() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            // Modern Platform Logic (Android 11+)
            if (!android.os.Environment.isExternalStorageManager()) {
                try {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                    intent.addCategory("android.intent.category.DEFAULT");
                    intent.setData(android.net.Uri.parse(String.format("package:%s", getPackageName())));
                    // MODERNIZED: Use launcher instead of startActivityForResult
                    manageFilesAccessLauncher.launch(intent);
                } catch (Exception e) {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                    // MODERNIZED: Use launcher instead of startActivityForResult
                    manageFilesAccessLauncher.launch(intent);
                }
            }
        } else {
            // Legacy Platform Logic (Android 10 and older)
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
            int itemId = item.getItemId();
            if (itemId == R.id.nav_home) return showFragment(new HomeFragment());
            if (itemId == R.id.nav_storage) return showFragment(new StorageFragment());
            if (itemId == R.id.nav_transfer) return showFragment(new TransferFragment());
            if (itemId == R.id.nav_files) return showFragment(new FilesFragment());
            return false;
        });
    }

    private boolean showFragment(Fragment fragment) {
        getSupportFragmentManager().beginTransaction()
            .replace(R.id.fragment_container, fragment)
            .commit();
        return true;
    }

    public void navigateTo(int itemId) {
        binding.bottomNavigation.setSelectedItemId(itemId);
    }
}

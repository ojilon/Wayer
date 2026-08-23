package com.example.wayer.core;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.example.wayer.R;
import com.example.wayer.databinding.ActivityMainBinding;
import com.example.wayer.ui.*;

public class MainActivity extends AppCompatActivity {
    
    private ActivityMainBinding binding;

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

        String rootPath = getFilesDir().getAbsolutePath();
        String filesJson = NativeEngine.processAction(3, rootPath);
        android.util.Log.i("WayerStorageTest", "Directory Listing: " + filesJson );

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
        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED || 
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{
                Manifest.permission.READ_EXTERNAL_STORAGE, 
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            }, 101);
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

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
    
    // 1. Hold a reference to the UI struct
    private ActivityMainBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        //Initialize the native engine
        NativeEngine.initEngine();

        //test route call to verify di-directional communication
        String response = NativeEngine.processAction(1, "Ping from Java");
        android.util.Log.i("WayerNativeTest", "C++ Response:" + response);
        
        // 2. Inflate the layout using the binding
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        checkStoragePermissions();
        setupNavigation();

        // Query files in root storage via C++ backend(Action ID 3)
        String rootPath = getFilesDir().getAbsolutePath();
        String filesJson = NativeEngine.processAction(3, rootPath);
        android.util.Log.i("WayerStorageTest", "Directory Listing: " + filesJson );

        if (savedInstanceState == null) {
            showFragment(new HomeFragment());
        }
    }

    // Procedural abstraction for OS requirements
    private void checkStoragePermissions() {
        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED || 
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{
                Manifest.permission.READ_EXTERNAL_STORAGE, 
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            }, 101);
        }
    }

    // Functional abstraction for UI routing
    private void setupNavigation() {
        // Notice we don't use findViewById. We directly access bottomNavigation from the binding struct.
        binding.bottomNavigation.setOnItemSelectedListener(item -> {
            int itemId = item.getItemId();
            if (itemId == R.id.nav_home) return showFragment(new HomeFragment());
            if (itemId == R.id.nav_documents) return showFragment(new DocumentsFragment());
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
        return true; // Return true to satisfy the item selected listener
    }
}
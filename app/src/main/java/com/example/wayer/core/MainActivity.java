package com.example.wayer.core;

import android.os.Bundle;
import android.Manifest;
import android.content.pm.PackageManager;

import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;

import com.example.wayer.R;
import com.example.wayer.ui.*;

import com.google.android.material.navigation.NavigationBarView;

public class MainActivity extends AppCompatActivity {

    private NavigationBarView bottomnavigation;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_main);
        bottomnavigation = findViewById(R.id.bottom_navigation);

        // validate storage permissions
        String[] permissions = {
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        };
        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(permissions, 101);
        }

        //show home screen when the application starts.
        if ( savedInstanceState == null) {
            showFragment(new HomeFragment());
        }

        bottomnavigation.setOnItemSelectedListener(item -> {
            int itemId =item.getItemId();
            if (itemId == R.id.nav_home) {
                showFragment(new HomeFragment());
                return true;
            }

            if (itemId == R.id.nav_documents) {
                showFragment(new DocumentsFragment());
                return true;
            }

            if (itemId == R.id.nav_storage) {
                showFragment(new StorageFragment());
                return true;
            }

            if (itemId == R.id.nav_transfer) {
                showFragment(new TransferFragment());
                return true;
            }

            if (itemId == R.id.nav_files) {
                showFragment(new FilesFragment());
                return true;
            }

            return false;
        });
    }

    private void showFragment(Fragment fragment) {

        getSupportFragmentManager().beginTransaction().replace(R.id.fragment_container, fragment).commit();
    }
    
}
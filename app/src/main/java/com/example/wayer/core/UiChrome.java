package com.example.wayer.core;

import android.app.Activity;
import android.os.Build;
import android.view.View;
import android.view.Window;

import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.example.wayer.R;

/**
 * Status / navigation bar contrast for light vs dark Wayer themes.
 */
public final class UiChrome {

    private UiChrome() {}

    public static void apply(Activity activity) {
        if (activity == null) return;
        Window window = activity.getWindow();
        View decor = window.getDecorView();

        WindowCompat.setDecorFitsSystemWindows(window, true);

        boolean light = ThemePrefs.isLightUi(activity);

        int bg = activity.getResources().getColor(R.color.wayer_background, activity.getTheme());
        window.setStatusBarColor(bg);
        window.setNavigationBarColor(bg);

        WindowInsetsControllerCompat controller =
                WindowCompat.getInsetsController(window, decor);
        if (controller != null) {
            controller.setAppearanceLightStatusBars(light);
            controller.setAppearanceLightNavigationBars(light);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.setNavigationBarContrastEnforced(false);
        }
    }
}

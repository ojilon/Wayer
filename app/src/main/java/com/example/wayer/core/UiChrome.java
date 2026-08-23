package com.example.wayer.core;

import android.app.Activity;
import android.graphics.Color;
import android.os.Build;
import android.view.View;
import android.view.Window;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

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

        // Solid bars matching background token (avoid translucent wash)
        int bg = activity.getResources().getColor(
                activity.getResources().getIdentifier("wayer_background", "color", activity.getPackageName()),
                activity.getTheme());
        window.setStatusBarColor(bg);
        window.setNavigationBarColor(bg);

        WindowInsetsControllerCompat controller =
                WindowCompat.getInsetsController(window, decor);
        if (controller != null) {
            // Light UI → dark status/nav icons; dark UI → light icons
            controller.setAppearanceLightStatusBars(light);
            controller.setAppearanceLightNavigationBars(light);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.setNavigationBarContrastEnforced(false);
        }
    }
}

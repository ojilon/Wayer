package com.example.wayer.core;

import android.graphics.RenderEffect;
import android.graphics.Shader;
import android.os.Build;
import android.view.View;

/**
 * Optional frosted glass: RenderEffect blur on API 31+ when user enables it.
 * No-op on older devices.
 */
public final class GlassBlur {

    private static final float RADIUS = 18f;

    private GlassBlur() {}

    public static boolean isSupported() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S;
    }

    public static void applyTo(View panel, boolean enabled) {
        if (panel == null) return;
        if (!isSupported()) {
            // Keep translucent drawable; no runtime blur
            return;
        }
        if (enabled) {
            panel.setRenderEffect(
                    RenderEffect.createBlurEffect(RADIUS, RADIUS, Shader.TileMode.CLAMP));
        } else {
            panel.setRenderEffect(null);
        }
    }

    /** Apply using ThemePrefs blur flag. */
    public static void applyFromPrefs(View panel, android.content.Context context) {
        applyTo(panel, ThemePrefs.isBlurEnabled(context) && isSupported());
    }
}

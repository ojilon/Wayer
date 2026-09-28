package com.example.wayer.core;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;

import androidx.appcompat.app.AppCompatDelegate;

/**
 * App-wide appearance preference.
 * Night mode: System / Dark / Light.
 * Optional glass blur (API 31+) for side panels.
 */
public final class ThemePrefs {

    private static final String PREFS = "wayer_prefs";
    private static final String KEY_MODE = "night_mode";
    private static final String KEY_BLUR = "glass_blur";

    private ThemePrefs() {}

    public static int getMode(Context context) {
        return prefs(context).getInt(KEY_MODE, AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
    }

    public static void setMode(Context context, int mode) {
        prefs(context).edit().putInt(KEY_MODE, mode).apply();
        AppCompatDelegate.setDefaultNightMode(mode);
    }

    public static void applyStored(Context context) {
        AppCompatDelegate.setDefaultNightMode(getMode(context));
    }

    public static String cycle(Context context) {
        int current = getMode(context);
        int next;
        String label;
        if (current == AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM) {
            next = AppCompatDelegate.MODE_NIGHT_YES;
            label = "Dark";
        } else if (current == AppCompatDelegate.MODE_NIGHT_YES) {
            next = AppCompatDelegate.MODE_NIGHT_NO;
            label = "Light";
        } else {
            next = AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM;
            label = "System";
        }
        setMode(context, next);
        return label;
    }

    public static String labelFor(int mode) {
        if (mode == AppCompatDelegate.MODE_NIGHT_YES) return "Dark";
        if (mode == AppCompatDelegate.MODE_NIGHT_NO) return "Light";
        return "System";
    }

    public static String currentLabel(Context context) {
        return labelFor(getMode(context));
    }

    /** True when the active configuration is light (for status-bar icons). */
    public static boolean isLightUi(Context context) {
        int mode = getMode(context);
        if (mode == AppCompatDelegate.MODE_NIGHT_NO) return true;
        if (mode == AppCompatDelegate.MODE_NIGHT_YES) return false;
        int night = context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return night != Configuration.UI_MODE_NIGHT_YES;
    }

    public static boolean isBlurEnabled(Context context) {
        return prefs(context).getBoolean(KEY_BLUR, false);
    }

    public static void setBlurEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_BLUR, enabled).apply();
    }

    /** Toggle blur; returns new enabled state. */
    public static boolean toggleBlur(Context context) {
        boolean next = !isBlurEnabled(context);
        setBlurEnabled(context, next);
        return next;
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }
}

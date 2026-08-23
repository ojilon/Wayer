package com.example.wayer.core;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.appcompat.app.AppCompatDelegate;

/**
 * App-wide appearance preference.
 * Modes: follow system, force dark, force light.
 * Apply once at process start (MainActivity) and whenever the user changes theme in a sidebar.
 */
public final class ThemePrefs {

    private static final String PREFS = "wayer_prefs";
    private static final String KEY_MODE = "night_mode";

    private ThemePrefs() {}

    public static int getMode(Context context) {
        return prefs(context).getInt(KEY_MODE, AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
    }

    public static void setMode(Context context, int mode) {
        prefs(context).edit().putInt(KEY_MODE, mode).apply();
        AppCompatDelegate.setDefaultNightMode(mode);
    }

    /** Apply stored mode without rewriting prefs (call from Activity.onCreate). */
    public static void applyStored(Context context) {
        AppCompatDelegate.setDefaultNightMode(getMode(context));
    }

    /**
     * Cycle: System → Dark → Light → System …
     * @return human label for toast / UI
     */
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

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }
}

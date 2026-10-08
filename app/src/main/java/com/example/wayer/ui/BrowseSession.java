package com.example.wayer.ui;

/**
 * B4/C1 of docs/TRANSFER_CLEANER_PLAN.md: where browsing left off.
 *
 * Plain static holders — they survive rotation and tab-hopping (same
 * process) and die with the process, which is exactly "reset only on full
 * close" with zero persistence code. Never persisted, never parcelled.
 */
public final class BrowseSession {

    /** Last folder open in the Transfer browse tab (null = not visited yet). */
    public static String transferBrowsePath = null;

    /** Last folder open in the Files tab (null = not visited yet). */
    public static String filesCurrentPath = null;

    private BrowseSession() {}
}

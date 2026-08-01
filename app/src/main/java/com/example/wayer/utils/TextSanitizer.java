// File path: com/example/wayer/utils/TextSanitizer.java
package com.example.wayer.utils;

/**
 * Pure formatting utilities that don't depend on Android or complex IO.
 */
public class TextSanitizer {

    /**
     * Converts "source name index.txt" to "source_name_index.txt"
     */
    public static String replaceSpacesWithUnderscores(String input) {
        if (input == null) return "";
        return input.trim().replaceAll("\\s+", "_");
    }
}
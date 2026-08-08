package com.example.wayer.utils;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class TextSanitizerTest {

    @Test
    public void replacesSpacesWithUnderscores() {
        assertEquals("hello_world.txt",
                TextSanitizer.replaceSpacesWithUnderscores("hello world.txt"));
    }

    @Test
    public void collapsesMultipleSpaces() {
        assertEquals("a_b_c",
                TextSanitizer.replaceSpacesWithUnderscores("a   b  c"));
    }

    @Test
    public void nullBecomesEmpty() {
        assertEquals("", TextSanitizer.replaceSpacesWithUnderscores(null));
    }

    @Test
    public void trimsEdges() {
        assertEquals("name",
                TextSanitizer.replaceSpacesWithUnderscores("  name  "));
    }
}

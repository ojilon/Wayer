package com.example.wayer.network;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

/**
 * JVM unit tests for the transfer protocol tokens.
 * Run: ./gradlew :app:testDebugUnitTest
 */
public class NetworkManagerTest {

    @Test
    public void uploadCommandHasNoSpaces() {
        assertEquals("/upload 10 file_name\n", NetworkManager.uploadCommand(10, "file name"));
    }

    @Test
    public void uploadCommandKeepsCleanNames() {
        assertEquals("/upload 7 report.pdf\n", NetworkManager.uploadCommand(7, "report.pdf"));
    }

    @Test
    public void uploadCommandCollapsesWhitespace() {
        assertEquals("/upload 3 a_b_c\n", NetworkManager.uploadCommand(3, "a  b\tc"));
    }

    @Test
    public void uploadCommandIsNewlineTerminated() {
        String cmd = NetworkManager.uploadCommand(5, "a.txt");
        assertEquals('\n', cmd.charAt(cmd.length() - 1));
    }
}

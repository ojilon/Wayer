package com.example.wayer.network;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

/**
 * Loopback regression tests for the PC wire protocol (plain JUnit +
 * ServerSocket, no Android framework).
 * Run: ./gradlew :app:testDebugUnitTest
 */
public class NetworkManagerLoopbackTest {

    @Rule
    public TemporaryFolder tmp = new TemporaryFolder();

    static final class CapturingCallback implements NetworkCallback {
        final List<String> console = new ArrayList<>();
        final List<String> completions = new ArrayList<>();

        @Override
        public void onConsoleUpdate(String outputText) {
            console.add(outputText);
        }

        @Override
        public void onOperationComplete(String finalResult) {
            completions.add(finalResult);
        }

        String lastCompletion() {
            assertEquals("expected exactly one completion, got: " + completions, 1, completions.size());
            return completions.get(0);
        }
    }

    private static Method downloadMethod() throws Exception {
        Method m = NetworkManager.class.getDeclaredMethod("downloadFromPc",
                String.class, File.class, DataOutputStream.class, DataInputStream.class, NetworkCallback.class);
        m.setAccessible(true);
        return m;
    }

    private static Method uploadMethod() throws Exception {
        Method m = NetworkManager.class.getDeclaredMethod("uploadToPc",
                String.class, File.class, DataOutputStream.class, DataInputStream.class, NetworkCallback.class);
        m.setAccessible(true);
        return m;
    }

    private static void invoke(Method m, Object... args) throws Exception {
        try {
            m.invoke(null, args);
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof Exception) throw (Exception) cause;
            throw new RuntimeException(cause);
        }
    }

    /** Byte-at-a-time line reader for the stub server side. */
    private static String stubReadLine(InputStream in) throws Exception {
        StringBuilder sb = new StringBuilder();
        while (true) {
            int b = in.read();
            if (b == -1 || b == '\n') break;
            if (b != '\r') sb.append((char) b);
        }
        return sb.toString();
    }

    private static void daemon(Thread t) {
        t.setDaemon(true);
        t.start();
    }

    @Test
    public void readLineStopsAtNewlineAndStripsCarriageReturn() throws Exception {
        byte[] payload = "FOUND 5\r\nHELLO".getBytes(StandardCharsets.UTF_8);
        DataInputStream in = new DataInputStream(new ByteArrayInputStream(payload));
        assertEquals("FOUND 5", NetworkManager.readLine(in, 64 * 1024));
    }

    @Test
    public void coalescedFoundHeaderAndBodyDownloadByteExact() throws Exception {
        final byte[] fileBytes = "HELLO".getBytes(StandardCharsets.UTF_8);
        final byte[] burst = "FOUND 5\nHELLO".getBytes(StandardCharsets.UTF_8);
        final String[] requestLine = new String[1];

        try (ServerSocket server = new ServerSocket(0)) {
            server.setSoTimeout(15_000);
            daemon(new Thread(() -> {
                try (Socket s = server.accept()) {
                    s.setSoTimeout(15_000);
                    requestLine[0] = stubReadLine(s.getInputStream());
                    // Single write: header + body coalesced in one TCP burst.
                    s.getOutputStream().write(burst);
                    s.getOutputStream().flush();
                    Thread.sleep(1_000);
                } catch (Exception ignored) {
                }
            }));

            File workDir = tmp.newFolder("dl-coalesced");
            CapturingCallback cb = new CapturingCallback();
            try (Socket socket = new Socket("127.0.0.1", server.getLocalPort())) {
                socket.setSoTimeout(10_000);
                invoke(downloadMethod(), "hello.txt", workDir,
                        new DataOutputStream(socket.getOutputStream()),
                        new DataInputStream(socket.getInputStream()), cb);
            }

            assertTrue("request must be newline-terminated, got: " + requestLine[0],
                    requestLine[0] != null && requestLine[0].equals("/ask hello.txt"));
            assertArrayEquals(fileBytes, Files.readAllBytes(new File(workDir, "hello.txt").toPath()));
            assertTrue("unexpected completion: " + cb.completions, cb.lastCompletion().startsWith("Success: Saved "));
        }
    }

    @Test
    public void matchesReplyListsRelatedNames() throws Exception {
        try (ServerSocket server = new ServerSocket(0)) {
            server.setSoTimeout(15_000);
            daemon(new Thread(() -> {
                try (Socket s = server.accept()) {
                    s.setSoTimeout(15_000);
                    stubReadLine(s.getInputStream());
                    byte[] reply = "MATCHES 2\nreport.pdf\nreport_final.pdf\n".getBytes(StandardCharsets.UTF_8);
                    s.getOutputStream().write(reply);
                    s.getOutputStream().flush();
                    Thread.sleep(1_000);
                } catch (Exception ignored) {
                }
            }));

            File workDir = tmp.newFolder("dl-matches");
            CapturingCallback cb = new CapturingCallback();
            try (Socket socket = new Socket("127.0.0.1", server.getLocalPort())) {
                socket.setSoTimeout(10_000);
                invoke(downloadMethod(), "vague", workDir,
                        new DataOutputStream(socket.getOutputStream()),
                        new DataInputStream(socket.getInputStream()), cb);
            }

            String msg = cb.lastCompletion();
            assertTrue("missing first name in: " + msg, msg.contains("report.pdf"));
            assertTrue("missing second name in: " + msg, msg.contains("report_final.pdf"));
        }
    }

    @Test
    public void uploadHandshakeWithBareReadyAndDoneConfirmation() throws Exception {
        File workDir = tmp.newFolder("ul");
        File local = new File(workDir, "my file.txt");
        byte[] payload = "PAYLOAD-123".getBytes(StandardCharsets.UTF_8);
        Files.write(local.toPath(), payload);

        final String[] headerLine = new String[1];
        final byte[] received = new byte[payload.length];
        final int[] receivedCount = new int[1];

        try (ServerSocket server = new ServerSocket(0)) {
            server.setSoTimeout(15_000);
            daemon(new Thread(() -> {
                try (Socket s = server.accept()) {
                    s.setSoTimeout(15_000);
                    headerLine[0] = stubReadLine(s.getInputStream());
                    long size = Long.parseLong(headerLine[0].split(" ")[1]);
                    // Bare READY token, NO trailing newline.
                    s.getOutputStream().write("READY".getBytes(StandardCharsets.UTF_8));
                    s.getOutputStream().flush();
                    InputStream in = s.getInputStream();
                    int total = 0;
                    while (total < size) {
                        int r = in.read(received, total, (int) (size - total));
                        if (r == -1) break;
                        total += r;
                    }
                    receivedCount[0] = total;
                    s.getOutputStream().write("DONE\n".getBytes(StandardCharsets.UTF_8));
                    s.getOutputStream().flush();
                    Thread.sleep(500);
                } catch (Exception ignored) {
                }
            }));

            CapturingCallback cb = new CapturingCallback();
            try (Socket socket = new Socket("127.0.0.1", server.getLocalPort())) {
                socket.setSoTimeout(10_000);
                invoke(uploadMethod(), local.getAbsolutePath(), workDir,
                        new DataOutputStream(socket.getOutputStream()),
                        new DataInputStream(socket.getInputStream()), cb);
            }

            // Give the stub a moment to finish reading before asserting.
            for (int i = 0; i < 50 && receivedCount[0] == 0; i++) Thread.sleep(100);

            assertEquals("/upload 11 my_file.txt", headerLine[0]);
            assertTrue("advertised filename must be space-sanitized, got: " + headerLine[0],
                    !headerLine[0].split(" ")[2].contains(" "));
            assertEquals(payload.length, receivedCount[0]);
            assertArrayEquals(payload, received);
            String msg = cb.lastCompletion();
            assertTrue("expected DONE/confirmed success, got: " + msg,
                    msg.contains("confirmed") && msg.contains("my_file.txt"));
        }
    }

    @Test
    public void silentServerSurfacesAsTimeoutInsteadOfHanging() throws Exception {
        try (ServerSocket server = new ServerSocket(0)) {
            server.setSoTimeout(15_000);
            daemon(new Thread(() -> {
                try (Socket s = server.accept()) {
                    // Accept but never reply.
                    Thread.sleep(8_000);
                } catch (Exception ignored) {
                }
            }));

            File workDir = tmp.newFolder("dl-timeout");
            CapturingCallback cb = new CapturingCallback();
            long startMs = System.currentTimeMillis();
            try (Socket socket = new Socket("127.0.0.1", server.getLocalPort())) {
                socket.setSoTimeout(2_000);
                invoke(downloadMethod(), "ghost.bin", workDir,
                        new DataOutputStream(socket.getOutputStream()),
                        new DataInputStream(socket.getInputStream()), cb);
                fail("expected a SocketTimeoutException, got completions: " + cb.completions);
            } catch (java.net.SocketTimeoutException expected) {
                // Bounded wait: the read is subject to SoTimeout instead of hanging forever.
            }
            long elapsedMs = System.currentTimeMillis() - startMs;
            assertTrue("client blocked far too long: " + elapsedMs + "ms", elapsedMs < 15_000);
        }
    }
}

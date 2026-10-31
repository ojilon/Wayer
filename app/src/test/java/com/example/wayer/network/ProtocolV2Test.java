package com.example.wayer.network;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.concurrent.FutureTask;

import static org.junit.Assert.*;

public class ProtocolV2Test {
    @Test public void framingCountsUtf8BytesAndHandlesFragmentation() throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ProtocolV2.writeFrame(out, new JSONObject().put("t", "query").put("q", "café"));
        InputStream oneByte = new ByteArrayInputStream(out.toByteArray()) {
            @Override public synchronized int read(byte[] b, int off, int len) {
                return super.read(b, off, Math.min(1, len));
            }
        };
        assertEquals("café", ProtocolV2.readFrame(oneByte).getString("q"));
    }

    @Test public void rejectsInvalidFrameLengthsAndUnsafeNames() throws Exception {
        for (String frame : new String[]{"@0\n", "@01\n{}", "@4194305\n", "@-1\n", "@2\n{"}) {
            try { ProtocolV2.readFrame(new ByteArrayInputStream(frame.getBytes(StandardCharsets.UTF_8))); fail(frame); }
            catch (java.io.IOException expected) { }
        }
        for (String name : new String[]{"../a", "CON.txt", ".hidden", "a:b", "a."}) {
            try { ProtocolV2.safeName(name); fail(name); } catch (java.io.IOException expected) { }
        }
        assertEquals("report.pdf", ProtocolV2.safeName("folder/report.pdf"));
    }

    @Test public void queryPickInlineAndCollision() throws Exception {
        File dir = Files.createTempDirectory("v2test").toFile();
        Files.write(new File(dir, "a.txt").toPath(), new byte[]{42});
        try (ServerSocket server = new ServerSocket(0)) {
            FutureTask<Void> pc = new FutureTask<>(() -> {
                try (Socket socket = server.accept()) {
                    socket.setSoTimeout(5000);
                    InputStream in = socket.getInputStream();
                    assertEquals("hello", ProtocolV2.readFrame(in).getString("t"));
                    ProtocolV2.writeFrame(socket.getOutputStream(), new JSONObject().put("t", "hello_ok").put("proto", 2));
                    JSONObject query = ProtocolV2.readFrame(in);
                    String id = query.getString("id");
                    ProtocolV2.writeFrame(socket.getOutputStream(), new JSONObject().put("t", "matches").put("id", id)
                            .put("items", new JSONArray().put(new JSONObject().put("n", 1).put("name", "a.txt"))));
                    JSONObject pick = ProtocolV2.readFrame(in);
                    assertEquals(1, pick.getInt("n"));
                    ProtocolV2.writeFrame(socket.getOutputStream(), new JSONObject().put("t", "file").put("id", id)
                            .put("name", "a.txt").put("size", 3));
                    socket.getOutputStream().write(new byte[]{1, 2, 3});
                    JSONObject done = ProtocolV2.readFrame(in);
                    assertEquals("done", done.getString("t"));
                    assertEquals(3, done.getInt("bytes"));
                }
                return null;
            });
            new Thread(pc).start();
            File result = ProtocolV2.download("127.0.0.1", server.getLocalPort(), "phone", "did", "a", dir,
                    new ProtocolV2.Listener() {
                        public void linked(String pc) { }
                        public int choose(JSONArray items) { return 1; }
                        public void progress(long bytes, long total) { }
                    });
            pc.get();
            assertEquals("a (1).txt", result.getName());
            assertArrayEquals(new byte[]{1, 2, 3}, Files.readAllBytes(result.toPath()));
            assertArrayEquals(new byte[]{42}, Files.readAllBytes(new File(dir, "a.txt").toPath()));
        } finally {
            for (File f : dir.listFiles()) f.delete();
            dir.delete();
        }
    }
}

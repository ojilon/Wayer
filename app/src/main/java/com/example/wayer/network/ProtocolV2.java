package com.example.wayer.network;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.EOFException;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/** Isolated, synchronous v2 download session. Call from a worker thread. */
public final class ProtocolV2 {
    private static final int MAX_FRAME = 4 * 1024 * 1024;
    private static final long MAX_FILE = 2L * 1024 * 1024 * 1024;

    public interface Listener {
        void linked(String pc);
        /** Return the selected item number, or -1 to abort. */
        int choose(JSONArray items) throws Exception;
        void progress(long bytes, long total);
    }

    /** Only handshake failures are eligible for v1 fallback. */
    public static final class HandshakeException extends IOException {
        public HandshakeException(Throwable cause) { super(cause); }
    }

    public static final class RemoteException extends IOException {
        public final String code;
        RemoteException(JSONObject message) {
            super(message.optString("msg", message.optString("code", "Unknown error")));
            code = message.optString("code", "internal");
        }
    }

    private ProtocolV2() {}

    public static File download(String host, int port, String device, String did,
                                String query, File dir, Listener listener) throws Exception {
        try (Socket socket = new Socket()) {
            InputStream in;
            OutputStream out;
            JSONObject hello;
            try {
                socket.connect(new InetSocketAddress(host, port), 3000);
                socket.setSoTimeout(5000);
                in = socket.getInputStream();
                out = socket.getOutputStream();
                writeFrame(out, new JSONObject().put("t", "hello").put("proto", 2)
                        .put("role", "control").put("device", device).put("did", did));
                hello = readFrame(in);
                if (!"hello_ok".equals(hello.optString("t")) || hello.optInt("proto") != 2)
                    throw new IOException("v2 hello refused");
            } catch (Exception e) {
                throw new HandshakeException(e);
            }
            socket.setSoTimeout(65000);
            listener.linked(hello.optString("pc", "PC"));
            int ping = Math.max(1, Math.min(hello.optInt("ping", 20), 20));
            ScheduledExecutorService keepalive = Executors.newSingleThreadScheduledExecutor();
            keepalive.scheduleAtFixedRate(() -> {
                try { writeFrame(out, new JSONObject().put("t", "ping")); }
                catch (Exception ignored) { try { socket.close(); } catch (IOException ignored2) {} }
            }, ping, ping, TimeUnit.SECONDS);
            try {
                String id = UUID.randomUUID().toString();
                writeFrame(out, new JSONObject().put("t", "query").put("id", id)
                        .put("q", query).put("max", 50));
                while (true) {
                    JSONObject msg = readFrame(in);
                    String type = msg.optString("t");
                    if ("ping".equals(type)) { writeFrame(out, new JSONObject().put("t", "pong")); continue; }
                    if ("pong".equals(type)) continue;
                    if (!id.equals(msg.optString("id"))) {
                        // PC-originated requests are not supported by this download-only session.
                        if (!msg.optString("id").isEmpty()) writeFrame(out, new JSONObject()
                                .put("t", "error").put("id", msg.optString("id"))
                                .put("code", "unsupported").put("msg", "Download-only client"));
                        continue;
                    }
                    if ("error".equals(type)) throw new RemoteException(msg);
                    if ("matches".equals(type)) {
                        JSONArray items = msg.getJSONArray("items");
                        if (items.length() == 0 || items.length() > 50) throw new IOException("Invalid matches");
                        int n = listener.choose(items);
                        if (n < 0) {
                            writeFrame(out, new JSONObject().put("t", "abort").put("id", id));
                            throw new IOException("Selection cancelled");
                        }
                        writeFrame(out, new JSONObject().put("t", "pick").put("id", id).put("n", n));
                    } else if ("file".equals(type)) {
                        return receive(in, out, msg, dir, listener);
                    }
                }
            } finally {
                keepalive.shutdownNow();
            }
        }
    }

    private static File receive(InputStream in, OutputStream out, JSONObject msg, File dir,
                                Listener listener) throws Exception {
        String name = safeName(msg.getString("name"));
        long size = msg.getLong("size");
        if (size < 0 || size > MAX_FILE) throw new IOException("Invalid file size");
        if (!dir.isDirectory() && !dir.mkdirs()) throw new IOException("Cannot create download folder");
        File temp = File.createTempFile(".wayer-", ".part", dir);
        boolean complete = false;
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (FileOutputStream file = new FileOutputStream(temp)) {
                byte[] buf = new byte[65536];
                long received = 0;
                while (received < size) {
                    int n = in.read(buf, 0, (int) Math.min(buf.length, size - received));
                    if (n < 0) throw new EOFException("Incomplete file");
                    file.write(buf, 0, n);
                    digest.update(buf, 0, n);
                    received += n;
                    listener.progress(received, size);
                }
            }
            StringBuilder hash = new StringBuilder();
            for (byte b : digest.digest()) hash.append(String.format(Locale.ROOT, "%02x", b & 255));
            String expected = msg.optString("sha256", "");
            if (!expected.isEmpty() && !expected.equalsIgnoreCase(hash.toString())) {
                writeFrame(out, new JSONObject().put("t", "error").put("id", msg.getString("id"))
                        .put("code", "hash_mismatch").put("msg", "File checksum mismatch"));
                throw new IOException("File checksum mismatch");
            }
            // Reserve a unique name without overwriting any existing download.
            File target = new File(dir, name);
            int suffix = 0;
            while (!target.createNewFile()) {
                int dot = name.lastIndexOf('.');
                String base = dot > 0 ? name.substring(0, dot) : name;
                String ext = dot > 0 ? name.substring(dot) : "";
                target = new File(dir, base + " (" + (++suffix) + ")" + ext);
            }
            if (!temp.renameTo(target)) { target.delete(); throw new IOException("Cannot save download"); }
            complete = true;
            writeFrame(out, new JSONObject().put("t", "done").put("id", msg.getString("id"))
                    .put("bytes", size).put("sha256", hash.toString()));
            return target;
        } finally {
            if (!complete) temp.delete();
        }
    }

    static String safeName(String name) throws IOException {
        if (name.contains("..")) throw new IOException("Unsafe file name");
        for (int i = 0; i < name.length(); i++) if (name.charAt(i) < 32 || name.charAt(i) == 127)
            throw new IOException("Unsafe file name");
        name = name.substring(Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\')) + 1).trim();
        if (name.isEmpty() || name.startsWith(".") || name.endsWith(".") ||
                name.getBytes(StandardCharsets.UTF_8).length > 200 ||
                name.matches(".*[<>:\"|?*].*") ||
                name.matches("(?i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\\..*)?$"))
            throw new IOException("Unsafe file name");
        return name;
    }

    static synchronized void writeFrame(OutputStream out, JSONObject obj) throws IOException {
        byte[] bytes = obj.toString().getBytes(StandardCharsets.UTF_8);
        if (bytes.length == 0 || bytes.length > MAX_FRAME) throw new IOException("Invalid frame length");
        out.write(("@" + bytes.length + "\n").getBytes(StandardCharsets.US_ASCII));
        out.write(bytes);
        out.flush();
    }

    static JSONObject readFrame(InputStream in) throws IOException, JSONException {
        if (in.read() != '@') throw new IOException("Invalid frame marker");
        int len = 0, digits = 0, c;
        while ((c = in.read()) != '\n') {
            if (c < '0' || c > '9' || ++digits > 7 || (digits == 1 && c == '0'))
                throw new IOException("Invalid frame length");
            len = len * 10 + c - '0';
            if (len > MAX_FRAME) throw new IOException("Frame too large");
        }
        if (digits == 0 || len == 0) throw new IOException("Invalid frame length");
        byte[] bytes = new byte[len];
        int pos = 0;
        while (pos < len) {
            int n = in.read(bytes, pos, len - pos);
            if (n < 0) throw new EOFException("Incomplete frame");
            pos += n;
        }
        JSONObject obj = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
        if (!(obj.opt("t") instanceof String)) throw new IOException("Missing message type");
        return obj;
    }
}

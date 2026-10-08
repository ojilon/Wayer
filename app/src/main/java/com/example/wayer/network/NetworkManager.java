package com.example.wayer.network;

import com.example.wayer.core.Config;
import com.example.wayer.utils.TextSanitizer;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.util.ArrayList;
import java.util.List;

/**
 * Hotspot file protocol with WayerPC (Java sockets only).
 *
 * Commands (always terminated with '\n'):
 *   /ask <filename>   — ask PC for file, then pull bytes into workingDir
 *   /upload <filename> — push local file (from workingDir by name, or absolute path) to PC
 *
 * Replies:
 *   FOUND <size>\n + <size> raw bytes | MATCHES <n>\n + names | bare READY |
 *   DONE\n | ERROR <code>\n
 *
 * Callbacks are invoked from a background thread; UI must post to main thread.
 */
public class NetworkManager {

    static final int CONNECT_TIMEOUT_MS = 10_000;
    static final int READ_TIMEOUT_MS = 30_000;
    private static final int MAX_LINE_LEN = 64 * 1024;
    private static final int MAX_MATCH_NAMES = 64;

    public static void processProtocolCommand(final String rawInput, final File workingDir, final NetworkCallback callback) {

        new Thread(() -> {
            String[] parts = rawInput.split(" ", 2);
            String protocolCommand = parts[0];
            String filename = parts.length > 1 ? parts[1].trim() : "";

            if (filename.isEmpty()) {
                callback.onOperationComplete("Protocol Error: Target filename required.");
                return;
            }

            try (Socket socket = new Socket()) {
                socket.connect(new InetSocketAddress(Config.HOST, Config.PORT), CONNECT_TIMEOUT_MS);
                socket.setSoTimeout(READ_TIMEOUT_MS);
                DataOutputStream out = new DataOutputStream(socket.getOutputStream());
                DataInputStream in = new DataInputStream(socket.getInputStream());

                callback.onConsoleUpdate("Connecting to " + Config.HOST + ":" + Config.PORT + "…");

                if (protocolCommand.equalsIgnoreCase("/ask")) {
                    downloadFromPc(filename, workingDir, out, in, callback);
                } else if (protocolCommand.equalsIgnoreCase("/upload")) {
                    // filename may be a bare name (look in workingDir) or an absolute path
                    uploadToPc(filename, workingDir, out, in, callback);
                } else {
                    callback.onOperationComplete("Unknown command: " + protocolCommand);
                }

            } catch (SocketTimeoutException e) {
                callback.onOperationComplete("Timed out waiting for PC (check hotspot & retry).");
            } catch (Exception e) {
                callback.onOperationComplete("Connection Failure: " + e.getMessage());
            }
        }).start();
    }

    /**
     * Reads one '\n'-terminated line from the raw stream, byte-at-a-time.
     * Never wrap the stream in a BufferedReader here: its buffer would swallow
     * file bytes that arrive coalesced with the header in the same TCP burst.
     */
    static String readLine(DataInputStream in, int maxLen) throws IOException {
        StringBuilder sb = new StringBuilder();
        while (sb.length() < maxLen) {
            int b = in.read();            // -1 on EOF
            if (b == -1) break;
            if (b == '\n') break;
            if (b != '\r') sb.append((char) b);
        }
        return sb.toString();
    }

    private static void downloadFromPc(
            String filename,
            File workingDir,
            DataOutputStream out,
            DataInputStream in,
            NetworkCallback callback) throws Exception {

        out.write(("/ask " + filename + "\n").getBytes());
        out.flush();

        String responseHeader = readLine(in, MAX_LINE_LEN);
        if (responseHeader.isEmpty()) {
            callback.onOperationComplete("Server closed channel unexpectedly.");
            return;
        }

        if (responseHeader.startsWith("FOUND")) {
            final long fileSize;
            try {
                fileSize = Long.parseLong(responseHeader.split(" ")[1].trim());
                if (fileSize < 0) throw new NumberFormatException("negative size");
            } catch (Exception e) {
                callback.onOperationComplete("Bad FOUND header: " + responseHeader);
                return;
            }
            callback.onConsoleUpdate("File verified (" + fileSize + " bytes). Downloading…");

            if (workingDir != null && !workingDir.exists()) {
                //noinspection ResultOfMethodCallIgnored
                workingDir.mkdirs();
            }
            File outputFile = new File(workingDir, filename);
            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                long totalBytesRead = 0;
                byte[] fileBuffer = new byte[4096];
                while (totalBytesRead < fileSize) {
                    int count = in.read(fileBuffer, 0, (int) Math.min(fileBuffer.length, fileSize - totalBytesRead));
                    if (count == -1) break;
                    fos.write(fileBuffer, 0, count);
                    totalBytesRead += count;
                }
                fos.flush();
                if (totalBytesRead < fileSize) {
                    callback.onOperationComplete("Download incomplete (got " + totalBytesRead + "/" + fileSize + " bytes)");
                    return;
                }
            }
            callback.onOperationComplete("Success: Saved " + outputFile.getAbsolutePath()
                    + " (" + fileSize + " bytes)");
        } else if (responseHeader.startsWith("MATCHES")) {
            final int matchCount;
            try {
                matchCount = Integer.parseInt(responseHeader.split(" ")[1].trim());
            } catch (Exception e) {
                callback.onOperationComplete("Server Error: " + responseHeader);
                return;
            }
            int toRead = Math.min(Math.max(matchCount, 0), MAX_MATCH_NAMES);
            List<String> names = new ArrayList<>();
            for (int i = 0; i < toRead; i++) {
                String name = readLine(in, MAX_LINE_LEN);
                if (name.isEmpty()) break;
                names.add(name);
            }
            String listed = names.isEmpty() ? "(none)" : joinNames(names);
            callback.onOperationComplete("PC has " + names.size() + " related file(s): " + listed
                    + " — /ask one by exact name.");
        } else {
            callback.onOperationComplete("Server Error: " + responseHeader);
        }
    }

    private static String joinNames(List<String> names) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < names.size(); i++) {
            if (i > 0) sb.append(", ");
            sb.append(names.get(i));
        }
        return sb.toString();
    }

    private static void uploadToPc(
            String filenameOrPath,
            File workingDir,
            DataOutputStream out,
            DataInputStream in,
            NetworkCallback callback) throws Exception {

        File localFile = resolveLocalFile(filenameOrPath, workingDir);
        if (localFile == null || !localFile.exists() || localFile.isDirectory()) {
            callback.onOperationComplete("Local Error: File '" + filenameOrPath + "' not found.");
            return;
        }

        // The /upload command is space-separated, so the advertised name must
        // not contain spaces. Only this protocol token is sanitized — the
        // local file is never renamed.
        String baseName = TextSanitizer.replaceSpacesWithUnderscores(localFile.getName());
        long fileSize = localFile.length();
        out.write(uploadCommand(fileSize, baseName).getBytes());
        out.flush();

        // READY is a bare token with NO trailing newline — never wait for '\n'
        // here or we deadlock against the server, which waits for our bytes.
        // Loop until the 5 token bytes arrive to tolerate fragmentation.
        byte[] readyBuf = new byte[5];
        int readyTotal = 0;
        while (readyTotal < readyBuf.length) {
            int count = in.read(readyBuf, readyTotal, readyBuf.length - readyTotal);
            if (count == -1) break;
            readyTotal += count;
        }
        if (readyTotal <= 0) {
            callback.onOperationComplete("Server sent empty response");
            return;
        }
        String pcResponse = new String(readyBuf, 0, readyTotal).trim();

        if (pcResponse.equalsIgnoreCase("/send") || pcResponse.equalsIgnoreCase("READY")) {
            callback.onConsoleUpdate("Handshake OK. Uploading " + fileSize + " bytes…");
            try (FileInputStream fis = new FileInputStream(localFile)) {
                byte[] fileBuffer = new byte[4096];
                int count;
                while ((count = fis.read(fileBuffer)) != -1) {
                    out.write(fileBuffer, 0, count);
                }
                out.flush();
            }
            String confirmation = readLine(in, MAX_LINE_LEN);
            if (confirmation.trim().equalsIgnoreCase("DONE")) {
                callback.onOperationComplete("Success: Upload completed (" + fileSize + " bytes) · " + baseName + " · confirmed");
            } else {
                String reply = confirmation.isEmpty() ? "EOF" : confirmation;
                callback.onOperationComplete("Upload sent but PC did not confirm (reply: " + reply + ").");
            }
        } else {
            // Not READY: consume the rest of this '\n'-terminated line so the
            // full ERROR text is reported (first 5 bytes already consumed).
            String rest = readLine(in, MAX_LINE_LEN);
            callback.onOperationComplete("Remote declined upload: " + pcResponse + rest);
        }
    }

    /** Pure command builder (kept separate so unit tests cover the spacing rule). */
    static String uploadCommand(long fileSize, String baseName) {
        return "/upload " + fileSize + " " + TextSanitizer.replaceSpacesWithUnderscores(baseName) + "\n";
    }

    /** Prefer absolute path when provided; otherwise resolve under workingDir. */
    private static File resolveLocalFile(String filenameOrPath, File workingDir) {
        if (filenameOrPath == null || filenameOrPath.isEmpty()) return null;
        File asAbsolute = new File(filenameOrPath);
        if (asAbsolute.isAbsolute() && asAbsolute.exists()) {
            return asAbsolute;
        }
        if (workingDir != null) {
            return new File(workingDir, filenameOrPath);
        }
        return asAbsolute;
    }
}

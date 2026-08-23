package com.example.wayer.network;

import com.example.wayer.core.Config;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.net.Socket;

/**
 * Hotspot file protocol with WayerPC (Java sockets only).
 *
 * Commands:
 *   /ask <filename>   — ask PC for file, then pull bytes into workingDir
 *   /upload <filename> — push local file from workingDir to PC
 *
 * Callbacks are invoked from a background thread; UI must post to main thread.
 */
public class NetworkManager {

    public static void processProtocolCommand( final String rawInput, final File workingDir, final NetworkCallback callback) {

        new Thread(() -> {
            /*
            rawInput -> can be "/ask filename" or "/upload filename"
            parts -> ["/ask or /upload", "filename"]
            protocol command -> either '/ask' or '/upload'
            */
            String[] parts = rawInput.split(" ", 2);
            String protocolCommand = parts[0];
            String filename = parts.length > 1 ? parts[1].trim() : "";

            if (filename.isEmpty()) {
                callback.onOperationComplete("Protocol Error: Target filename required.");
                return;
            }

            try (Socket socket = new Socket(Config.HOST, Config.PORT);
                 DataOutputStream out = new DataOutputStream(socket.getOutputStream());
                 DataInputStream in = new DataInputStream(socket.getInputStream())) {

                callback.onConsoleUpdate("Connecting to " + Config.HOST + ":" + Config.PORT + "…");

                if (protocolCommand.equalsIgnoreCase("/ask")) {
                    downloadFromPc(filename, workingDir, out, in, callback);
                } else if (protocolCommand.equalsIgnoreCase("/upload")) {
                    uploadToPc(filename, workingDir, out, in, callback);
                } else {
                    callback.onOperationComplete("Unknown command: " + protocolCommand);
                }

            } catch (Exception e) {
                callback.onOperationComplete("Connection Failure: " + e.getMessage());
            }
        }).start();
    }

    private static void downloadFromPc(
            String filename,
            File workingDir,
            DataOutputStream out,
            DataInputStream in,
            NetworkCallback callback) throws Exception {

        out.write(("/ask " + filename).getBytes());
        out.flush();

        byte[] buffer = new byte[1024];
        int bytesRead = in.read(buffer);
        if (bytesRead == -1) {
            callback.onOperationComplete("Server closed channel unexpectedly.");
            return;
        }

        String responseHeader = new String(buffer, 0, bytesRead).trim();

        if (responseHeader.startsWith("FOUND")) {
            long fileSize = Long.parseLong(responseHeader.split(" ")[1]);
            callback.onConsoleUpdate("File verified (" + fileSize + " bytes). Downloading…");

            //out.write("/send".getBytes());
            out.flush();

            File outputFile = new File(workingDir, filename);
            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                long totalBytesRead = 0;
                int count;
                byte[] fileBuffer = new byte[4096];
                while (totalBytesRead < fileSize && (count = in.read(fileBuffer)) != -1) {
                    fos.write(fileBuffer, 0, count);
                    totalBytesRead += count;
                }
                fos.flush();
            }
            callback.onOperationComplete("Success: Saved " + outputFile.getName()
                    + " (" + fileSize + " bytes)");
        } else {
            callback.onOperationComplete("Server Error: " + responseHeader);
        }
    }

    private static void uploadToPc(
            String filename,
            File workingDir,
            DataOutputStream out,
            DataInputStream in,
            NetworkCallback callback) throws Exception {

        File localFile = new File(workingDir, filename);
        if (!localFile.exists() || localFile.isDirectory()) {
            callback.onOperationComplete("Local Error: File '" + filename + "' not found in app files dir.");
            return;
        }

        long fileSize = localFile.length();
        out.write(("/upload " + fileSize + " " + filename).getBytes());
        out.flush();

        byte[] buffer = new byte[1024];
        int bytesRead = in.read(buffer);
        if (bytesRead <= 0) {
            callback.onOperationComplete("Server sent empty response");
            return;
        }
        String pcResponse = new String(buffer, 0, bytesRead).trim();

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
            callback.onOperationComplete("Success: Upload completed (" + fileSize + " bytes)");
        } else {
            callback.onOperationComplete("Remote declined upload: " + pcResponse);
        }
    }
}

// File path: com/example/wayer/network/NetworkManager.java
package com.example.wayer.network;

import com.example.wayer.core.Config;
import java.io.*;
import java.net.Socket;

/**
 * Orchestrates modern socket network tasks out of the main thread.
 * Ready for clean replacement with custom standard C socket protocols later.
 */
public class NetworkManager {

    /**
     * Executes asynchronous background operations utilizing native Java standard threads.
     */
    public static void processProtocolCommand(final String rawInput, final File workingDir, final NetworkCallback callback) {
        
        // Spin up a dedicated worker thread so the UI fluid animation loop does not freeze
        new Thread(new Runnable() {
            @Override
            public void run() {
                String[] parts = rawInput.split(" ", 2);
                String protocolCommand = parts[0];
                String filename = parts.length > 1 ? parts[1] : "";

                if (filename.isEmpty()) {
                    callback.onOperationComplete("Protocol Error: Target filename required.");
                    return;
                }

                try (Socket socket = new Socket(Config.HOST, Config.PORT);
                     DataOutputStream out = new DataOutputStream(socket.getOutputStream());
                     DataInputStream in = new DataInputStream(socket.getInputStream())) {

                    callback.onConsoleUpdate("Connecting to server host " + Config.HOST + "...");

                    if (protocolCommand.equalsIgnoreCase("/ask")) {
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
                            callback.onConsoleUpdate("File Verified (" + fileSize + " bytes). Running download allocation...");

                            out.write("/send".getBytes());
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
                            callback.onOperationComplete("Success: Stream written to local file: " + outputFile.getName());

                        } else {
                            callback.onOperationComplete("Server Error: " + responseHeader);
                        }

                    } else if (protocolCommand.equalsIgnoreCase("/upload")) {
                        File localFile = new File(workingDir, filename);
                        if (!localFile.exists() || localFile.isDirectory()) {
                            callback.onOperationComplete("Local System Error: File '" + filename + "' not found here.");
                            return;
                        }

                        long fileSize = localFile.length();
                        out.write(("/upload " + fileSize + " " + filename).getBytes());
                        out.flush();

                        byte[] buffer = new byte[1024];
                        int bytesRead = in.read(buffer);
                        String pcResponse = new String(buffer, 0, bytesRead).trim();

                        if (pcResponse.equalsIgnoreCase("/send") || pcResponse.equalsIgnoreCase("READY")) {
                            callback.onConsoleUpdate("Handshake valid. Pushing binary payload to host...");
                            try (FileInputStream fis = new FileInputStream(localFile)) {
                                byte[] fileBuffer = new byte[4096];
                                int count;
                                while ((count = fis.read(fileBuffer)) != -1) {
                                    out.write(fileBuffer, 0, count);
                                }
                                out.flush();
                            }
                            callback.onOperationComplete("Success: Upload transaction completed.");
                        } else {
                            callback.onOperationComplete("Remote host declined the stream target setup. Responsse ->" + pcResponse);
                        }
                    }

                } catch (Exception e) {
                    callback.onOperationComplete("Connection Failure: " + e.getMessage());
                }
            }
        }).start(); // Trigger thread execution context
    }
}
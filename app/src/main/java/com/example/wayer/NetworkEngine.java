package com.example.wayer;

import android.os.AsyncTask;
import java.io.*;
import java.net.Socket;

public class NetworkEngine extends AsyncTask<String, String, String> {

    // Target gateway configuration matching your PC Hotspot IP allocation mapping
    //though not used now, left here for future study of code
    private static final String SERVER_IP = "192.168.43.41"; 
    private static final int SERVER_PORT = 5000;

    private OnNetworkResultListener listener;
    private File currentWorkingDirectory;

    public interface OnNetworkResultListener {
        void onUpdateConsole(String text);
    }

    public NetworkEngine(File currentDir, OnNetworkResultListener listener) {
        this.currentWorkingDirectory = currentDir;
        this.listener = listener;
    }

    @Override
    protected String doInBackground(String... params) {
        String rawInput = params[0];
        String[] parts = rawInput.split(" ", 2);
        String protocolCommand = parts[0]; 
        String filename = parts.length > 1 ? parts[1] : "";

        if (filename.isEmpty()) {
            return "Protocol Error: Target filename required.";
        }

        Socket socket = null;
        DataOutputStream out = null;
        DataInputStream in = null;

        try {
            publishProgress("Connecting to server host " + Config.HOST + "...");
            socket = new Socket(Config.HOST, Config.PORT);
            out = new DataOutputStream(socket.getOutputStream());
            in = new DataInputStream(socket.getInputStream());

            if (protocolCommand.equalsIgnoreCase("/ask")) {
                // Protocol Request Frame Out
                publishProgress("Sending packet: /ask " + filename);
                out.write(("/ask " + filename).getBytes());
                out.flush();

                // Read Network Stream Header Envelope
                byte[] buffer = new byte[1024];
                int bytesRead = in.read(buffer);
                if (bytesRead == -1) return "Server closed channel unexpectedly.";
                
                String responseHeader = new String(buffer, 0, bytesRead).trim();
                
                if (responseHeader.startsWith("FOUND")) {
                    String[] headerParts = responseHeader.split(" ");
                    long fileSize = Long.parseLong(headerParts[1]);
                    publishProgress("Server status: File Verified (" + fileSize + " bytes). Running download allocation...");

                    // Acknowledge payload readiness handshake
                    out.write("/send".getBytes());
                    out.flush();

                    // Read incoming binary block and commit to disk
                    File outputFile = new File(currentWorkingDirectory, filename);
                    FileOutputStream fos = new FileOutputStream(outputFile);
                    
                    long totalBytesRead = 0;
                    int count;
                    buffer = new byte[4096];
                    
                    while (totalBytesRead < fileSize && (count = in.read(buffer)) != -1) {
                        fos.write(buffer, 0, count);
                        totalBytesRead += count;
                    }
                    fos.flush();
                    fos.close();

                    return "Success: Stream written to local file: " + outputFile.getName();
                } else if (responseHeader.startsWith("ERROR")) {
                    return "Server Exception Notice: " + responseHeader;
                } else {
                    return "Protocol Break: Unexpected string: " + responseHeader;
                }

            } else if (protocolCommand.equalsIgnoreCase("/upload")) {
                // Local Storage To Remote Host Upload Routine
                File localFile = new File(currentWorkingDirectory, filename);
                if (!localFile.exists() || localFile.isDirectory()) {
                    return "Local System Error: File '" + filename + "' not found here.";
                }

                long fileSize = localFile.length();
                publishProgress("Broadcasting upload packet: FOUND " + fileSize + " bytes");
                out.write(("/upload " + fileSize + " " + filename).getBytes());
                out.flush();

                // Wait for destination handshake clearance confirmation command
                byte[] buffer = new byte[1024];
                int bytesRead = in.read(buffer);
                String pcResponse = new String(buffer, 0, bytesRead).trim();
                
                // If Python replies "READY", start pumping your binary loop data
                if (pcResponse.equalsIgnoreCase("/send") || pcResponse.equalsIgnoreCase("READY")) {
                    publishProgress("Handshake valid. Pushing binary payload to host...");
                    FileInputStream fis = new FileInputStream(localFile);
                    buffer = new byte[4096];
                    int count;
                    while ((count = fis.read(buffer)) != -1) {
                        out.write(buffer, 0, count);
                    }
                    out.flush();
                    fis.close();
                    return "Success: Upload transaction completed.";
                } else {
                    return "Remote host declined the stream target setup.";
                }
            }

        } catch (Exception e) {
            return "Connection Failure: " + e.getMessage();
        } finally {
            try {
                if (in != null) in.close();
                if (out != null) out.close();
                if (socket != null) socket.close();
            } catch (IOException ignored) {}
        }
        return "Transaction context completed.";
    }

    @Override
    protected void onProgressUpdate(String... values) {
        if (listener != null) {
            listener.onUpdateConsole(values[0]);
        }
    }

    @Override
    protected void onPostExecute(String result) {
        if (listener != null) {
            listener.onUpdateConsole(result + "\n");
        }
    }
}
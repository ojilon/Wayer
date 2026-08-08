package com.example.wayer.transfer;

public class NetworkStatus {
    private final String status;
    private final int port;

    public NetworkStatus(String status, int port) {
        this.status = status;
        this.port = port;
    }

    public String getStatus() { return status; }
    public int getPort() { return port; }
}
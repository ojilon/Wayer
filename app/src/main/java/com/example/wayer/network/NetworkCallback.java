// File path: com/example/wayer/network/NetworkCallback.java
package com.example.wayer.network;

/**
 * An interface (contract) letting background threads push live 
 * terminal logs out to the MainActivity without knowing MainActivity exists.
 */
public interface NetworkCallback {
    void onConsoleUpdate(String outputText);
    void onOperationComplete(String finalResult);
}
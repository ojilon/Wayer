package com.example.wayer.core;

public class NativeEngine {
    
    // Load the C++ shared library on startup
    static {
        System.loadLibrary("wayer_engine");
    }

    // Purely procedural JNI calls. We avoid passing complex objects.
    // Use primitives (ints, bytes) and Strings for flat data transfer.
    
    public static native void initEngine();
    
    // A single unified router function is often cleaner than dozens of tiny JNI methods
    public static native String processAction(int actionId, String payload);
}
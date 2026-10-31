// File path: com/example/wayer/core/Config.java
package com.example.wayer.core;

/**
 * App-wide global settings. Keep it centralized here so 
 * changing your server config doesn't require hunting through source code.
 */
public class Config {
    public static synchronized String deviceId(android.content.Context context) {
        android.content.SharedPreferences prefs = context.getApplicationContext()
                .getSharedPreferences("protocol", android.content.Context.MODE_PRIVATE);
        String id = prefs.getString("device_id", null);
        if (id == null || id.isEmpty()) {
            id = java.util.UUID.randomUUID().toString();
            if (!prefs.edit().putString("device_id", id).commit())
                throw new IllegalStateException("Cannot persist device ID");
        }
        return id;
    }
    // Put your PC's actual hotspot IP address here
    public static final String HOST = "192.168.43.41"; 
    public static final int PORT = 5000;
}
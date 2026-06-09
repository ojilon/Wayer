# Wayer - Android End

An Android app for transferring files with your PC through hotspot connection. Browse, download, and upload files.

## Prerequisites
- Android SDK (API 21+)
- Gradle build system
- A PC running the Wayer PC-end server
- Android sdk and ndk build tools

## Installation & Build

### 1. Clone the Repository

```bash
git checkout android-end
```

### 2. Open in Android Studio

```bash
# Navigate to the project root
cd Wayer
# Open in Android Studio or use gradle
```

### 3. Install Dependencies

Dependencies are declared in `app/build.gradle`. Gradle will automatically download them.

### 4. Build the APK

**Using Command Line**
```bash
./gradlew assembleDebug    # Debug APK
./gradlew assembleRelease  # Release APK (requires signing)
```

### 5. Locate the APK

Built APKs are located at:
```
app/build/outputs/apk/debug/app-debug.apk        (Debug)
app/build/outputs/apk/release/app-release.apk    (Release)
```

## Installation on Android Device

### Method 1: ADB (Android Debug Bridge)
```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Method 2: Manual Installation
1. Copy the APK to your device
2. Open a file manager
3. Tap the APK file to install

## Project Structure

```
android-end/
├── app/
│   ├── build.gradle          # App build configuration
│   ├── src/
│   │   └── main/
│   │       ├── AndroidManifest.xml    # App permissions and components
│   │       ├── java/                  # Source code
│   │       └── res/                   # Resources (layouts, strings, etc)
├── build.gradle              # Project build configuration
├── settings.gradle           # Gradle settings
├── gradle.properties         # Gradle properties
└── README.md
```

## Usage Guide

Connect your Android phone to your PC's hotspot, then open the Wayer app to start transferring files.

### Core Commands

The app supports three main operations:

#### 1. **Navigation - `ls` and `cd` Commands**

- **`ls`** - List files and folders in the current directory
  ```
  ls
  ```
  Shows available files/folders on the PC server

- **`cd <path>`** - Change directory
  ```
  cd Documents
  cd ..           # Go back one level
  ```
  Navigate through the file system hierarchy

#### 2. **Download Files - `/ask` Command**

Request a file from the PC server:
```
/ask <filename>
```

**Example:**
```
/ask document.pdf
/ask photo.jpg
```

- Enters the filename you want to download
- Server searches for the file in the shared folder
- File downloads to your Android device (typically in Downloads)
- Connection status is shown in the app

#### 3. **Upload Files - `/upload` Command**

Send a file from your phone to the PC:
```
/upload <filepath>
```

**Example:**
```
/upload /sdcard/Pictures/photo.jpg
/upload /sdcard/Documents/notes.txt
```

- Specifies the full path to the file on your phone
- File is sent to the PC's `received/` folder
- Upload progress is displayed
- Confirmation shown when complete

## Quick Workflow

1. **Open the app** - Connect to PC hotspot
2. **Explore files** - Use `ls` and `cd` to navigate
3. **Download** - Use `/ask <filename>` to get files from PC
4. **Upload** - Use `/upload <filepath>` to send files to PC
5. **Check status** - App displays connection status and transfer progress

## Features

✅ Browse PC file system from Android  
✅ Download files with `/ask` command  
✅ Upload files with `/upload` command  
✅ Directory navigation with `ls` and `cd`  
✅ Real-time transfer status  
✅ Hotspot-based connection (no internet required)  

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Build fails** | Run `./gradlew clean` then rebuild |
| **Can't connect to PC** | Verify both devices on same hotspot; check PC server is running |
| **File not found** | Ensure filename exists; check path is correct; use `ls` to verify |
| **Upload fails** | Verify file path is accessible; check Android permissions |
| **APK won't install** | Enable "Unknown Sources" in Android settings (may vary by device) |

## Build Output

After successful build:
- **Debug APK**: `app/build/outputs/apk/debug/app-debug.apk`
- **Release APK**: `app/build/outputs/apk/release/app-release.apk`

## Permissions

The app requires these Android permissions (see `AndroidManifest.xml`):
- Internet access
- File read/write access
- Storage permissions (varies by Android version)

## Notes

- Keep the PC server running for the app to function
- Both devices must be on the same hotspot network
- File transfers are optimized for WiFi hotspot speed
- Larger files may take longer depending on connection quality

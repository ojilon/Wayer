# Wayer - Android App

Android client for transferring files with your PC through hotspot connection.

**🔗 [← Back to Main](https://github.com/ojilon/Wayer/blob/main/README.md)** | **📖 [Detailed Setup Guide →](https://github.com/ojilon/Wayer/blob/android-end/README_ANDROID_END.md)**

## ⚡ Quick Start

```bash
# Build debug APK
./gradlew assembleDebug

# Find APK at:
# app/build/outputs/apk/debug/app-debug.apk
```

## 📂 Project Structure

```
android-end/
├── app/
│   ├── build.gradle         # App configuration
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml
│           ├── java/        # Source code
│           └── res/         # Resources
└── build.gradle             # Project config
```

## 🎮 Usage Commands

Once connected to PC hotspot and server is running:

| Command | Purpose |
|---------|----------|
| `ls` | List files/folders |
| `cd <path>` | Change directory |
| `/ask <filename>` | Download file |
| `/upload <filepath>` | Upload file |

**Example workflow:**
```
ls
cd Documents
/ask report.pdf
/upload /sdcard/Pictures/photo.jpg
```

## 📚 Full Documentation

For complete build instructions, installation, and usage:
👉 **[README_ANDROID_END.md](https://github.com/ojilon/Wayer/blob/android-end/README_ANDROID_END.md)**

## 🔗 Related Branch

- **PC Server**: [pc-end branch](https://github.com/ojilon/Wayer/tree/pc-end)

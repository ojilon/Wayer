# Wayer - Android App

Android client for transferring files with your PC through a hotspot connection. Provides a small CLI-like terminal UI to browse the PC file system, download files to the phone, and upload phone files to the PC.

**🔗 [← Back to Main](https://github.com/ojilon/Wayer/blob/main/README.md)** | **📖 [Detailed Setup & Command Reference →](https://github.com/ojilon/Wayer/blob/main/README_ANDROID_END.md)**

## ⚡ Quick Start

```bash
# Build debug APK
./gradlew assembleDebug

# Find APK at:
# app/build/outputs/apk/debug/app-debug.apk
```

## 📂 Project Structure (high level)

```
android-end/
├── app/
│   ├── build.gradle         # App-level build configurations and dependencies
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml   # Declares application components & permissions
│           ├── java/                    # App Java source (core, network, storage, utils)
│           └── res/                     # UI layouts and resources
└── build.gradle             # Project-level configuration definitions
```

## 🎮 Usage Commands (summary)

The app exposes a CLI-style terminal. Commands are split between local filesystem operations (run on the device) and protocol/network operations (sent to the PC server).

Local commands:

- `ls` — list files/folders in the current working directory on the phone
- `cd <path>` — change current working directory
- `cls` — clear terminal output
- `stz <filename>` — sanitize and rename a file (convert spaces/unsafe characters)
- `find <keyword>` — search for filenames containing the keyword under current directory
- `refresh` — refresh internal file path cache (may take time on first run)
- `jump <folder>` — jump directly to a named folder within the current hierarchy (shortcut)
- `findfile <filename>` — global search for a specific filename
- `choose <number>` — pick an item from the last search/list output
- `mkdir <folder>` — create a folder in the current directory
- `setdownloadpath <folder>` — set custom download target in local storage
- `sanitizepath` — sanitize names inside the current working folder

Network/protocol commands (require the PC server to be running and both devices on the same hotspot):

- `/ask <filename>` — request a file from the PC server; server responds and the file is streamed to the phone
- `/upload <filepath>` — send a local phone file to the PC server

Example session:

```
ls
cd Documents
/ask report.pdf
/upload Pictures/photo.jpg
```

## 📚 Full Documentation

For detailed build instructions, installation steps, and a complete command reference, see README_ANDROID_END.md in this repository.

## 🔗 Related Branch

- **PC Server**: [pc-end branch](https://github.com/ojilon/Wayer/tree/pc-end)

# Wayer - Android End

An Android app that connects to the Wayer PC server over a Wi‑Fi hotspot. The app exposes a small CLI-style terminal to browse the PC file tree, request downloads, and upload local files to the PC.

## Prerequisites
- Android SDK (API 21+)
- Gradle (wrapper included)
- A PC running the Wayer PC-end server (see pc-end branch)
- For optional native work: Android NDK and native build tools

## Quick start / Build
From the repository root:

```bash
# switch to the branch you want (optional)
git checkout main

# Build debug APK
./gradlew assembleDebug

# Debug APK path
app/build/outputs/apk/debug/app-debug.apk
```

Install with ADB:

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Project layout (high level)

```
android-end/
├── app/                  # Android Studio project
│   ├── build.gradle
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/example/wayer/
│       │   ├── core/         # MainActivity, Config, etc.
│       │   ├── network/      # NetworkManager, NetworkCallback
│       │   ├── storage/      # FileNavigator, FileMutator, FileSearcher
│       │   └── utils/        # Text utilities
│       └── res/             # layouts, strings, drawables
└── build.gradle
```

## How the app works
- Local commands operate on the Android device filesystem (using the terminal UI).
- Protocol/network commands (start with a slash, e.g. `/ask`) are sent to the PC server. The PC server must be running and both devices must be on the same hotspot network.

## Commands

Local (device) commands:
- `ls` — list files and folders in the current working directory
- `cd <path>` — change working directory
- `cls` — clear terminal output
- `stz <filename>` — sanitize and rename a file (replace spaces/unsafe characters)
- `find <keyword>` — search for filenames containing the keyword under the current directory
- `findfile <filename>` — global search for a specific filename
- `refresh` — refresh internal file path cache (may be slow)
- `jump <folder>` — quick jump to a subfolder by name
- `choose <number>` — select an item from the last search/list output
- `mkdir <folder>` — create a directory in the current location
- `setdownloadpath <folder>` — set custom download folder on the device
- `sanitizepath` — run sanitization across names in the current directory

Network/protocol commands (require PC server):
- `/ask <filename>` — request a file from the PC server; if found, the server replies with a header (e.g. `FOUND <bytes>`), then the app initiates the download and streams the file to local storage
- `/upload <filepath>` — upload a local file to the PC server; the app sends an upload header with size, the server replies with a handshake (`/send` or `READY`) and the binary payload is streamed

Example session:

```
ls
cd Documents
/ask report.pdf
/upload Pictures/photo.jpg
```

Protocol notes
- The app expects the PC server to follow a simple text-header + streaming protocol:
  - For `/ask`: client sends `/ask <filename>`, server responds `FOUND <size>` or an error. Client then sends `/send` and reads the byte stream until the advertised size is received.
  - For `/upload`: client sends `/upload <size> <filename>`, server responds with `/send` or `READY`. Client streams the file bytes afterwards.
- If the server closes the connection or responds with an error header, the app prints an informative message to the terminal.

## Permissions
(See AndroidManifest.xml)
- INTERNET — for socket connections to PC server
- STORAGE read/write (or scoped storage equivalents) — to access and save files on the device
  - On modern Android releases, runtime storage permissions and scoped storage rules apply — grant permissions or use the app’s configured download path.

## Troubleshooting
- Can't connect: make sure both phone and PC are on the same hotspot and the PC server is running.
- File not found: verify filename and use `ls` / `find` to inspect the server or local folders.
- Upload fails: confirm the local file path and that the app has storage permission to read the file.
- Build issues: run `./gradlew clean` then rebuild; open the project in Android Studio for configuration assistance.

## Build output
- Debug APK: `app/build/outputs/apk/debug/app-debug.apk`
- Release APK: `app/build/outputs/apk/release/app-release.apk` (requires signing config)

## Notes & next steps
- The app is intentionally minimal (CLI-style) for fast file transfers over a hotspot.
- The PC server implements the file-serving protocol — see the pc-end branch for the server implementation and exact protocol details.
- Future improvements: UI polish, resumable transfers, checksums, TLS, and an alternative discovery/handshake mechanism.

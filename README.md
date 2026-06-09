# 📱 Wayer - File Transfer System

Transfer files between your PC and Android phone through hotspot connection.

**Wayer** is a two-component project:
- 📱 **Android Client** - Browse and transfer files from your phone
- 💻 **PC Server** - Manage file transfers from your computer

---

## 🚀 Quick Navigation

### 📱 **Android Client** (This Repository)

Build and run the Android app to connect to your PC and transfer files.

```bash
# Build debug APK
./gradlew assembleDebug

# Find APK at: app/build/outputs/apk/debug/app-debug.apk
```

**📖 [→ Full Android Setup Guide](https://github.com/ojilon/Wayer/blob/main/README_ANDROID_END.md)**

---

### 💻 **PC Server** (Separate Repository)

Set up the Python server on your PC to handle file requests from the phone.

```bash
# Install dependencies
pip install -r requirements.txt

# Start the server
cd python
python server/app3.py
```

**📖 [→ Full PC Server Setup Guide](https://github.com/ojilon/WayerPC/blob/main/README_PC_END.md)**  
**🔗 [→ Go to WayerPC Repository](https://github.com/ojilon/WayerPC)**

---

## 🏗️ Project Architecture

```
Wayer (Complete File Transfer System)
├── ojilon/Wayer (This Repo)
│   ├── 📱 Android Application
│   ├── Language: Java (100%)
│   ├── Build: Gradle
│   └── Purpose: Client app for file browsing & transfer
│
└── ojilon/WayerPC (Separate Repo)
    ├── 💻 Python Server + C DLL
    ├── Languages: Python, C, C++, CMake
    ├── Purpose: File server for handling requests
    └── Role: Backend processing & file search
```

---

## 📋 System Requirements

### For Android Client
- Android SDK (API 26+)
- Gradle build system
- Android Studio (optional)

### For PC Server
- Python 3.x
- MinGW64 or GCC (for C DLL compilation)
- CMake 3.10+

---

## 🎮 How It Works

### Setup Flow

1. **Start PC Server**
   ```bash
   # On your PC, navigate to WayerPC repo
   cd python
   python server/app3.py
   # Server listens on <HOST>:<PORT>
   ```

2. **Connect Android Phone to PC Hotspot**
   - Enable hotspot on PC or use existing WiFi network

3. **Open Wayer App on Phone**
   - Connect to the same network as the PC

4. **Transfer Files**
   - Use commands: `ls`, `cd`, `/ask`, `/upload`

---

## 🔄 Workflow Example

```
Phone (Android App)         PC (Python Server)
        |                            |
        |------- ls ------→          | (List files)
        |←------ response -------|
        |
        |------- cd Documents --|
        |
        |------- /ask photo.jpg|    (Request file)
        |←------ photo.jpg -----|
        |
        |------- /upload file --→   (Send file)
        |        (received folder)
```

---

## 📚 Complete Guides

### 📱 Android Client Documentation
- **Location**: [README_ANDROID_END.md](https://github.com/ojilon/Wayer/blob/main/README_ANDROID_END.md)
- **Covers**: Installation, building APK, commands, troubleshooting

### 💻 PC Server Documentation
- **Location**: [README_PC_END.md](https://github.com/ojilon/WayerPC/blob/main/README_PC_END.md)
- **Covers**: Server setup, configuration, file operations, DLL compilation

---

## 🎯 Key Commands

| Command | Device | Purpose |
|---------|--------|---------|
| `ls` | Phone | List files/folders on PC |
| `cd <path>` | Phone | Navigate directories |
| `/ask <filename>` | Phone | Download file from PC |
| `/upload <filepath>` | Phone | Upload file to PC |

---

## 📂 Repository Structure

### ojilon/Wayer (Android Client)
```
Wayer/
├── app/
│   ├── build.gradle
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/          # Source code
│       └── res/           # Resources
├── build.gradle
├── gradle.properties
├── settings.gradle
├── README.md              # Main documentation
└── README_ANDROID_END.md  # Detailed guide
```

### ojilon/WayerPC (PC Server)
```
WayerPC/
├── python/
│   ├── server/
│   │   ├── app3.py        # Entry point
│   │   ├── socket_server3.py
│   │   ├── Locate.py
│   │   ├── transfer.py
│   │   └── config.py
│   └── Filesmanager/
├── c/                     # C DLL source
├── CMakeLists.txt
├── README.md              # Quick overview
└── README_PC_END.md       # Detailed guide
```

---

## 🔗 Links

- **Android Client Repo**: https://github.com/ojilon/Wayer
- **PC Server Repo**: https://github.com/ojilon/WayerPC
- **Android Guide**: [README_ANDROID_END.md](https://github.com/ojilon/Wayer/blob/main/README_ANDROID_END.md)
- **PC Server Guide**: [README_PC_END.md](https://github.com/ojilon/WayerPC/blob/main/README_PC_END.md)

---

## 🚨 Troubleshooting

### Connection Issues
- Verify both devices are on the same network
- Check PC server is running and listening
- Confirm firewall is not blocking connections

### File Transfer Errors
- Use `ls` command to verify file exists
- Check file paths are correct
- Ensure Android app has file permissions

### Build Issues
- Android: `./gradlew clean` then rebuild
- PC Server: Verify Python 3.x and dependencies installed

---

## 📝 License

MIT License - See LICENSE file in each repository

---

**Get started**: [Android Setup Guide →](https://github.com/ojilon/Wayer/blob/main/README_ANDROID_END.md) | [PC Server Guide →](https://github.com/ojilon/WayerPC/blob/main/README_PC_END.md)

# Wayer

Project for transfer of files between PC and Android phone, through hotspot connection.

## 📱 Project Overview

Wayer is a file transfer application that enables seamless file sharing between your PC and Android phone using a WiFi hotspot connection. No internet required—just connect both devices to a hotspot and start transferring!

## 🏗️ Project Structure

This repository contains two independent implementations:

### **PC-End Branch** (`pc-end`)
A Python-based server that runs on your Windows PC to handle file requests from your Android phone.

- **Primary File**: `python/server/app3.py`
- **Technology**: Python with socket server, C DLL for file search
- **Purpose**: Server-side file management and transfers
- **Quick Start**: 
  ```bash
  cd python
  python server/app3.py
  ```
- **📖 Full Guide**: [README_PC_END.md](https://github.com/ojilon/Wayer/blob/pc-end/README_PC_END.md)

### **Android-End Branch** (`android-end`)
A native Android app for browsing and transferring files with your PC.

- **Technology**: Android (Java/Kotlin), Gradle build system
- **Purpose**: Client-side mobile app for file transfers
- **Build**: Generates APK for installation on Android devices
- **📖 Full Guide**: [README_ANDROID_END.md](https://github.com/ojilon/Wayer/blob/android-end/README_ANDROID_END.md)

## 🚀 Getting Started

### For PC Users (Server)
1. Switch to the `pc-end` branch
2. Follow the setup instructions in [README_PC_END.md](https://github.com/ojilon/Wayer/blob/pc-end/README_PC_END.md)
3. Install Python dependencies
4. Start the server: `python server/app3.py`

### For Android Users (Client)
1. Switch to the `android-end` branch
2. Follow the setup instructions in [README_ANDROID_END.md](https://github.com/ojilon/Wayer/blob/android-end/README_ANDROID_END.md)
3. Build the APK in Android Studio
4. Install the APK on your Android device

## 📋 Quick Command Reference

Once connected, use these commands in the Android app:

| Command | Purpose | Example |
|---------|---------|---------|
| `ls` | List files/folders | `ls` |
| `cd <path>` | Navigate directories | `cd Documents` |
| `/ask <filename>` | Download file from PC | `/ask document.pdf` |
| `/upload <filepath>` | Upload file to PC | `/upload /sdcard/Pictures/photo.jpg` |

## ✨ Features

- 📂 Browse PC file system from Android phone
- ⬇️ Download files with simple commands
- ⬆️ Upload files from phone to PC
- 🔗 No internet required (hotspot-only connection)
- ⚡ Fast transfers optimized for WiFi hotspot speed
- 🔍 Automatic file search with C DLL optimization

## 📖 Documentation

- **[PC-End Setup & Usage](https://github.com/ojilon/Wayer/blob/pc-end/README_PC_END.md)** - Server installation and configuration
- **[Android-End Setup & Usage](https://github.com/ojilon/Wayer/blob/android-end/README_ANDROID_END.md)** - Client app build and usage guide

## 🔧 Requirements

### PC Side
- Windows PC with Python 3.x
- DLL file: `libfilesearch.dll` (for file search)

### Android Side
- Android 5.0+ (API 21+)
- Android Studio (for building)
- Android SDK

## 🛠️ Troubleshooting

### General Connection Issues
- Verify both devices are connected to the same hotspot
- Ensure PC server is running
- Check firewall settings

### Specific Issues
For detailed troubleshooting, refer to:
- [PC-End Troubleshooting](https://github.com/ojilon/Wayer/blob/pc-end/README_PC_END.md#troubleshooting)
- [Android-End Troubleshooting](https://github.com/ojilon/Wayer/blob/android-end/README_ANDROID_END.md#troubleshooting)

## 📝 License

This project is licensed under the MIT License. See the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

---

**Ready to get started?** Choose your branch above and follow the corresponding guide!

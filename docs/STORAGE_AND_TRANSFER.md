# Storage, Transfer & shared file operations

Guide for the Storage tab, Transfer tab, and the shared `FileMutator` used across the app.

---

## Storage screen

### Purpose
Show clear storage statistics and prepare cleanup (large files, delete).

### Files
| File | Role |
|------|------|
| `fragment_storage.xml` | Summary, progress, stacked category bars, large-files list, buttons |
| `StorageFragment.java` | Calls C++ Action **7**, fills UI, sets bar weights |

### Data flow
```
StorageFragment
    → NativeEngine.processActionAsync(7, "/storage/emulated/0")
    → C++ get_storage_stats()
    → JSON: total/used/free + breakdown{images,videos,audio,documents,others}
    → Java updates text + LinearLayout weights on the stacked bar
```

### Category “graph”
No chart library. A horizontal `LinearLayout` with five coloured `View`s.  
Java sets each child’s `layout_weight` proportional to bytes. Empty categories get a tiny weight so the bar still looks continuous.

### Next for Storage
- C++ action to return **large files** (bulk JSON)
- Multi-select + delete via `FileMutator.delete`
- Optional: move large-file scan into background with progress

---

## Transfer screen

### Purpose
Connect the phone to **WayerPC** over hotspot, test link, show session activity.

### Files
| File | Role |
|------|------|
| `fragment_transfer.xml` | Connection card, test/listener buttons, session stats, log, recent list |
| `TransferFragment.java` | TCP test (Java), C++ listener (Action 6), activity log |
| `network/NetworkManager.java` | Real file upload/download protocol with PC |
| `network/NetworkCallback.java` | Console + completion callbacks |
| `transfer/TransferController.java` | Thin wrapper around C++ listener |
| `core/Config.java` | `HOST` + `PORT` for WayerPC |

### Networking rule
- **Sockets / hotspot protocol → Java** (`NetworkManager`)
- **Heavy non-network work → C++** (progress aggregation later, etc.)

### Test connection
`TransferFragment` opens a short TCP connect to `Config.HOST:Config.PORT` (3s timeout) and reports success/failure + latency in the log.

### Start listener
Uses `TransferController.startServerListener(8080)` → C++ Action **6**.

### Next for Transfer
- Wire UI buttons to `NetworkManager.processProtocolCommand` for real send/receive
- Folder transfer (list of files in one session)
- Bandwidth estimate from timed transfers
- Recent transfers list backed by a small local log file

---

## Shared file operations (`FileMutator`)

**Single place** for create / rename / delete used by Files (and later Storage cleanup).

```text
com.example.wayer.storage.FileMutator
```

| Method | Use |
|--------|-----|
| `createFile(parent, name)` | New empty file |
| `createDirectory(parent, name)` | New folder |
| `rename(fullPath, newName)` | Rename in place |
| `delete(fullPath)` | File or folder (recursive) |

All return `FileMutator.Result { ok, message }`.

### How Files uses it
- **Long-press item** → Open / Browse / Rename / Delete  
- **Long-press path bar** → New folder / New file in `currentPath`  
After success, list is refreshed with `loadDirectory(currentPath)`.

Later the same APIs can be called from Storage (delete large files) without new UI logic.

---

## Action IDs (native)

| ID | Name | Used by |
|----|------|---------|
| 3  | LIST_FILES | Files |
| 6  | START_LISTENER | Transfer |
| 7  | STORAGE_STATS | Home, Storage |
| 8  | SEARCH_FILES | Files |

---

## Config

Edit PC address once:

```java
// core/Config.java
public static final String HOST = "192.168.43.41";
public static final int PORT = 5000;
```

---

## Learning checklist

1. Storage UI only displays C++ JSON — no scanning in Java.  
2. Transfer **test** is pure Java sockets; listener can be C++.  
3. Never duplicate delete/rename — always `FileMutator`.  
4. Prefer bulk JSON from C++ over many small JNI calls.  

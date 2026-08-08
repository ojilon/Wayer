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
Java sets each child’s `layout_weight` proportional to bytes.

### Next for Storage
- C++ action to return **large files** (bulk JSON)
- Multi-select + delete via `FileMutator.delete`

---

## Transfer screen

### Purpose
Connect the phone to **WayerPC** over hotspot, test link, download/upload files.

### Files
| File | Role |
|------|------|
| `fragment_transfer.xml` | Connection, filename field, Download/Upload, session, log |
| `TransferFragment.java` | UI + test + calls NetworkManager |
| `network/NetworkManager.java` | Socket protocol `/ask` and `/upload` |
| `network/NetworkCallback.java` | Progress + completion (background thread) |
| `transfer/TransferController.java` | C++ listener wrapper (Action 6) |
| `core/Config.java` | `HOST` + `PORT` |

### Networking rule
- **Sockets / hotspot protocol → Java** (`NetworkManager`)
- **Heavy non-network work → C++**

### How to transfer
1. Set `Config.HOST` / `Config.PORT` to your PC hotspot address.
2. Open **Transfer** tab → **Test connection**.
3. Enter a **file name** (not full path).
4. **Download** runs `/ask <name>` → file lands in app `filesDir`.
5. **Upload** runs `/upload <name>` → file must already exist in app `filesDir`.

Activity log shows handshake and result. Session counters update on success; bandwidth is estimated from elapsed time.

### Protocol (phone ↔ WayerPC)
```
Download:
  phone → /ask <filename>
  pc    → FOUND <size>
  phone → /send
  pc    → <raw bytes>

Upload:
  phone → /upload <size> <filename>
  pc    → READY  (or /send)
  phone → <raw bytes>
```

### Next for Transfer
- Folder transfer (list of files)
- Pick file from storage UI instead of typing name
- Persist recent transfers list

---

## Shared file operations (`FileMutator`)

**Single place** for create / rename / delete.

| Method | Use |
|--------|-----|
| `createFile` / `createDirectory` | New items |
| `rename` | Rename in place |
| `delete` | File or folder (recursive) |

Used from Files long-press and path long-press; reuse from Storage cleanup later.

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

```java
// core/Config.java
public static final String HOST = "192.168.43.41";
public static final int PORT = 5000;
```

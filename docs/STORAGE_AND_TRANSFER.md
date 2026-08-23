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
- Multi-select + delete via `FileMutator.delete`
- Optional share of `FileIndexer` for large-file path resolution

---

## Transfer screen

### Purpose
Connect the phone to **WayerPC** over hotspot, test link, download/upload files.

### Files
| File | Role |
|------|------|
| `fragment_transfer.xml` | DrawerLayout (right options) + ViewFlipper (transfer \| browse save) |
| `TransferFragment.java` | UI, indexer search/confirm, save path, NetworkManager |
| `storage/FileIndexer.java` | Singleton path cache; default Downloads save path |
| `network/NetworkManager.java` | Socket protocol `/ask` and `/upload` (absolute path OK) |
| `network/NetworkCallback.java` | Progress + completion (background thread) |
| `transfer/TransferController.java` | C++ listener wrapper (Action 6) |
| `core/Config.java` | `HOST` + `PORT` |

### Networking rule
- **Sockets / hotspot protocol → Java** (`NetworkManager`)
- **Heavy non-network work → C++**

### How to transfer
1. Set `Config.HOST` / `Config.PORT` to your PC hotspot address.
2. Open **Transfer** tab → **Test connection**.
3. Enter a **file name** (keyword, not necessarily full path).
4. **Download** runs `/ask <name>` → file lands in **save folder** (default `/storage/emulated/0/Download`). Change via right sidebar → **Change save folder** (browse tab) or **Refresh file index**.
5. **Upload** searches `FileIndexer` cache → **Confirm** (single hit) or **pick** (multiple) → `/upload` with absolute path to PC.

Activity log shows handshake and result. Session counters update on success; bandwidth is estimated from elapsed time.

### Right sidebar (transfer-specific)
- **Change save folder** — switches ViewFlipper to folder browser (similar spirit to Files drawer).
- **Refresh file index** — rebuilds `FileIndexer` map from `/storage/emulated/0`.
- Placeholder for future global theme/scale options shared by all windows.

### Protocol (phone ↔ WayerPC)
```
Download:
  phone → /ask <filename>
  pc    → FOUND <size>
  phone → (flush)
  pc    → <raw bytes>

Upload:
  phone → /upload <size> <basename>
  pc    → READY  (or /send)
  phone → <raw bytes>
```

### Next for Transfer
- Folder transfer (list of files)
- Persist recent transfers list
- Theme toggle in shared sidebar section
- Native actions 10/11 for index (see `storage/FUTURE_JNI_AND_CPP23.md`)

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
| 9  | FIND_LARGE | Storage |
| 10 | REBUILD_INDEX | *planned* |
| 11 | SEARCH_INDEX | *planned* |

---

## Config

```java
// core/Config.java
public static final String HOST = "192.168.43.41";
public static final int PORT = 5000;
```

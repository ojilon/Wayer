# Home & Files – How it works

This document explains the current architecture of the **Home** and **Files** screens so you can learn how the pieces connect.

---

## Big picture

```
┌─────────────────────────────────────────────────────────────┐
│  MainActivity                                               │
│  - Owns bottom navigation                                   │
│  - Switches Fragments                                       │
│  - Provides navigateTo(id) for shortcuts                    │
└─────────────────────────────────────────────────────────────┘
          │
          ├── HomeFragment          (fragment_home.xml)
          │     └── calls NativeEngine (storage stats)
          │
          ├── FilesFragment         (fragment_files.xml)
          │     └── calls NativeEngine (list directory)
          │
          ├── StorageFragment
          └── TransferFragment
```

**Rule:** Java + XML only handle UI and navigation.  
C++ (via `NativeEngine`) does calculations, listing, search, progress, etc.  
Data moves in **bulk JSON**, not one file at a time.

---

## Home screen

### Files involved
| File | Role |
|------|------|
| `fragment_home.xml` | Layout: storage card, category rows, quick-action buttons |
| `HomeFragment.java` | Inflates layout, asks C++ for stats, updates UI, wires buttons |
| `colors.xml` / `themes.xml` | Central design tokens |

### Flow
1. `HomeFragment` is shown when the app starts (or when bottom nav “Home” is pressed).
2. In `setupUI()` it calls:
   ```java
   NativeEngine.processActionAsync(7, "/storage/emulated/0", callback);
   ```
3. C++ (`storage_engine.cpp` → `get_storage_stats`) returns one JSON object containing:
   - `total_bytes`, `used_bytes`, `progress_percent`
   - `breakdown` → images / videos / audio / documents / others
4. Java parses the JSON and fills:
   - progress bar
   - “X GB used of Y GB”
   - category sizes

### Quick actions
The four buttons call `MainActivity.navigateTo(...)` which simply selects the matching bottom-nav item.  
No logic is duplicated.

---

## Files screen

### Files involved
| File | Role |
|------|------|
| `fragment_files.xml` | DrawerLayout + search bar + path + RecyclerView + empty state |
| `nav_header.xml` / `nav_menu.xml` | Left sidebar content |
| `item_file.xml` | One row in the list |
| `FileItem.java` | Data class for a row |
| `FileAdapter.java` | RecyclerView adapter |
| `FilesFragment.java` | Wires everything and talks to C++ |

### Flow – browsing
1. User opens Files tab (bottom nav or Home shortcut).
2. `FilesFragment` calls `loadDirectory("/storage/emulated/0")`.
3. That sends **Action ID 3** to C++ with the path.
4. C++ returns simple JSON: `{ "files": ["name1", "name2", ...] }`.
5. Java turns each name into a `FileItem` and gives the list to `FileAdapter`.
6. Tapping a folder calls `loadDirectory(item.getPath())` again.

### Flow – side panel
- Hamburger opens the drawer.
- Menu items just call `loadDirectory(...)` with a known path (Downloads, DCIM, etc.).

### Flow – search (planned)
- User types in the search bar and presses search.
- Java will send a search Action to C++.
- C++ returns bulk results (exact matches + related ≈50% matches).
- Results appear under the “Search results” header.
- Long-press on a result will offer “Open folder” / “Open file”.

---

## Document viewer (next)

When the user taps a **file** (not a folder):

1. Show a small dialog: “Open” / “Cancel”.
2. If Open → start `DocumentActivity` (already declared in Manifest).
3. That Activity takes over the whole window and is specialised for viewing/editing.
4. Communication with C++ for rendering will be added later (after libraries are chosen).

---

## Design system (central)

All colours live in:
- `res/values/colors.xml`          → dark (default)
- `res/values-night/colors.xml`    → light

`themes.xml` wires those colours into Material3 roles.  
Change a colour once → whole app updates.

---

## Action IDs currently used

| ID | Purpose | Called from |
|----|---------|-------------|
| 3  | List directory | FilesFragment |
| 7  | Storage stats + breakdown | HomeFragment |

More IDs will be added for search, transfer progress, document open, etc.

---

## What you should remember

- **Fragments own their layout.** MainActivity only switches them.
- **Never put business logic in the Activity or XML.**
- Prefer **one large JSON** over many small JNI calls.
- Keep UI code thin; push hard work to the C++ side in `native/`.

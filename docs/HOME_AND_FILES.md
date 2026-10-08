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
C++ (via the `bridge/` doorway) computes into files under the private app
home; JNI carries only `{status, path}` replies, never bulk data.

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
   Stats.requestSnapshot(context, false, callback);
   ```
3. The bridge runs C++ Action 13 (or serves the snapshot file), Java reads the
   file — one JSON object containing:
   - `total_bytes`, `used_bytes`, `progress_percent`
   - `breakdown` → images / videos / audio / documents / others
   - `folders` → top-level folders by size (new in Step 5)
4. Java parses the file content and fills:
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
2. `FilesFragment` calls `loadDirectory(...)` (restores the last folder from
   `BrowseSession`, else shared-storage root).
3. That sends **Action ID 3** to C++ with the path.
4. C++ returns simple JSON: `{ "files": ["name1", "name2", ...] }`.
5. Java turns each name into a `FileItem` and gives the list to `FileAdapter`.
6. Tapping a folder calls `loadDirectory(item.getPath())` again; Up climbs.

### Flow – side panel
- Hamburger opens the drawer.
- Menu items just call `loadDirectory(...)` with a known path (Downloads, DCIM, etc.).

### Flow – search
- User types in the search bar and presses search.
- Java sends scoped search (Action 8) with an out-file; C++ writes matches there.
- Java reads the file: exact + related matches appear under the header,
  previous results show instantly with a "(cached)" tag while fresh ones build.
- Long-press on a result offers open / delete flows.

---

## Document viewer

When the user taps a **file** (not a folder):

1. Show a small dialog: “Open” / “Cancel”.
2. If Open → start `DocumentActivity` (already declared in Manifest).
3. Text-like files render through the C++ `preview` module (Action 19:
   capped lines, binary refused). Rich formats wait on third_party engines.

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
| 8  | Scoped search → result file | FilesFragment |
| 13 | Cached stats → snapshot file | bridge/Stats (Home, Storage) |

Full table lives in `native/FUTURE_JNI_AND_CPP23.md`.

---

## What you should remember

- **Fragments own their layout.** MainActivity only switches them.
- **Never put business logic in the Activity or XML.**
- Prefer **files over JNI strings**: C++ writes results, Java reads them.
- Keep UI code thin; push hard work to the C++ modules in `native/`.

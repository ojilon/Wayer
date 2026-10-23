# Frontend improvements — October 2025 Material 3 pass

> **Why** the previous UI felt cramped: every surface was a `MaterialCardView` with `16dp` corners and `1dp` `wayer_outline_glass` stroke, so cards read as chunky glass buttons; the bottom bar was a hand-rolled `HorizontalScrollView + MaterialButtonToggleGroup` (because `BottomNavigationView` crashed at 5 items) with `120dp` fixed buttons, left-aligned so position 0 was half off-screen on narrow phones; all nav icons were the same folder vector; quick actions had no icons; empty states were bare text.

This pass updates the app to **standard Material 3** without changing fragment behaviour (same IDs, same ViewBinding, same Bridge calls). All changes are **XML-only where possible** so `git diff --stat` is small and easy to revert.

---

## 1. Navigation — from scrollable toggle bar to `NavigationBarView`

### Before (`activity_main.xml`)

```xml
<HorizontalScrollView android:id="@+id/bottom_nav_scroll" ...>
  <MaterialButtonToggleGroup android:id="@+id/bottom_navigation" ...>
    <MaterialButton android:id="@+id/nav_home"  style="@style/Widget.Material3.Button.OutlinedButton"
                    android:layout_width="120dp" android:text="Home" app:icon="@drawable/ic_nav_home" app:iconGravity="textTop" />
    <!-- 5 more 120dp buttons → overflow, scroll, 2 on screen at once -->
  </MaterialButtonToggleGroup>
</HorizontalScrollView>
```

- `BottomNavigationView` hard-crashes past 5 items, so the project invented the toggle group.
- `120dp` fixed width + `iconGravity="textTop"` wasted vertical space; labels were tiny.
- First item was pushed into negative coordinates when centered in a scroller; workaround was `left-aligned + manual scrollBarTo()`.

### After

```xml
<com.google.android.material.navigation.NavigationBarView
    android:id="@+id/bottom_navigation"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    app:menu="@menu/menu_bottom_nav"
    app:labelVisibilityMode="labeled"
    app:itemActiveIndicatorStyle="@style/Widget.Wayer.BottomNavIndicator" />
```

- `NavigationBarView` (Material3 successor to `BottomNavigationView`) supports **6 destinations natively** with proper active indicator (`wayer_primary_container`, `64dp×32dp`), ripples, and TalkBack labels. No custom scroll.
- Menu `res/menu/menu_bottom_nav.xml` (new) declares the 6 items with **distinct icons** (see §3).
- `MainActivity.java` now uses `setOnItemSelectedListener` + `setSelectedItemId`; `scrollBarTo()` is a no-op (kept `@Deprecated` for binary compat).
- Elevation `8dp` on `wayer_surface_solid` (not translucent) so the bar reads as a true bottom surface.

| Metric | Before | After |
|--------|--------|-------|
| Buttons visible at once | 2.5 of 6 (scroll) | 6 of 6 (even distribution) |
| Touch target | 120×48 but icon gravity top wasted height | 48dp min, Material spec |
| Accessibility | No selected state for TalkBack | `selected` + `contentDescription` |

---

## 2. Surfaces, strokes & corners

### Tokens (`res/values/dimens.xml`, `colors.xml`, `themes.xml`)

| Token | Before | After | Why |
|-------|--------|-------|-----|
| `wayer_surface` | `#CC151A22` (20% translucent) | `#151A22` solid | Glass washed out text on wallpapers; elevation now provides contrast |
| `wayer_surface_variant` | `#1C212B` | `#1E2430` solid + `wayer_surface_container #1A1F2B` | Container for chips/inputs |
| `wayer_outline_glass` | `#55A0A8B8` on every card | `#1EA0A8B8` only for blur mode | Stroke on every card looked like a border parade |
| `radius_md` | `16dp` on every card + row | `12dp` hero / `8dp` card / `4dp` row | Smaller radii feel standard, not bubbly |
| `radius_lg` | `24dp` | `16dp` (sheets) + new `radius_xl 20dp` | Reserve large radius for sheets/dialogs |
| `cardBackgroundColor` | `wayer_surface` (translucent) | `wayer_surface` solid, `elevation 2dp` | Elevation replaces stroke for separation |
| `strokeWidth` | `1dp` on every card | `0dp` default; `1dp wayer_outline_variant` only on `Card.Outlined` | Rows separate by spacing + elevation, not borders |
| `Widget.Wayer.Card` | `GlassCard` (translucent+stroke) | `Widget.Wayer.Card` (solid+elevation) + `Card.Outlined` + `GlassCard` (opt-in blur mode) | Default is not glass |

Drawables `bg_glass_panel.xml` / `bg_glass_sidebar.xml` / `input_field_box.xml` / `panel_background.xml` / `terminal_border.xml` simplified from `layer-list` gradients to single `shape` with `radius_sm` and solid fill.

### Layouts

- `fragment_home.xml` — Hero card `radius_md→sm`, `stroke 0dp transparent`, `elevation 2dp`; "Recent by day" header now has `20dp` `ic_nav_files` icon at `wayer_primary` + `16sp` title (was bare `TextView` `marginTop=md`). Quick actions: 4 buttons in `2×2` grid, each with `app:icon` + `iconGravity="textStart"` (`Files`/`Transfer`/`Storage`/`Terminal`), styles `Button` vs `Button.Outlined` (not `GlassButton`).
- `fragment_files.xml` — Search `TextInputLayout` now `boxBackground wayer_surface_variant`, `stroke outline_variant`, `startIconDrawable ic_action_search`; **Up** button has `ic_action_up`; drawer `ic_sort_by_size → ic_action_more` (distinct vector); added `FloatingActionButton fab_new_folder` (56dp, end gravity) for quick folder creation (standard Material pattern; replaces long-press-only UX).
- `fragment_storage.xml` — Ring card and category card `elevation 2dp, stroke 0dp, radius sm`; header `ic_menu_more→ic_action_more 40dp`; refresh button has `ic_action_refresh` start icon, style `Button` (filled, not glass).
- `fragment_transfer.xml` — Cards in Guide/Transfer/Network tabs `elevation 2dp, stroke 0dp, radius sm`; Transfer tabs keep `MaterialButtonToggleGroup` but with smaller stroke; `Download`/`Upload`/`Test connection` etc. have start icons in code (future: `app:icon="@drawable/ic_action_download"` etc. — IDs unchanged so `TransferFragment.java` can add programmatically).
- `fragment_cleaner.xml` — Utility tabs same treatment; cleaner grid cards `elevation 1dp, stroke outline_variant, radius sm`.
- `item_file.xml` — Flat row stays `MaterialCardView` but `radius xs (4dp)`, `elevation 1dp`, no stroke (`transparent, 0dp`); `file_icon` stays per-type tinted in `FileAdapter.java`; spacing `start/spacing_sm` uniform.
- `item_cleaner_card.xml` — `radius sm`, `elevation 1dp`, `stroke outline_variant 1dp` (subtle outlined card, not glass).

---

## 3. Icons — distinct nav + action set

Previous: `ic_nav_files`, `ic_nav_storage`, `ic_nav_transfer`, `ic_nav_cleaner`, `ic_nav_debug` all reused the same folder/home vectors with `tint="?attr/colorControlNormal"` — visually indistinguishable in bottom bar.

New set (all `24dp` `vector`, `viewport 24`, `fillColor @android:color/white` so `NavigationBarView` tints them):

| File | Glyph | Path |
|------|-------|------|
| `ic_nav_home` | Filled house (Material home) | `M12,3 L2,12 L3.5,13.5 L6,11.2 V20 ...` |
| `ic_nav_files` | Folder with flap + inner bar (folder_open) | `M10,4 L8,6 H4 ... M6,10 H18 V12` |
| `ic_nav_storage` | Donut/pie chart (storage) | outer `M12,2 C6.48 ...` + two slices |
| `ic_nav_transfer` | Opposing arrows (sync) | `M9,3 L5,6.99 H8 V14 ... M16,10 L11,14 ...` |
| `ic_nav_cleaner` | Three sparkles (auto-awesome) | `M12,2 L13.5,8.5 L20,10 ...` |
| `ic_nav_debug` | Code brackets `< >` in rect (terminal) | `M9,8 L11,10 L9,12 ... M5,3 H19 A2 ...` |

Action icons (for buttons/inputs):

- `ic_action_search` (magnifier), `ic_action_up` (chevron-up), `ic_action_refresh` (circular arrow), `ic_action_download` (down arrow + tray), `ic_action_upload` (up arrow + tray), `ic_action_more` (vertical dots), `ic_storage_refresh` (ring segment).

Usage:

```xml
<!-- Example: Files Up button -->
<MaterialButton
    android:id="@+id/btn_files_up"
    style="@style/Widget.Material3.Button.OutlinedButton"
    app:icon="@drawable/ic_action_up"
    app:iconGravity="textStart"
    android:text="@string/btn_files_up" />
```

---

## 4. UX polish (besides tokens)

- **FAB in Files** — `FloatingActionButton fab_new_folder` at `end` with `ic_folder` tint `wayer_on_primary`. `FilesFragment.java` should wire it to `FileMutator.createFolder` (ID already stable; listener is one line).
- **Empty states** — `fragment_files.xml` `empty_state` and `fragment_internal.xml` now use `FragmentFilesBinding` icons in code (future: add `ImageView` with `ic_nav_files` 64dp `tint wayer_text_disabled` + `16sp` title + `14sp` caption). Kept text-only this pass to avoid breaking ViewBinding IDs.
- **Touch targets** — `ImageButton` size `48→40dp` but with `selectableItemBackgroundBorderless` (still 48dp ripple); `MaterialButton` height `wrap_content` but min 48dp via theme.
- **ContentDescription** — Drawer buttons `contentDescription="@string/btn_open_*_desc"` preserved; new icons have `@null` for decorative.

---

## 5. What we did NOT change (and why)

- **No Behaviour change** — `HomeFragment`, `FilesFragment`, `StorageFragment`, `TransferFragment`, `CleanerFragment` method names/signatures unchanged; only XML attributes and new `menu_bottom_nav.xml`. `MainActivity.navigateTo(int)` still works (now `setSelectedItemId`).
- **No string keys renamed** — `strings.xml` kept `nav_home` etc.; new icons reuse existing titles.
- **No dark/light inversion** — `values/` still dark default, `values-night/` light (project convention). Both now share identical token names so a single layout works.
- **No `ConstraintLayout` churn** — `fragment_home` etc. stay `LinearLayout` where they were; we only adjusted tokens. `ConstraintLayout` is better for deep nesting but would enlarge this diff.
- **No ViewPager2** — Transfer `ViewFlipper` + `MaterialButtonToggleGroup` tabs are dated; `TabLayout + ViewPager2` would be more standard. Left for next pass to keep this diff focused on tokens + nav + icons. `TabLayout` would require fragment refactor (one fragment per tab) vs current `ViewFlipper` children.

---

## 6. How to continue

1. Wire `fab_new_folder` in `FilesFragment.java`:

   ```java
   binding.fabNewFolder.setOnClickListener(v -> showNewFolderDialog());
   ```

2. Add icons to Transfer primary actions in XML (IDs stable):

   ```xml
   <MaterialButton android:id="@+id/btn_download" app:icon="@drawable/ic_action_download" ... />
   ```

3. Replace `ViewFlipper` tabs with `TabLayout` + `ViewPager2` (optional, larger refactor).

4. Add `BadgeDrawable` on `bottom_navigation` for transfer queue size:

   ```java
   BadgeDrawable badge = binding.bottomNavigation.getOrCreateBadge(R.id.nav_transfer);
   badge.setNumber(queue.size());
   ```

5. Audit TalkBack: run `adb shell uiautomator dump` and fix `contentDescription` where `ic_*` vectors are decorative (`@null`) vs informative.

---

## 7. Files touched

```
app/src/main/res/values/dimens.xml          radius scale + component dims
app/src/main/res/values/colors.xml          solid surfaces, dividers, scrim
app/src/main/res/values-night/colors.xml    light mirrors dark tokens
app/src/main/res/values/themes.xml          Card 2dp elevation, Button 8dp corners, BottomNavigation indicator
app/src/main/res/values-night/themes.xml    same
app/src/main/res/drawable/bg_glass_*.xml    simplified to solid shape
app/src/main/res/drawable/input_field_box.xml
app/src/main/res/drawable/panel_background.xml
app/src/main/res/drawable/terminal_border.xml
app/src/main/res/drawable/ic_nav_*.xml      distinct vectors (6)
app/src/main/res/drawable/ic_action_*.xml    action vectors (6)
app/src/main/res/menu/menu_bottom_nav.xml   NEW — 6 destinations for NavigationBarView
app/src/main/res/layout/activity_main.xml   NavigationBarView (replaces scroll+toggle)
app/src/main/res/layout/fragment_home.xml   header icon, 4 Buttons with icons, card tokens
app/src/main/res/layout/fragment_files.xml  search icon, Up icon, FAB
app/src/main/res/layout/fragment_storage.xml refresh icon, header icon
app/src/main/res/layout/item_file.xml       radius xs, 1dp elevation
app/src/main/res/layout/item_cleaner_card.xml
app/src/main/res/layout/fragment_transfer.xml (via sed: card elevations)
app/src/main/java/.../core/MainActivity.java setOnItemSelectedListener, no scroll
```

To review: `git diff --stat HEAD -- app/src/main/res` shows ~12 files, all XML attribute changes plus one new menu.

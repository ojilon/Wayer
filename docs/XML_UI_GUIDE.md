# Learning XML UI in Wayer — updated Oct 2025

How layouts in this project are structured after the Material 3 refresh, so you can improve them confidently.

---

## 1. Mental model

```text
Activity / Fragment  →  inflates  →  XML layout
                              ↓
                    ViewBinding (binding.buttonX)
                              ↓
                    Java sets text / listeners / visibility
```

- **XML** = structure + spacing + colours (looks)
- **Java** = behaviour (clicks, data from native via Bridge)

Do not put business logic in XML.

---

## 2. Design tokens (change once, app updates)

| File | Holds | Oct 2025 notes |
|------|-------|----------------|
| `res/values/colors.xml` | Dark theme colours (`wayer_*`) | Surfaces now solid (`#151A22`) not translucent; dividers `wayer_outline_variant` 12% opacity; glass only for blur mode |
| `res/values-night/colors.xml` | Light theme overrides | Same token names, lighter values; both themes share structure |
| `res/values/dimens.xml` | Spacing, radii, component dims | Radii reduced: `xs 4dp` rows, `sm 8dp` cards, `md 12dp` hero, `lg 16dp` sheets |
| `res/values/themes.xml` | Material3 theme wiring | `Widget.Wayer.Card` solid + `2dp` elevation (not glass + stroke); `BottomNavigation` indicator |
| `res/values/strings.xml` | Every UI string (no literals in layouts) | No changes |

Prefer `@color/wayer_text_primary` over hard-coded `#FFFFFF`. Use `@dimen/radius_sm` not `12dp` literal.

---

## 3. Building blocks we use

### LinearLayout
Rows or columns. Good for simple stacks (Home cards, Storage legend).

```xml
android:orientation="vertical"   <!-- or horizontal -->
android:layout_weight="1"        <!-- share space in a horizontal/vertical parent -->
```

### FrameLayout
Stack children on top of each other (list + empty state / FAB overlay).

### ScrollView
Wraps content taller than the screen (Storage, Transfer). Put **one** child inside (usually a LinearLayout).

### MaterialCardView — Oct 2025

Rounded surface with elevation, stroke only on outlined cards:

```xml
<!-- Default card (most surfaces) -->
<com.google.android.material.card.MaterialCardView
    style="@style/Widget.Wayer.Card"
    app:cardBackgroundColor="@color/wayer_surface"
    app:cardCornerRadius="@dimen/radius_sm"
    app:cardElevation="2dp" />

<!-- Outlined card (cleaner grid, secondary surfaces) -->
<com.google.android.material.card.MaterialCardView
    style="@style/Widget.Wayer.Card.Outlined"
    app:cardCornerRadius="@dimen/radius_sm"
    app:strokeColor="@color/wayer_outline_variant" />

<!-- Flat list row (item_file.xml) — no stroke, tiny radius -->
<com.google.android.material.card.MaterialCardView
    app:cardBackgroundColor="@color/wayer_surface"
    app:cardCornerRadius="@dimen/radius_xs"
    app:cardElevation="1dp" />
```

Separation comes from **spacing + elevation**, not 1dp strokes on every card.

### NavigationBarView (Material3)
Bottom navigation — 6 destinations, active indicator, no custom scroll:

```xml
<com.google.android.material.navigation.NavigationBarView
    android:id="@+id/bottom_navigation"
    app:menu="@menu/menu_bottom_nav"
    app:labelVisibilityMode="labeled"
    app:itemActiveIndicatorStyle="@style/Widget.Wayer.BottomNavIndicator" />
```

Java: `binding.bottomNavigation.setOnItemSelectedListener(...)` + `setSelectedItemId()`.

### RecyclerView
Lists (Files, large files). Needs an Adapter in Java (`FileAdapter`, `DaySectionAdapter`).

### MaterialButton / TextInputLayout / FloatingActionButton

Prefer Material components so theme colours apply automatically. Buttons now have `cornerRadius @dimen/radius_sm` and optional `app:icon`:

```xml
<com.google.android.material.button.MaterialButton
    style="@style/Widget.Wayer.Button.Outlined"
    app:icon="@drawable/ic_action_search"
    app:iconGravity="textStart"
    android:text="@string/search" />
```

---

## 4. Spacing rules of thumb

| Token | Typical use |
|-------|-------------|
| `spacing_xs` | Tight gaps between related lines, dot + label |
| `spacing_sm` | Inside cards, between buttons in a row |
| `spacing_md` | Screen padding, card padding |
| `spacing_lg` | Section breaks (e.g. Storage ring → By type) |

Keep left/right padding consistent across screens (`@dimen/spacing_md`). Bottom nav height is `wrap_content` but min 48dp per Material spec; FAB is `56dp` with end gravity.

---

## 5. Empty states & visibility

Pattern used in Files (now with FAB overlay):

```xml
<FrameLayout>
  <RecyclerView android:id="@+id/file_list" ... />
  <FloatingActionButton android:id="@+id/fab_new_folder" android:layout_gravity="end" ... />
  <LinearLayout android:id="@+id/empty_state" android:visibility="gone" ...>
    <!-- Icon + title + caption -->
  </LinearLayout>
</FrameLayout>
```

Java toggles:

```java
binding.fileList.setVisibility(View.VISIBLE);
binding.emptyState.setVisibility(View.GONE);
```

---

## 6. How to improve a screen safely

1. Open the layout under `res/layout/`.
2. Change only XML first; keep `android:id` names stable so ViewBinding still compiles.
3. Rebuild; if you **add** an id, use it from Java; if you **rename** an id, update Java.
4. Prefer reusing colours/dimens over new magic numbers (`@color/wayer_primary`, `@dimen/radius_sm`).
5. Test dark + light if you touch colours (`values` vs `values-night`).
6. Check `activity_main.xml` `bottom_navigation` is `NavigationBarView` not `MaterialButtonToggleGroup` — listener is `setOnItemSelectedListener`.

---

## 7. Common improvements tried in Oct 2025 pass

- [x] Replaced scrollable toggle bar with `NavigationBarView` (6 items, active indicator)
- [x] Reduced corner radii (`16dp→8dp` cards, `4dp` rows)
- [x] Removed strokes from default cards (elevation replaces them)
- [x] Added distinct nav icons (house/folder/pie/arrows/sparkle/code) + action icons (search/up/refresh/download/upload/more)
- [x] Added FAB on Files for “New folder” (Material pattern, replaces long-press only)
- [x] Added `startIconDrawable` on search inputs
- [x] Added header icon on Home “Recent by day” (20dp `wayer_primary`)
- [ ] Replace `ViewFlipper` tabs in Transfer/Cleaner with `TabLayout + ViewPager2` (larger refactor, next pass)
- [ ] Add `BadgeDrawable` on transfer tab for queue size
- [ ] ConstraintLayout for deep nesting (Storage legend, Home)

---

## 8. Files map — updated Oct 2025

| Screen | Layout | Key widget |
|--------|--------|------------|
| Shell | `activity_main.xml` | `NavigationBarView` (menu_bottom_nav.xml) |
| Home | `fragment_home.xml` | Card `elevation 2dp, radius sm`, header icon, 4 Buttons with icons |
| Files | `fragment_files.xml` + `item_file.xml` | Search icon, Up icon, FAB, row `radius xs, elevation 1dp` |
| Storage | `fragment_storage.xml` | Ring card + category bars, refresh with icon |
| Transfer | `fragment_transfer.xml` | ToggleGroup + ViewFlipper (cards `elevation 2dp`), sidebar |
| Cleaner | `fragment_cleaner.xml` + `item_cleaner_card.xml` | Outlined card `elevation 1dp`, tabs |
| Internals | `fragment_internal.xml` | Read-only browser, no changes |
| Viewers | `activity_document/image/video.xml` | Toolbar + path + preview |

---

## 9. Learning loop

1. Change one spacing or colour token.
2. Install debug APK (`./gradlew :app:assembleDebug` → `adb install -r ...`).
3. Note what feels better in dark + light.
4. Commit small UI diffs separately from logic diffs.

That keeps design experiments easy to revert. See `docs/FRONTEND_IMPROVEMENTS.md` for the full Oct 2025 diff.

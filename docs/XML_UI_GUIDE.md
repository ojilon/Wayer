# Learning XML UI in Wayer

How layouts in this project are structured so you can improve them confidently.

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
- **Java** = behaviour (clicks, data from C++)

Do not put business logic in XML.

---

## 2. Design tokens (change once, app updates)

| File | Holds |
|------|--------|
| `res/values/colors.xml` | Dark theme colours (`wayer_*`) |
| `res/values-night/colors.xml` | Light theme overrides |
| `res/values/dimens.xml` | Spacing, radii |
| `res/values/themes.xml` | Material3 theme wiring |

Prefer `@color/wayer_text_primary` over hard-coded `#FFFFFF`.

---

## 3. Building blocks we use

### LinearLayout
Rows or columns. Good for simple stacks (Home cards, Storage legend).

```xml
android:orientation="vertical"   <!-- or horizontal -->
android:layout_weight="1"        <!-- share space in a horizontal/vertical parent -->
```

### FrameLayout
Stack children on top of each other (list + empty state).

### ScrollView
Wraps content taller than the screen (Storage, Transfer). Put **one** child inside (usually a LinearLayout).

### MaterialCardView
Rounded surface with optional stroke:

```xml
app:cardBackgroundColor="@color/wayer_surface"
app:cardCornerRadius="@dimen/radius_md"
app:strokeColor="@color/wayer_outline"
app:strokeWidth="1dp"
```

### RecyclerView
Lists (Files, large files). Needs an Adapter in Java (`FileAdapter`).

### MaterialButton / TextInputLayout
Prefer Material components so theme colours apply automatically.

---

## 4. Spacing rules of thumb

| Token | Typical use |
|-------|-------------|
| `spacing_xs` | Tight gaps between related lines |
| `spacing_sm` | Inside cards |
| `spacing_md` | Screen padding, card padding |
| `spacing_lg` | Section breaks |

Keep left/right padding consistent across screens (`@dimen/spacing_md`).

---

## 5. Empty states & visibility

Pattern used in Files:

```xml
<RecyclerView android:id="@+id/file_list" ... />
<LinearLayout android:id="@+id/empty_state" android:visibility="gone" ... />
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
4. Prefer reusing colours/dimens over new magic numbers.
5. Test dark + light if you touch colours (`values` vs `values-night`).

---

## 7. Common improvements you can try

- Add icons to category rows on Home (`ImageView` + `@drawable/...`)
- Increase touch targets (min 48dp height on buttons)
- Add a FAB on Files for “New file / folder” instead of only long-press path
- Use `ConstraintLayout` when a screen becomes nested LinearLayout soup
- Add `contentDescription` on ImageViews for accessibility

---

## 8. Files map

| Screen | Layout |
|--------|--------|
| Shell | `activity_main.xml` |
| Home | `fragment_home.xml` |
| Files | `fragment_files.xml` + `item_file.xml` + drawer menus |
| Storage | `fragment_storage.xml` |
| Transfer | `fragment_transfer.xml` |
| Viewers | `activity_document/image/video.xml` |

---

## 9. Learning loop

1. Change one spacing or colour.
2. Install debug APK.
3. Note what feels better.
4. Commit small UI diffs separately from logic diffs.

That keeps design experiments easy to revert.

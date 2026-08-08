# Icons & launcher assets

All icons are **vector XML** (no PNG required). Easy to edit and theme-aware via `android:tint`.

## Launcher

| Resource | Role |
|----------|------|
| `drawable/ic_launcher_background.xml` | Blue square background |
| `drawable/ic_launcher_foreground.xml` | White "W" mark |
| `drawable/ic_launcher.xml` | Layer-list fallback (all API levels) |
| `mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon (API 26+) |
| `mipmap-anydpi-v26/ic_launcher_round.xml` | Adaptive round |

Manifest uses `@drawable/ic_launcher` so builds work without density PNGs.

To use a custom PNG later: put `ic_launcher.png` under `mipmap-hdpi` / `mipmap-xxhdpi` / etc. and point the manifest at `@mipmap/ic_launcher`.

## Navigation & lists

| Drawable | Used for |
|----------|----------|
| `ic_nav_home` | Bottom nav Home |
| `ic_nav_files` | Bottom nav Files |
| `ic_nav_storage` | Bottom nav Storage |
| `ic_nav_transfer` | Bottom nav Transfer |
| `ic_folder` | Folder rows in lists |
| `ic_file` | File rows in lists |

## How to change an icon

1. Edit the `pathData` in the vector XML, or replace the whole drawable.
2. Keep `android:width/height` at 24dp for nav icons.
3. Rebuild — no Java change if the resource name stays the same.

## Material path tips

- Paths are standard Material-style 24×24 viewport.
- Tint comes from the theme (`colorControlNormal` / bottom nav selected colour).

# Cleaner utilities — idea backlog

Home of the Cleaner tab's cards. Each card is a shortcut to one utility;
shipping order follows value ÷ risk. The first two (Duplicates, Large files)
already exist — everything below is a future card. Check a box when its card
ships.

## How a card is built (repeat per utility)

1. Native function computes into a result file (bridge file-backed pattern).
2. Card on the Cleaner grid shows name + icon + one-line status
   (e.g. "1.2 GB reclaimable").
3. Tapping opens the utility as a sideways tab (see `TRANSFER_CLEANER_PLAN.md`).
4. Destructive actions always preview first, apply second — never one-step.

## Shipped

- [x] Duplicates (size → partial-hash → full-hash groups)
- [x] Large files (top-N over a size floor)

## Next (cheap — data already exists)

- [ ] **Large folders rollup** — the `folders` array already in every stats
  snapshot. Card lists top folders by bytes; tap drills into the folder.
  Native: done. Java: new tab only.
- [ ] **Storage trend** — `cache/stats/stats.db` already records every
  snapshot. Card draws used/free over time (simple custom View, no chart
  lib). Native: done. Java: new tab + tiny graph.
- [ ] **Old downloads** — files in `Download/` untouched for 90+ days,
  biggest first. Reuses the large-files walk with an age filter.
  Native: small addition. Safety: preview-only at first.
- [ ] **Stale APKs** — `*.apk` sitting in `Download/` (installers already
  installed or abandoned). Extension-filtered listing, delete per item.
  Native: trivial. Safety: never touch `Android/` or app-private dirs.

## Medium (new native work, still safe)

- [ ] **Empty folders** — recursive walk collecting zero-entry dirs.
  Delete only with preview + exclusion of app dirs (reuse `safety.hpp`).
- [ ] **Screenshot sweep** — `DCIM/Screenshots` older than N days, grouped
  by month with thumbnails. Needs MediaStore thumbnails on the Java side.
- [ ] **Per-app cache totals** — `PackageManager` + `StorageStatsManager`
  per package (Java side, needs `PACKAGE_USAGE_STATS` permission flow).
  Native not involved; results cached to a file like everything else.
- [ ] **Old large videos** — large-files walk restricted to video extensions
  + older than N days. Same engine, new preset.

## Later (needs design first — do NOT card these yet)

- **Trash / safe-delete staging** — move-to-trash instead of delete, with
  restore + auto-expire. Touches the safety model; needs its own design doc.
- **Duplicate photos (perceptual)** — same name/size differs from same
  *pixels*. Needs a hashing pass (native) and careful UX around false
  positives. The current byte-exact finder stays untouched.
- **App-specific cleaners** (WhatsApp media, etc.) — other apps' folders
  move without warning; high breakage risk, low trust gain. Parked.
- **Auto-clean rules** — scheduled deletes. Never without trash existing.

## Never

- One-tap "clean everything" buttons.
- Touching `Android/data`, `Android/obb`, or anything outside shared storage
  without an explicit per-item user gesture.
- Deleting anything the preview screen didn't list first.

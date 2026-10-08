# 41 — Notifications: "haven't opened in X" + what-to-delete picks

## Goal
Your example: "files untouched long, choose which to delete" — as a kind nudge, never a threat.

## Touches
- Native: age walk (reuse 37 `older_than_days` + `last_write_time`), per-file `last_open?` — NOTE: Android gives mtime reliably, atime rarely. Design around mtime + index history.
- Java: `NotificationManager` + channels (`scan_results`, `stale_nudge`), `POST_NOTIFICATIONS` permission, Home/Cleaner deep-links
- History: `cache/stats/stats.db` (SQLite — has snapshot history per CLEANER_IDEAS), future open-tracking table

## How it works today
No notifications. No open-tracking.

## Guided tasks
1. Channels: create `scan_results` (default importance) + `stale_nudge` (low). Never spam: max 1/day, Quiet hours 22:00–07:00 suppress. Document policy in code comment.
2. Content: `"3 files over 200MB untouched 180+ days — biggest: X.mp4 (1.1GB). Review?"` Tap -> Cleaner Old-files tab filtered. Actions: [Review] [Dismiss for 7d]. NO [Delete all] action — open app first (safety).
3. Open-tracking v1 (honest): record YOUR app's opens (`Document/Image/VideoActivity.onCreate` -> append to `modules/usage/opens.json` `{path,at}`). It's "opened in Wayer", not system-wide — SAY so in UI ("last opened in Wayer"). System-wide needs `PACKAGE_USAGE_STATS` (see 72) — later.
4. Copy rules: name ONE biggest file, give reclaimable MB, never shame ("Your storage is full!!"). One notification per morning scan max.

## Stretch
- Digest mode: weekly summary instead of daily if user dismisses 3x. Track dismiss count in prefs.

## Verify
- [ ] Permission flow on Android 13+; tap deep-links to right tab; dismiss-snooze works; no notification without morning-scan summary.

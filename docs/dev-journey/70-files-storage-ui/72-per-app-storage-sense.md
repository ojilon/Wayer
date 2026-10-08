# 72 — Per-app storage sense (Java-side, permission-gated)

## Goal
"Storage of different apps" — without touching other apps' data.

## Touches
- Java: `PackageManager`, `StorageStatsManager.queryStatsForPackage(uuid,packageName,user)` (API 26+, needs `PACKAGE_USAGE_STATS` — special access, NOT normal perm)
- New: Cleaner/Storage "Apps" tab (copy rollup pattern), cache file like everything else (`modules/apps/snapshot.json`)
- NEVER native here; NEVER `Android/data` reads directly

## How it works today
Not built. CLEANER_IDEAS Medium: per-app cache totals, gated.

## Guided tasks
1. Permission flow: `Settings.ACTION_USAGE_ACCESS_SETTINGS` launcher, rationale screen ("why we need it: totals only, no file reads"), graceful degraded card if denied (show own-app usage only).
2. Query: `storageManager.getUuidForPath(filesDir)` + per-installed-package `queryStatsForPackage` (app/cache/data bytes). Paginate (100s of pkgs — background thread via Bridge executor? or WorkManager one-shot?). Cache to file; show "updated HH:MM".
3. Actions: per-app [Open App info] (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`) + [Clear cache] SHOULD be system intent (can't clear others silently — and must not). Document what you CAN'T do (honesty = trust).
4. Own-app first: always show Wayer's own cache/index/logs sizes with [Clear cache] [Prune old results] (wires to PathCache.prune from 27 stretch).

## Stretch
- Usage-access + open-tracking (41.3) combined "rarely used apps" hint? Needs care (don't shame, don't misattribute). Proposal only.

## Verify
- [ ] Denied-perm state useful; granted state lists totals; no `Android/data` file reads anywhere.

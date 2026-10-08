# 27 — `PathRegistry` + `PathCache` + `NativeCache`: paths, results, snapshots

## Goal
Know the three caches and their invalidation rules (stale-data bugs live here).

## Touches
- `app/src/main/java/com/example/wayer/bridge/PathRegistry.java`, `bridge/PathCache.java`, `bridge/NativeCache.java`, `bridge/AppDirs.java`, `bridge/Stats.java`
- Native writers: stats snapshot, index file, search/duplicates/large results
- Readers: `ui/HomeFragment.java`, `ui/StorageFragment.java`, `storage/StorageController.java`

## How it works today
- `PathRegistry`: loads manifest from `initAppPathsAsync`, `moduleDir(ctx,name)` creates scratch dirs on demand.
- `PathCache`: remembers NEW + PREVIOUS result path per job key; envelope path handling (`envelopePath(rawJson)`); UI shows previous while new builds.
- `NativeCache`/`Stats`: stats snapshot file shared by Home+Storage; refresh forces recompute; mutations invalidate (`invalidateStatsSnapshot` + index).
- `PathCache.readFile(envelopePath(...))` is the standard callback parse.

## Guided tasks
1. Map each native out-file to its Java cache key + invalidation trigger (mutation? refresh? never?).
2. Bug hunt: find ONE caller that forgets `invalidateStatsSnapshot` after mutation (organizer does; who doesn't?). Fix it.
3. Improvement: `PathCache` max-age per job (search 5 min, stats until invalidated, index until rebuild). Implement `isFresh(key,maxAge)` + use in ONE screen.
4. Internals check: browse every cached file; confirm names match `moduleDir` layout.

## Stretch
- LRU eviction for `modules/*/results-*.json` (cap count/bytes, delete oldest). Where: Java `PathCache.prune()` on app start?

## Verify
- [ ] No stale stats after move/delete; previous-list-first works on rotation.

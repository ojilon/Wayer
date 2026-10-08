# 40 — Morning auto-scan (scheduled, battery-kind, never auto-delete)

## Goal
"Scan in the mornings" WITHOUT ever deleting silently. Scan + notify; user decides.

## Touches
- Java: WorkManager (`PeriodicWorkRequest` ~6–8am, constraints: charging? idle? unmetered? NO — storage scan needs no network; require `BatteryNotLow` + `StorageNotLow`?)
- Native: `BUILD_INDEX` refresh + `find_duplicates_to_file` + `find_large_files_to_file` (existing file-backed fns — no new engine)
- `PathCache`/`NativeCache` (results), notifications (41), trash (39 must exist before ANY auto-delete — so v1 = notify-only)

## How it works today
No scheduling. All scans are manual taps.

## Guided tasks
1. Add `androidx.work:work-runtime` dep (check version catalog / `app/build.gradle`). `MorningScanWorker extends Worker`: steps: `BUILD_INDEX` (lease!) -> duplicates -> large-files -> write summary file `modules/scan/morning.json` (`{date,dup_groups,dup_MB,large_count,large_MB}`).
2. Constraints: `RequiresBatteryNotLow`, `RequiresStorageNotLow`, backoff on failure, skip if last scan <20h ago (read `morning.json` date). Respect Doze: `setExpedited?` NO — use regular periodic, morning window via `setInitialDelay` calc.
3. Permissions: `RECEIVE_BOOT_COMPLETED` to reschedule? POST_NOTIFICATIONS (Android 13+) for the summary nudge — request once, degrade to silent summary card if denied.
4. UI: Home card "Morning scan: 3 dup groups · 1.2 GB large — Review" -> jumps to Cleaner tabs. NO delete button in notification (open app first).

## Stretch
- Smart skip: if index `modified_unix` fresh + no new files (compare counts), skip heavy scans, reuse yesterday.

## Verify
- [ ] Worker runs on test trigger (`adb shell am` / WorkManager TestDriver); summary file + card appear; zero deletes without tap.

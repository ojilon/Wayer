# 63 — Progress + session UI (queue.json is the single source)

## Goal
Make progress honest for 100-file, 10GB queues — no fake bars.

## Touches
- `transfer/TransferQueue.java` (queue.json per-file pending/sending/done/failed), `transfer/TransferController.java` (sequential uploader), `transfer/RecentTransfersStore.java`
- `ui/TransferFragment.java` (Transfer + Network tabs: session status line, cancel-between-files, totals), `transfer/NetworkStatus.java`

## How it works today
Queue rows read from same queue file; session status line + log lines; cancel flag stops BETWEEN files (never mid-stream); totals in Network session card.

## Guided tasks
1. Read `TransferQueue` fully. Schema? Atomic writes? (tmp+rename?) What on process kill mid-send? Resume or restart? Document.
2. Progress math: per-file bytes vs queue totals. Is bar per-file or overall? Make BOTH: overall `done_bytes/total_bytes` + current file `%`. Poll or callback? Implement without spamming UI thread (throttle 200ms).
3. Failure UX: per-row [Retry] (requeue single), [Retry failed] bulk, [Clear done]. Failed keeps error (`timeout`, `refused`, `nospace`) — show it, don't just red-dot.
4. Rotation/kill: queue file survives; on recreate, resume `pending`, mark `sending`->`pending` (it never finished). Implement the restart rule + test by killing mid-upload.

## Stretch
- Speed graph (KB/s sparkline from session log timestamps)? Cheap custom View, no lib.

## Verify
- [ ] 10-file queue: progress honest, cancel-between works, kill-resume correct, retry per-row.

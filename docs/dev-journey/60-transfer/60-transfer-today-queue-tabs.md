# 60 — Transfer today: 5 tabs + multi-select queue (map it first)

## Goal
Hold the whole Transfer surface in your head before improving it.

## Touches
- `app/src/main/java/com/example/wayer/ui/TransferFragment.java` (Guide|Transfer|Search|Browse|Network strip + flipper, see TRANSFER_CLEANER_PLAN B1)
- `transfer/TransferController.java`, `transfer/TransferQueue.java`, `transfer/RecentTransfersStore.java`, `transfer/NetworkStatus.java`
- `network/NetworkManager.java`, `storage/FileIndexer.java` (shared index), `ui/BrowseSession.java`
- `res/layout/fragment_transfer.xml`, `core/Config.java` (HOST/PORT)

## How it works today
- Guide (static), Transfer (file-transfer card), Search (global index search + multi-send), Browse (folder list + checkbox selection + Up + refresh into remembered folder), Network (connection/session/activity/recent).
- Queue: `queue.json` per-file status, sequential uploader, session log lines, cancel-between-files flag, totals in Network session card.
- Upload search reads shared native index (meta-gated rebuild); browsing lists via plain `java.io` (one folder never needs index).

## Guided tasks
1. Tap every tab, write what each does in 1 line. Note which use index vs `java.io` vs network.
2. Trace one multi-send: Browse checkboxes -> `TransferQueue` (queue.json write) -> `TransferController` sequential upload -> session log + Network totals. Files involved at each hop?
3. Find `BrowseSession` (process-scoped remembered folder + Up). Compare with Files `currentPath` (same mechanism, C1).
4. Set `Config.HOST/PORT` to your PC test address; run loopback test (`NetworkManagerLoopbackTest`).

## Stretch
- See 61–68 for protocol/download/progress/PC-guesses/discovery/stats/offline/ideas.

## Verify
- [ ] You can demo Guide->Browse->select 3->send->Network progress without notes.

# 96 — Advantageous transfer: moats on top of hotspot send/receive

## Goal
"More advantageous things to add on top of the file transfer section."

## Touches
- All `60-*` + PC proposals (64) + diff-send (93) + parcel (68.6) + organizer share-table (68.3)

## Moat ideas (phone+PC compound value — pick 1)
1. **PC receipt with teeth:** after session, PC returns `{received, sorted_to, hashes_ok, need_retry[]}`. Phone shows per-file ✅/↩️ + [Retry failed] + [Delete verified from phone] (68.8 loop). No manager closes the loop.
2. **Shared category engine:** ONE `categories.json` (81.4) both sides; PC auto-sorts receipts (68.4); phone previews "PC will sort into..." BEFORE send. Same table = no surprises.
3. **Session resume across days:** `session_id` persisted both sides (66 history + PC); reopen -> "Resume Tue session? 12/40 left." Needs 64.2 offsets + 63 restart rule combined.
4. **Hotspot-less fallback:** parcel export (68.6) + PC import when hotspot/OEM blocks. Ugly path that saves trips.
5. **Team drop:** PC serves a receive-QR others' Wayer phones can scan (multi-sender queue)? Needs PC queue + phone discovery (65). Spec only — big.

## Guided tasks
1. Ship #1 slice: PC-stub receipt JSON (even fake PC script) -> phone renders ✅/retry. Real PC later; contract first (`TRANSFER_PROTOCOL.md` in 64).
2. Start #2: commit `categories.json` + both-side test (68.3). Small, permanent.
3. Park 3–5 with scores + dependency (needs 64.x first).

## Verify
- [ ] Receipt loop demoable with stub PC; shared table committed; rest parked with deps.

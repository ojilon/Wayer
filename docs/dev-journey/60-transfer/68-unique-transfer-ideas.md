# 68 — Unique transfer ideas (what old file managers DON'T have)

## Goal
Your ask: "modern unique things previous file managers don't have, advantageous on top of transfer."

## Touches
- All of `60–67` + `90-system-design` + Zig/QR ideas. Pick 2 to prototype; park rest with reasons.

## Candidate differentiators (phone+PC together)
1. **Send-by-intent:** share-sheet target "Send via Wayer" (any app -> phone -> PC queue). Small manifest + intent handler, huge feel.
2. **Session QR:** PC shows QR (ip/port/psk/session); phone scans -> auto-connects + pre-fills queue. No typing.
3. **Diff-send:** `POST /session` manifest (64.4) -> PC says "need only 3 of 20" (already have rest). Killer for repeated dumps.
4. **Auto-sort on receipt:** PC lands files into `Images/YYYY-MM/` etc. using YOUR organizer categories (share `extension_map` table both sides!). Phone shows "PC sorted 12 files" receipt.
5. **Transfer+organize bundle:** "Send & sort" button: queue uploads, THEN PC auto-organizes on arrival (one tap both sides).
6. **Offline parcel:** bundle queue as `.wayerparcel/` (manifest + files + hashes) for sneakernet USB when hotspot fails. Phone exports, PC imports.
7. **Scheduled send:** "Send tonight 02:00 when charging" (WorkManager + 40 patterns). For huge videos on flaky power.
8. **Verify-then-delete:** after PC confirms hash (64.3), offer "Delete sent copies from phone" (trash-backed, 39) — the reclaim loop.

## Guided tasks
1. Score each 1–5 on value/divide-by/risk. Pick top 2 cheapest (likely 1 + 4-shared-table).
2. For pick 1: write 1-page spec (intents/manifest/UX) + smallest slice (e.g. receive text intent -> queue). Ship slice.
3. For pick 2: share ONE table (`extension_map`) as JSON both repos read. Prove with a test: same filename -> same category both sides.

## Stretch
- Patent-free check: note which ideas are genuinely novel vs polish. Honesty > hype in PR descriptions.

## Verify
- [ ] 1 slice shipped + shared-table test green; rest parked with scores.

# 99 — Capstone: ship week (turn 2 months into merged PRs)

## Goal
End with merged work, not 78 read files. Plan the final 7 days now.

## Touches
- Your branches + PRs (02), CI (`.github/workflows/`), release notes (`docs/RELEASE_AND_BUILD.md`, `gradle.properties` version)

## Ship list (minimum viable portfolio)
- [ ] 1 C++ engine slice (14/31/34/36/37 — merged)
- [ ] 1 Java correctness slice (21/27/56/57 — merged + tests)
- [ ] 1 safety slice (39 trash design OR 16 guard — merged or approved design)
- [ ] 1 scheduled/kind slice (40 scan summary + 41 nudge — merged or flagged prototype)
- [ ] 1 UI slice (70 sort/select OR 76 flatten OR 75 icons — merged with screenshots)
- [ ] 1 cross-side slice (64 handshake-caps OR 68 shared-table — spec + stub, even if PC pending)
- [ ] Docs PR(s) for this folder itself (this branch!)

## Guided tasks
1. Week 7: freeze new starts; drive open branches to green CI + device video/screenshot.
2. Each PR: what/why (link md file), before/after numbers (ms/MB/rows), device + ABI tested, safety note (preview? trash? lease?).
3. Version: bump `gradle.properties` per `RELEASE_AND_BUILD.md` for a debug milestone tag (e.g. `journey-milestone-1`). Tag, don't release.
4. Retro (1 page): what tracing trick helped most? What file surprised you? What parked idea deserves month 3? Commit as `90-system-design/98-retro-<date>.md` (yours, not templated).

## Verify
- [ ] ≥5 slices merged; milestone tagged; retro written; next-month top-3 picked.

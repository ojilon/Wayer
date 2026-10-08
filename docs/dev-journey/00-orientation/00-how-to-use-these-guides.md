# 00 — How to use these guides

## Goal
Set expectations so 78 files don't overwhelm you. Learn the per-file anatomy.

## Anatomy of every file here
1. **Goal** — one sentence: what you'll understand after this sitting.
2. **Touches** — exact files to open (copy-paste paths).
3. **How it works today** — current behavior, traced end to end.
4. **Guided tasks** — ordered, smallest-first edits. Do them, don't skip.
5. **Stretch** — only if the guided tasks felt easy.
6. **Verify** — build/test/tap-through command.

## Rules
- One file per sitting. Close other tabs.
- Keep a scratch branch per case OR batch 3–4 related cases per branch (see `02-git-*`).
  Never code on `main`.
- Each sitting ends with `assembleDebug` or `testDebugUnitTest`. No exceptions.
- If stuck >45 min: write what you tried in the PR description, move to next file.

## Your 8-week pace
- Week 1: `00/` + `10/` (orientation + C++ core).
- Week 2: `20/` (Java foundations + unit tests).
- Week 3–4: `30/` + `50/` (cleaner + viewing).
- Week 5: `60/` + `70/` (transfer + UI rethink).
- Week 6: `80/` (Zig via CMake) + `100/` (libs).
- Week 7–8: `90/` (system design reads) + unique differentiators, polish PRs.

## Verify
- [ ] You can name the bridge rule: Java passes paths, C++ writes files, JNI returns `{status,path}`.
- [ ] You know the two test commands by heart.

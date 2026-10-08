# 61 — Upload protocol: `/upload` tokens + space-in-filename fix

## Goal
Understand the wire format so renames never break uploads.

## Touches
- `network/NetworkManager.java` (upload builder), `network/NetworkManagerTest.java` (3 tests for sanitize, B3)
- `utils/TextSanitizer.java` (token shaping, phone-side only — local file untouched)
- `core/Config.java` (HOST/PORT), PC side (other repo/branch — guess in 64)

## How it works today
- B3 bug: space in filename broke `/upload` token. Fix: protocol token sanitized (builder pure + 3 unit tests), local file untouched. PC side untouched.
- Uploads sequential (one-by-one), per-file status in queue file.

## Guided tasks
1. Read upload builder + its 3 tests. What exactly is sanitized (spaces? slashes? unicode? length?)? List.
2. Add tests: `a b.txt`, `a/b.txt` (path sep!), `ünïcode✓.mp4`, 255-char name, empty. Fix builder until green WITHOUT touching local file.
3. Resume? (No.) Spec `Content-Range`-style resume header as proposal only — needs PC cooperation (64). Write the header sketch.
4. Checksum? Spec `X-File-Sha64: <xxhash>` trailer for PC verify (needs 31 hashing). Proposal only here; implement hash first.

## Stretch
- Chunked upload (1MB parts + manifest) for flaky hotspot? Design manifest JSON, don't build.

## Verify
- [ ] New token tests green; real upload of `space name (1).mp4` succeeds; local name unchanged.

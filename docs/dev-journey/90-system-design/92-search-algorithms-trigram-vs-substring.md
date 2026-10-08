# 92 — Search algos: substring today, trigram/FTS when typos matter

## Goal
Know when `ascii_lower + find` stops being enough.

## Touches
- Native: `storage/modules/search/src/file_search.cpp`, `storage/index.hpp` search fns
- Java: `FileSearcher.java` (scoped), Transfer Search tab (global), debounce/busy (28/67)
- Core: `ascii_lower` (10), `json::escape` (11)

## How it works today
Case-folded substring on names (probably). Fast, predictable, no ranking. Debounced typing, single-retry on busy.

## Read (then come back)
- SQLite FTS5 docs (tokenizers, `trigram` tokenizer for substring+typo) + Postgres `pg_trgm` similarity concept.
- Ranking basics: TF-ish (name match > path match), recency boost, exact > prefix > substring.

## Guided tasks
1. Failure list: typos (`vacatoin` vs `vacation`), accents (`café`), middle-token (`IMG_2024_beach` query `beach` — works? rank?). Collect 20 real queries + expected top hit.
2. v1 (no lib): normalize (lower + strip accents? `Normalizer` Java-side or ASCII-fold native?) + token-split on `_- .` + all-tokens-must-match + rank (name>path, newer first?). Implement + test on the 20.
3. v2 (ONLY if v1 typo cases still fail): trigram index (SQLite FTS5 `trigram` OR hand trigram map in native?). Prototype on index file, measure size + query ms (see 91 numbers).
4. UX: highlight matched substring in rows (adapter span), show "stale index" header (67) when global.

## Stretch
- Pinyin/initials? Only if your users need it — ask, don't assume. Park otherwise.

## Verify
- [ ] 20-query suite green; ranking documented; trigram decision with size/speed numbers.

# 73 — HomeFragment: storage summary + shortcuts (dashboard, not dump)

## Goal
Home answers in 3 seconds: space OK? what's new? where to go?

## Touches
- `app/src/main/java/com/example/wayer/ui/HomeFragment.java`, `res/layout/fragment_home.xml`
- `bridge/Stats.java` (shared snapshot), morning-scan summary (40), notification digest (41)

## How it works today
Storage summary (shared snapshot file), shortcuts into other tabs.

## Guided tasks
1. Cards: [Space: X free of Y + mini bar] [Morning scan: ... -> Review] [Quick: Files/Transfer/Cleaner shortcuts] [Recent transfers: last 3]. Max 4 cards — delete the rest.
2. Shortcuts deep-link to TABS + FILTERS (e.g. "Review dups" -> Cleaner Duplicates tab, not just Cleaner home). Implement tab+filter extras.
3. Empty/first-run: no snapshot yet -> [Scan storage] CTA (BUILD_INDEX + stats), not blank numbers.
4. Refresh affordance: pull-to-refresh? Or auto on resume if stale >1h? Pick one, keep lease/busy rules (26).

## Stretch
- Weekly digest card ("freed 2.1GB, 3 dup groups left")? Needs history (66/71). Spec data source.

## Verify
- [ ] Cold start shows useful CTA; warm start <1s from snapshot; shortcuts land on right tab+filter.

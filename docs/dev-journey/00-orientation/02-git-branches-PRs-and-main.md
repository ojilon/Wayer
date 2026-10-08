# 02 — Git: branches, PRs, and "will main get these docs?"

## Goal
Answer your exact question and set a 2-month branching discipline.

## Short answer
Local `main` gets these docs ONLY after you merge/pull. Creating them on branch
`docs/dev-journey` does not change `main` until:

```powershell
# option A: merge on GitHub then sync
git checkout main
git pull origin main        # brings merged PR content into local main

# option B: merge locally
git checkout main
git merge docs/dev-journey
```

Checking out main without merging/pulling shows the OLD main (no docs). That's normal.

## Touches
- `.github/workflows/` (CI runs `:app:testDebugUnitTest` on PRs)
- `git log --oneline -10`, `git status`, `git branch -a`

## Guided tasks
1. Create the docs branch NOW:
   ```powershell
   git checkout -b docs/dev-journey
   git add docs/dev-journey
   git commit -m "docs: dev journey guided tour (batch 1)"
   git push -u origin docs/dev-journey
   ```
2. Open a Draft PR. Keep it open while you add batches, or split per folder
   (`docs-journey-cpp`, `docs-journey-cleaner`, ...). Small PRs review better.
3. Per-case coding rule (your choice, both fine):
   - **Option 1 (recommended):** one branch per THEME (`feat/duplicates-realistic`,
     `feat/morning-scan`), batch 2–4 md cases per branch.
   - **Option 2:** one branch per md file — cleanest history, most branches.
   Don't create 78 branches; group by folder.
4. Before each PR: `git status`, `./gradlew :app:testDebugUnitTest`, `assembleDebug`.

## Stretch
- Add `gh pr checks --watch` to your loop (GitHub CLI).

## Verify
- [ ] `git branch` shows you are NOT on main while writing.
- [ ] You can explain why `git checkout main` hides the docs until pull/merge.

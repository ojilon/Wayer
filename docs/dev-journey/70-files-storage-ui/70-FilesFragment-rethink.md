# 70 — FilesFragment rethink (normal managers aren't the target — better is)

## Goal
Your note: "normal file managers are like that, needs a rethink + improving." Design better, not same.

## Touches
- `app/src/main/java/com/example/wayer/ui/FilesFragment.java`, `res/layout/fragment_files.xml`, `item_file.xml`
- `storage/FileNavigator.java`, `storage/FileSearcher.java`, `ui/BrowseSession.java`, `ui/FileAdapter.java`, `ui/FileOpenHelper.java`
- `docs/XML_UI_GUIDE.md`, `docs/HOME_AND_FILES.md`

## How it works today
Browse (remembers folder + Up), live scoped search, create/rename/delete, open image/video/document. Session memory via BrowseSession (C1). Flat rows (D1).

## Rethink directions (pick, don't do all)
1. **Command bar, not hamburger soup:** primary row [Search][Sort][Select][New▾][Paste?] always visible; overflow only for rare. Sort: name/size/date/type (persist choice).
2. **Selection-first:** tap selects (checkbox), second tap opens? Or classic tap-opens? PICK ONE per user test — document + never mix. Bulk bar appears on select (Send/Copy/Move/Trash/Delete).
3. **New▾ sheet:** File/Folder/Import-from-Transfer-queue? FAB vs bar button — FAB hides on scroll; bar never hides. Prefer bar (see XML guide FAB note).
4. **Inline rename:** long-press -> row becomes EditText (save/cancel), not a dialog. Fewer taps, fewer dialogs.
5. **Drag?** NO (touch + accessibility cost). Cut/paste bar instead (see 57 paste-bar).
6. **Recents + Pinned:** header chips [Recents][Pinned] above list (prefs-backed, max 10). Solves deep-tree pain without changing browse.

## Guided tasks
1. Implement sort (name/size/date/type asc/desc) with persisted pref — smallest rethink slice with big feel.
2. Implement selection bulk bar (reuse Transfer checkbox pattern). Trash-backed delete (39) from here too.
3. Breadcrumbs (55) + copy-path here, not elsewhere first.

## Stretch
- Dual-pane on tablets (list + preview)? Layout-sw600dp only. Spec, don't build on phone.

## Verify
- [ ] Sort persists; bulk actions work; rotation keeps selection+folder; no dialog spam.

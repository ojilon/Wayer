# storage/modules/organizer

**Target:** `wayer_storage_organizer` (currently INTERFACE)

## Migrate

1. Move `file_organizer.cpp/.hpp` into this module.
2. STATIC library; parent links it.
3. Keep pipe-delimited `apply_organize` until JSON parser exists (flags.md).

## Improvements

- Do not auto-move images/DCIM without explicit design (flags.md)
- Invalidate storage cache after successful apply
- Test collision `_dup` behavior on real trees before defaulting on

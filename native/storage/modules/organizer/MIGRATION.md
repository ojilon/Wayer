# storage/modules/organizer

**Target:** `wayer_storage_organizer` (STATIC)

## Migrate — done

1. [x] `file_organizer.cpp` lives in this module; API in `include/wayer/storage/organizer.hpp`
2. [x] STATIC library; parent links it
3. [x] Pipe-delimited `apply_organize` kept until JSON parser exists (flags.md)

## Improvements

- Do not auto-move images/DCIM without explicit design (flags.md)
- Invalidate storage cache after successful apply
- Test collision `_dup` behavior on real trees before defaulting on

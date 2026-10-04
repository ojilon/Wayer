# preview — read-only document/text preview

**CMake target:** `wayer_preview`
**Depends on:** `wayer_core` only (json helpers)
**Used by:** `jni` (action 19 `READ_TEXT_FILE`) → `DocumentActivity`

## Purpose

First consumer of the future rendering scaffold: let the in-app viewer read
text-like files (logs, index JSON, markdown, stats snapshots) without loading
whole files into Java and without dumping binary.

## Rules

- READ ONLY. No writes, deletes, renames — now or later in this module.
- Byte budget enforced in C++ (default 64 KiB, hard cap 256 KiB).
- Binary sniffed by NUL byte → metadata only, content withheld.
- Heavy rendering/editing later wraps third_party engines; this module stays
  the plain-text path.

## Agent checklist

- [x] Sources under src/ + public include
- [x] Links only core
- [x] JNI only calls into this module from `jni/`

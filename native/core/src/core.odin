// =============================================================================
// core.odin — package facade for wayer_core's foundation layer.
//
// This file is the public surface of package core_heart (native/core/src/).
// All procedures defined in sibling files (json_util.odin, paths.odin,
// logging.odin, text.odin) share this package, so they are automatically
// visible as core_heart.<proc> when imported by wayer_core.odin.
//
// Why this file exists
//   * Documents the package's role for new contributors.
//   * Provides a single place to bump the module version.
//   * No re-exports needed — Odin shares same-package symbols implicitly.
//
// Android 10 note
//   Odin code in this package must never call core:os file ops directly.
//   File I/O goes through the C wrappers in android_fs.c (bionic-safe:
//   opendir/readdir/stat/open only, no statx which Android 10 seccomp blocks).
//   Logging uses __android_log_print when ODIN_OS == .Android.
// =============================================================================

package core_heart

// Module version — bump when the file layout under <root>/wayer changes.
CORE_VERSION :: 1

// All symbols are defined in sibling files:
//   json_util.odin  → json_escape, bool_to_string
//   paths.odin      → AppPaths, ensure_app_dirs, write_paths_manifest, set_app_paths, ...
//   logging.odin    → info, error, infof, errorf, log
//   text.odin       → ascii_lower, write_text_file
//
// They are automatically part of package core_heart; no `import` or alias
// is required inside the same package.

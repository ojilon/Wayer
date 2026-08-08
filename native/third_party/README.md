# native/third_party

Place **external C++ libraries** here (headers + static/shared libs).

## Why this folder

- Document rendering, advanced image/video decode, etc. will need third-party code.
- Binaries and large source trees must **not** be committed to Git.
- The folder lives under `native/` so every branch sees the same local path when you switch branches on this machine.

## Git rules

`.gitignore` ignores everything under `native/third_party/` **except** this README (and optional `.gitkeep`).

When you merge to `main`, collaborators install the same libs into this path on their machines (or via a future setup script).

## Suggested layout

```text
native/third_party/
  README.md          ← tracked
  .gitkeep           ← optional, tracked
  mupdf/             ← example, ignored
  ffmpeg/            ← example, ignored
  ...
```

## CMake (later)

When you pick a library, link it from `native/CMakeLists.txt`, for example:

```cmake
target_include_directories(wayer_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mupdf/include
)
target_link_libraries(wayer_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mupdf/lib/libmupdf.a
)
```

Do **not** add library includes to C++ until the libs are installed locally.

## Document / media pipeline

| Kind | Current Java viewer | Future C++ |
|------|---------------------|------------|
| Images | `ImageActivity` (BitmapFactory) | optional decode via third_party |
| Video | `VideoActivity` (VideoView) | optional ffmpeg path |
| Documents | `DocumentActivity` placeholder | mupdf / similar in `documents/` |

Java stays responsible for the window; C++ returns pixels / pages / text as bulk data when ready.

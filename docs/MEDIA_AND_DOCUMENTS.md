# Media & document viewers

How opening a file chooses a full-window Activity, and how C++ / third_party fits later.

---

## Open path

```
FilesFragment (tap file)
    → FileOpenHelper.open(context, path)
        → .jpg/.png/...  → ImageActivity
        → .mp4/.mkv/...  → VideoActivity
        → everything else → DocumentActivity
```

Same helper is used from long-press **Open file**.

---

## ImageActivity

| Piece | Role |
|-------|------|
| `activity_image.xml` | Toolbar, path, ImageView |
| `ImageActivity.java` | Downsamples with `BitmapFactory`, shows image |

Works offline for common still formats. No C++ required yet.

---

## VideoActivity

| Piece | Role |
|-------|------|
| `activity_video.xml` | Toolbar, path, VideoView |
| `VideoActivity.java` | `VideoView` + `MediaController`, plays local URI |

Device codecs decide what plays. Advanced decoding can move to C++ + `native/third_party` later.

---

## DocumentActivity

| Piece | Role |
|-------|------|
| `activity_document.xml` | Toolbar, path, placeholder container |
| `DocumentActivity.java` | Receives path; placeholder until libraries chosen |
| `native/documents/` | Future C++ document engine |

**Do not** add document libraries to C++ until they live under `native/third_party/` (see that README).

---

## Manifest

All three activities are registered, `exported="false"`, theme `Theme.Wayer`.

---

## third_party

Install heavy libs only under:

```text
native/third_party/
```

Git ignores the binaries; the README stays tracked. Switching branches on the same machine keeps the libs in place.

---

## Template C++ (documents – no external includes yet)

`native/documents/document_engine.hpp` already exposes:

```cpp
namespace wayer::documents {
    std::string filter_documents(std::string_view path);
}
```

When you pick a library:

1. Put it in `native/third_party/<name>/`
2. Link from `native/CMakeLists.txt`
3. Add an Action ID in `wayer_engine.cpp` (e.g. open document → return page count / text / base64 preview)
4. Call from `DocumentActivity` via `NativeEngine.processActionAsync`

Until then, DocumentActivity only shows the path and placeholder text.

---

## Learning points

1. One helper (`FileOpenHelper`) decides the viewer — do not scatter extension checks.
2. Viewers are full Activities so they take over the whole window (as designed).
3. Image/video work in pure Java first; documents wait on libraries.
4. Never commit third_party blobs; only the install path is shared by convention.

# Android protocol v2 download (experimental)

The Transfer tab defaults to “Try v2 downloads”. Uncheck it to use the unchanged
v1 `/ask` path. Uploads (including queues) always use v1 `/upload`. A failed v2
hello falls back to v1 on a fresh connection; once hello succeeds, errors do
**not** trigger a retry, avoiding duplicate or unexpected transfers.

A v2 download opens a control connection for the operation, sends a query and
supports the PC's inline file or numbered matches/pick. The match dialog has a
115-second selection timeout; cancel sends abort. It sends pings, answers pings,
checks any advertised SHA-256, saves via a temporary file, and keeps existing
files on name collisions. The Network status displays whether this temporary
control connection is linked. The stable device ID is stored in application
preferences. Transfer progress is shown in the existing transfer hint.

This is not a complete v2 client: the control connection is not persistent
between operations; PC-initiated requests, data sockets, upload resume, offers,
and manifests/sync are not implemented. Uploads and all other legacy operations
continue to use v1. In particular, this download path handles the inline query
response used by the referenced PC branch, not a future data-connection response.

To test, use a PC running `refactor02/improve_ui` with matching host/port in
`Config.java`, enable v2, search for a filename from Transfer, and select a
match if prompted. Disable v2 on the PC (or uncheck the option on Android) to
exercise v1. `ProtocolV2Test` covers framing, unsafe names and an inline
query/pick/download against a loopback server.

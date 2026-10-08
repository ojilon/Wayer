# 64 — Guessing the OTHER side: how WayerPC server should improve with you

## Goal
Your explicit ask: "will involve you guessing how the other app server would — include suggestions on how the other side also improves."

## Touches (phone side you own)
- `network/NetworkManager.java`, `core/Config.java` (HOST/PORT), `transfer/*`, `NetworkManagerTest`
- PC side (other branches/`pc-end` — mirror these proposals there)

## Assumed PC today (verify in that repo)
Hotspot server, `/upload` token auth?, flat receive dir, no resume/checksum. Phone sanitizes tokens (61); PC trusts them.

## Proposals for PC (open issues there, implement phone-side compat first)
1. **Handshake v2:** `HELLO {app,version,features:[resume,checksum,chunked]}` -> PC replies caps. Phone degrades gracefully (old PC = no resume, still works). Implement version const in `Config` + `NetworkStatus` display ("PC vX — resume: yes/no").
2. **Resume:** `PUT /upload?offset=N` + `X-File-Id`. PC appends or 416 if mismatch. Phone sends `offset` from PC `HEAD /file?id`. Spec headers both sides; phone stub first.
3. **Checksum confirm:** phone `X-File-Hash: xxh3:abc123` trailer; PC verifies, replies `{ok|hash_mismatch}`; phone marks row `verify_failed` + auto-retry once. Needs 31 hash on phone.
4. **Chunked manifest:** `POST /session {files:[{name,size,hash}]}` -> PC `{session_id, need:[indices]}` (skip existing = dedup across devices!). Then parts. Big win for re-sends.
5. **Discovery:** UDP beacon `WAYER-PC:<port>:<name>` on hotspot subnet; phone listens, lists PCs (see 65). PC toggle "visible".
6. **Quotas/errors:** PC `413 over_quota`, `507 disk_full`, `409 exists` with JSON `{code,message,path}` — phone maps to row error + action ([Free space] hint?). Standardize codes doc shared by both repos.
7. **TLS?** Hotspot WPA2 already encrypts L2; document threat model BEFORE adding TLS weight. Proposal: optional PSK QR-pairing (scan PC QR -> PSK) for paranoid mode. Design only.

## Guided tasks
1. Pick ONE (handshake caps display is cheapest): implement phone `HELLO` + UI "PC caps" line. No PC change needed to show "unknown (legacy)".
2. Write the shared `TRANSFER_PROTOCOL.md` draft (endpoints, headers, errors, versions) — put in BOTH repos when PC work starts.

## Verify
- [ ] Legacy PC still works (caps=unknown); new PC advertises; errors map to row messages.

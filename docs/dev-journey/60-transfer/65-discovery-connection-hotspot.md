# 65 — Discovery + connection (hotspot UX that doesn't suck)

## Goal
"Set PC address in Config" is dev-grade. Users need tap-to-find.

## Touches
- `core/Config.java` (HOST/PORT manual), `transfer/NetworkStatus.java`, `network/NetworkManager.java`, `ui/TransferFragment` Network tab
- Permissions: `ACCESS_FINE_LOCATION` (Wi-Fi scan), `NEARBY_WIFI_DEVICES` (Android 13+), hotspot APIs (mostly manual: user enables hotspot)

## How it works today
Manual HOST/PORT. Connection/session/activity/recent live in Network tab.

## Guided tasks
1. Manual flow hardening: validate `host:port` inline (IP/hostname regex + port range), [Test] button (HELLO ping -> latency ms + PC version), remember last 5 (prefs) with nickname.
2. Discovery v1 (no PC change): subnet sweep? mDNS (`_wayer._tcp`)? Document OEM hotspot subnet ranges (192.168.43.x/24 typical). Implement mDNS listener first (cheap, no perms beyond network); sweep only as fallback with big warning (battery + scary).
3. Discovery v2 (needs PC 64.5 beacon): UDP listen, list `name · ip · caps`, tap-to-connect. Spec packet format here.
4. Hotspot guide: Guide tab already static — add OEM steps (Samsung vs Pixel hotspot path) + "keep screen on during transfer" + "disable VPN?" troubleshooter. Test with VPN on/off.

## Stretch
- QR connect: PC shows `wayer://ip:port?psk=...`, phone scans (CameraX? or manual paste first). Spec URI.

## Verify
- [ ] Manual connect <30s for a new user; Test button shows version/latency; discovery lists PC when beacon on.

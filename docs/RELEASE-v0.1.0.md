# Hookah Bros v0.1.0

First playable LAN sandbox prototype for Android ARM64. Download and install `HookahBros-v0.1.0-arm64.apk` on a 64-bit Android device (Android 6 or newer; Android 10 emulator checked). This is a debug-signed prototype, not a Play Store release.

## Included

- Solo play and ENet host/client rooms for up to four players.
- First-person movement, camera, jumping and collision.
- Furnished low-poly lounge with reception, sofas, tables, shelves, lamps, windows, door and comic signs.
- Eight physical objects: bottles, cups, boxes and ashtrays. Pick up with the crosshair, carry and throw.
- Four hookahs: take a hose, use it for smoke, a short original bubbling sound and a cooldown. Other players see the effect.
- Touch joystick, separate look finger and action buttons, pause/resume/main-menu flow.
- Saved camera sensitivity, volume and graphics settings.

## Connecting

Use the same Wi-Fi network. One player selects **Создать комнату • LAN**, then opens the menu to see their local IP. Other players enter that IP and select **Подключиться**. UDP 28765 must be reachable. A fifth player is refused; leaving as host ends the session.

There is no matchmaking, relay or NAT traversal. Connections between unrelated mobile networks are not guaranteed. Host movement and shared physics are authoritative; latency may be visible because client prediction is not implemented.

## Verification and limits

Godot 4.3 import, solo gameplay physics, ray pickup/throw, range and wall collision checks, hookah cooldown/exclusive ownership, simultaneous touch roles, settings persistence, reconnect and host exit are exercised by real-engine tests. Multi-process ENet tests cover movement, item state and smoke replication. Rendered menu/gameplay screenshots and Android emulator screenshots are kept in Actions artifacts.

The downloadable ARM64 APK passes ZIP/resource/engine-library and signature checks. Android install/launch/solo/control/pause/resume tests use a separate **x86_64 export of the same source** in an API 29 emulator. This does not confirm ARM64 execution or performance on a physical phone. No physical-device FPS measurement has been made; stable 30 FPS remains a target.

All geometry, materials and audio are original and procedural. No paid SDKs, accounts, analytics or external servers are required. Settings persist; sandbox progress does not.

# Prototype architecture

- `main.gd`: host/client/offline session orchestration, RPC validation, snapshot transport, item/hose ownership and actions.
- `player.gd`: CharacterBody3D capsule, host-side movement/gravity/collision/jump, local camera and remote interpolation.
- `world.gd`: bounded procedural lounge and static collisions, eight RigidBody3D props, hookahs, local particle/audio events.
- `ui.gd`: menu/HUD, separate multitouch finger ownership, pause/focus resets and persisted settings.

No server or cloud account is needed. ENet host accepts at most three clients. Input and snapshots run at 20 Hz, physics at Godot's default 60 Hz. Channel 1 carries ordered unreliable input, 2 snapshots, 3 reliable actions/events; spawning is reliable. Host computes all player motion with collision and freezes client-side shared physics. Clients never submit world positions. Local clients receive authoritative movement with interpolation rather than prediction; latency is noticeable on slow networks.

RPC action sender is obtained from the connection, never from a client-controlled player ID. Movement vectors and angles must be finite; axes are clamped, pitch bounded, input rate limited and stale input expires. Item/hookah pickup uses a host-side 3 m collision/shape cast with a small touch-friendly radius, ownership is exclusive, actions are rate limited, hookah use has a 2 s cooldown and distance leash. Held props use a collision shape sweep against static geometry; throw impulse uses camera direction. Disconnect releases props and hoses. Snapshot sizes are bounded by the fixed four-player/eight-object world.

No runtime RPC creates user-supplied objects or scenes. There is no internet discovery, host migration, prediction, persistent multiplayer world or anti-DDoS service. Pausing blocks local commands; network and remote players continue. Android focus loss clears fingers and input and opens the pause menu. Game progress is transient; settings use `user://settings.cfg`.

## Validation boundary

Desktop real-engine tests and screenshots exercise code and rendering. Android emulator uses the same source with an x86_64 export to match the host emulator; ARM64 APK is separately exported and inspected. Device thermal behavior, real ARM64 execution, mobile-driver rendering and real-phone multitouch require device validation. CI must fail on exit status or script/engine errors in mandatory runtime logs.

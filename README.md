# Hookah Bros 0.1

Experimental Godot 4 first-person cooperative Android/desktop prototype for up to four players.

Open `project.godot` in Godot 4.3+. Run and choose **Host (LAN)** on one device; other devices join using the host's local IP. UDP 28765 must be reachable. Desktop: WASD, mouse, E. Android: touch controls are experimental.

This is a LAN prototype, **not** internet matchmaking or a verified Android release. A dedicated server, authoritative validation, mobile testing and an export preset are future work.

Run structural tests: `python -m unittest discover -s tests -v`.

## Cloud build and visual verification

GitHub Actions workflows:

- **Godot validation**: Python structural checks, Godot 4.3 import, 60-frame headless boot, and a virtual-display screenshot of the solo scene. When successful, the real Godot screenshot is available as the `hookah-bros-screenshot` workflow artifact.
- **Android APK (experimental)**: attempts a Godot 4.3 Android arm64 debug export and uploads `HookahBros-Android-debug` as a workflow artifact on success. It is a development build, not a Play Store release.

See [Actions](https://github.com/supportkadi-sudo/-/actions). CI configuration is not proof of a successful build: inspect each run's logs and artifacts. Android testing on physical devices and internet matchmaking remain pending.

Solo mode: start the project and press **Play solo (offline)**. On desktop use WASD, mouse and E; on mobile drag the left half to move and right half to look, and use **Pick / Throw**.

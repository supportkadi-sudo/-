# Hookah Bros 0.1

Experimental Godot 4 first-person cooperative Android/desktop prototype for up to four players.

Open `project.godot` in Godot 4.3+. Run and choose **Host (LAN)** on one device; other devices join using the host's local IP. UDP 28765 must be reachable. Desktop: WASD, mouse, E. Android: touch controls are experimental.

This is a LAN prototype, **not** internet matchmaking or a verified Android release. A dedicated server, authoritative validation, mobile testing and an export preset are future work.

Run structural tests: `python -m unittest discover -s tests -v`.

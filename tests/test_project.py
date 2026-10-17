from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ProjectSmokeTests(unittest.TestCase):
    def test_project_and_scene_exist(self):
        self.assertTrue((ROOT / "project.godot").is_file())
        self.assertTrue((ROOT / "scenes/main.tscn").is_file())

    def test_four_player_limit(self):
        text = (ROOT / "scripts/main.gd").read_text()
        self.assertIn("const MAX_PLAYERS := 4", text)
        self.assertIn("peer.create_server(PORT, MAX_PLAYERS - 1)", text)

    def test_solo_mode_and_input_mapping(self):
        text = (ROOT / "scripts/main.gd").read_text()
        self.assertIn("func _solo() -> void:", text)
        self.assertIn("InputMap.add_action(action)", text)
        self.assertIn("KEY_W", text)
        self.assertIn("KEY_E", text)
        self.assertIn("_setup_input()", text)

    def test_cloud_capture_and_android_export(self):
        screenshot = (ROOT / "tests/capture.gd").read_text()
        self.assertIn("SCREENSHOT_OK", screenshot)
        self.assertIn("save_png", screenshot)
        ci = (ROOT / ".github/workflows/smoke.yml").read_text()
        self.assertIn("xvfb-run", ci)
        self.assertIn("actions/upload-artifact@v4", ci)
        android = (ROOT / ".github/workflows/android.yml").read_text()
        self.assertIn("--export-debug Android", android)
        self.assertIn("HookahBros-Android-debug", android)
        self.assertIn('name="Android"', (ROOT / "export_presets.cfg").read_text())

    def test_ci_failure_reporting(self):
        reporter = (ROOT / ".github/workflows/ci-report.yml").read_text()
        self.assertIn("workflow_run:", reporter)
        self.assertIn("issues: write", reporter)
        self.assertIn("gh issue edit", reporter)
        android = (ROOT / ".github/workflows/android.yml").read_text()
        self.assertIn("android-diagnostic-logs", android)
        self.assertIn("diagnostics/export.log", android)
        godot = (ROOT / ".github/workflows/smoke.yml").read_text()
        self.assertIn("godot-diagnostic-logs", godot)

    def test_server_checks(self):
        text = (ROOT / "scripts/main.gd").read_text()
        self.assertIn("multiplayer.get_remote_sender_id()", text)
        self.assertIn("if not multiplayer.is_server():", text)

    def test_core_gameplay_loop_exists(self):
        main = (ROOT / "scripts/main.gd").read_text()
        player = (ROOT / "scripts/player.gd").read_text()
        world = (ROOT / "scripts/world.gd").read_text()
        ui = (ROOT / "scripts/ui.gd").read_text()
        gameplay_test = (ROOT / "tests/gameplay.gd").read_text()
        workflow = (ROOT / ".github/workflows/smoke.yml").read_text()
        self.assertIn('preload("res://scripts/world.gd")', main)
        self.assertIn('preload("res://scripts/ui.gd")', main)
        self.assertIn("func _action", main)
        self.assertIn("func _release", main)
        self.assertIn("func smoke_event", main)
        self.assertIn('"jump":KEY_SPACE', main)
        self.assertIn("jump_pending", player)
        self.assertIn("move_and_slide()", player)
        self.assertIn("func make_hookah", world)
        self.assertIn("func make_prop", world)
        self.assertIn("func toggle_pause", ui)
        self.assertIn('"Бросить"', ui)
        self.assertIn('main._action(1,"interact")', gameplay_test)
        self.assertIn("res://tests/gameplay.gd", workflow)

    def test_android_runtime_gate(self):
        workflow = (ROOT / ".github/workflows/android.yml").read_text()
        configure = (ROOT / "tests/configure_android.gd").read_text()
        self.assertIn("pull_request:", workflow)
        self.assertIn("tests/verify_apk.py", workflow)
        self.assertIn("tests/android_smoke.py", workflow)
        self.assertIn("settings.save()", configure)
        self.assertTrue((ROOT / "tests/android_smoke.py").is_file())
        self.assertTrue((ROOT / "tests/verify_apk.py").is_file())

if __name__ == "__main__":
    unittest.main()

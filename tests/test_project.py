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

    def test_server_checks(self):
        text = (ROOT / "scripts/main.gd").read_text()
        self.assertIn("multiplayer.get_remote_sender_id()", text)
        self.assertIn("if not multiplayer.is_server():", text)

if __name__ == "__main__":
    unittest.main()

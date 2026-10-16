extends SceneTree

# Run under a virtual display, not --headless:
# xvfb-run -a godot --path . --script res://tests/capture.gd
func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var error := change_scene_to_file("res://scenes/main.tscn")
    if error != OK:
        push_error("Unable to open main scene: %s" % error)
        quit(1)
        return
    for frame in range(15):
        await process_frame
    var main := current_scene
    if main == null:
        push_error("Main scene was not loaded")
        quit(1)
        return
    main.call("_solo")
    for frame in range(20):
        await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Viewport screenshot was empty")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    var result := image.save_png("res://artifacts/solo.png")
    if result != OK:
        push_error("Screenshot save failed: %s" % result)
        quit(1)
        return
    print("SCREENSHOT_OK res://artifacts/solo.png")
    quit(0)

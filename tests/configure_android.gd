extends SceneTree

# Run with: godot --headless --editor --path . --script res://tests/configure_android.gd
func _initialize() -> void:
    call_deferred("_configure")

func _configure() -> void:
    var sdk := OS.get_environment("ANDROID_HOME")
    if sdk.is_empty():
        sdk = OS.get_environment("ANDROID_SDK_ROOT")
    var java := OS.get_environment("JAVA_HOME")
    if sdk.is_empty() or java.is_empty():
        push_error("ANDROID_HOME/ANDROID_SDK_ROOT and JAVA_HOME must be configured")
        quit(1)
        return
    var settings := EditorInterface.get_editor_settings()
    settings.set_setting("export/android/android_sdk_path", sdk)
    settings.set_setting("export/android/java_sdk_path", java)
    settings.set_setting("export/android/debug_keystore", OS.get_environment("HOME").path_join(".android/debug.keystore"))
    settings.set_setting("export/android/debug_keystore_user", "androiddebugkey")
    settings.set_setting("export/android/debug_keystore_pass", "android")
    print("ANDROID_EXPORT_SETTINGS_OK sdk=", sdk, " java=", java)
    quit(0)

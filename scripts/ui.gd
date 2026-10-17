extends CanvasLayer
signal solo
signal host
signal join(ip: String)
signal leave
signal action(kind: String)
signal changed

var menu: PanelContainer
var hud: Control
var settings: VBoxContainer
var status: Label
var hint: Label
var ip: LineEdit
var move_axis := Vector2.ZERO
var move_finger := -1
var look_finger := -1
var origin := Vector2.ZERO
var look_delta := Vector2.ZERO
var sensitivity := 1.0
var volume := 0.7
var quality := 1
var playing := false
var paused := false
var joystick: Control
var solo_button: Button
var host_button: Button
var join_button: Button
var exit_button: Button
var jump_button: Button
var pause_button: Button

func _ready() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://settings.cfg") == OK:
        sensitivity = clampf(float(cfg.get_value("controls","sensitivity",1.0)),0.3,3.0)
        volume = clampf(float(cfg.get_value("audio","volume",0.7)),0,1)
        quality = clampi(int(cfg.get_value("graphics","quality",1)),0,1)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    menu = PanelContainer.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    menu.offset_left = -260
    menu.offset_right = 260
    menu.offset_top = -310
    menu.offset_bottom = 310
    root.add_child(menu)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12,0.105,0.085,0.98)
    style.content_margin_left = 30
    style.content_margin_right = 30
    style.content_margin_top = 20
    style.content_margin_bottom = 20
    style.corner_radius_top_left = 18
    style.corner_radius_bottom_right = 18
    menu.add_theme_stylebox_override("panel",style)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",10)
    menu.add_child(column)
    var title := Label.new()
    title.text = "HOOKAH BROS"
    title.add_theme_font_size_override("font_size",36)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "v0.1.0 • Дым коромыслом"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)
    solo_button = button(column,"Играть одному",func():
        if playing:
            toggle_pause()
        else:
            solo.emit())
    host_button = button(column,"Создать комнату • LAN",func(): host.emit())
    ip = LineEdit.new()
    ip.placeholder_text = "IP хоста, например 192.168.1.5"
    ip.text = "127.0.0.1"
    ip.custom_minimum_size.y = 44
    column.add_child(ip)
    join_button = button(column,"Подключиться",func(): join.emit(ip.text.strip_edges()))
    var settings_button := button(column,"Настройки",_toggle_settings)
    settings_button.name = "SettingsButton"
    exit_button = button(column,"Выход",func():
        if playing:
            leave.emit()
        else:
            get_tree().quit())
    settings = VBoxContainer.new()
    settings.visible = false
    column.add_child(settings)
    slider(settings,"Чувствительность",0.3,3.0,sensitivity,func(v): sensitivity=v; save())
    slider(settings,"Громкость",0,1,volume,func(v): volume=v; save())
    var graphics := CheckButton.new()
    graphics.text = "Высокое качество"
    graphics.button_pressed = quality == 1
    graphics.toggled.connect(func(on): quality=int(on); save())
    settings.add_child(graphics)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.text = "До 4 игроков • одна Wi-Fi сеть\nИнтернет требует доступного IP и UDP 28765"
    column.add_child(status)
    hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hud)
    hint = Label.new()
    hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    hint.offset_left = -350
    hint.offset_right = 350
    hint.offset_top = 45
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size",22)
    hud.add_child(hint)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    hud.add_child(cross)
    pause_button = button(hud,"Меню",toggle_pause)
    pause_button.position = Vector2(20,15)
    var buttons := VBoxContainer.new()
    buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    buttons.offset_left = -205
    buttons.offset_right = -25
    buttons.offset_top = -290
    buttons.offset_bottom = -20
    hud.add_child(buttons)
    for pair in [["Прыжок","jump"],["Взять / шланг","interact"],["Бросить","throw"],["Использовать","use"]]:
        var kind: String = pair[1]
        var control := button(buttons,pair[0],func(): action.emit(kind))
        if kind == "jump":
            jump_button=control
    joystick = Control.new()
    joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    joystick.position = Vector2(125,-130)
    joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick.draw.connect(func():
        joystick.draw_circle(Vector2.ZERO,72,Color(0.82,0.74,0.57,0.18))
        joystick.draw_circle(move_axis*48,25,Color(0.82,0.74,0.57,0.55)))
    hud.add_child(joystick)
    set_playing(false)
    get_viewport().size_changed.connect(func(): call_deferred("_debug_layout"))
    save()

func button(parent: Node, text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(140,48)
    b.add_theme_font_size_override("font_size",20)
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func slider(parent: Node, text: String, low: float, high: float, value: float, callback: Callable) -> void:
    var label := Label.new()
    label.text = text
    parent.add_child(label)
    var s := HSlider.new()
    s.min_value=low
    s.max_value=high
    s.step=0.05
    s.value=value
    s.value_changed.connect(callback)
    parent.add_child(s)

func _debug_layout() -> void:
    if not OS.is_debug_build() or DisplayServer.get_name() == "headless":
        return
    var layout := {}
    var screen := get_viewport().get_screen_transform()
    for entry in [["solo",solo_button],["jump",jump_button],["pause",pause_button]]:
        var point: Vector2=screen*entry[1].get_global_rect().get_center()
        layout[entry[0]]=[point.x,point.y]
    print("HB_UI_LAYOUT:",JSON.stringify(layout))

func _toggle_settings() -> void:
    settings.visible = not settings.visible
    var column := menu.get_child(0)
    for child in column.get_children():
        if child == settings or child.get_index() < 2 or child.name == "SettingsButton":
            continue
        child.visible = not settings.visible
    if not settings.visible:
        _refresh_menu()

func _refresh_menu() -> void:
    solo_button.text = "Продолжить" if playing else "Играть одному"
    host_button.visible = not playing
    join_button.visible = not playing
    ip.visible = not playing
    exit_button.text = "В главное меню" if playing else "Выход"

func save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("controls","sensitivity",sensitivity)
    cfg.set_value("audio","volume",volume)
    cfg.set_value("graphics","quality",quality)
    cfg.save("user://settings.cfg")
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
    changed.emit()

func reset_touch() -> void:
    move_finger=-1
    look_finger=-1
    move_axis=Vector2.ZERO
    look_delta=Vector2.ZERO
    if is_instance_valid(joystick):
        joystick.queue_redraw()

func set_playing(value: bool) -> void:
    playing=value
    paused=false
    if settings.visible:
        _toggle_settings()
    _refresh_menu()
    menu.visible=not value
    hud.visible=value
    reset_touch()
    call_deferred("_debug_layout")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value and not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE

func toggle_pause() -> void:
    if not playing:
        return
    paused=not paused
    if paused:
        print("HB_PAUSE_OPEN")
    menu.visible=paused
    reset_touch()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not paused and not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause()
    if event is InputEventScreenTouch and not event.pressed:
        if event.index == move_finger:
            move_finger=-1
            move_axis=Vector2.ZERO
            joystick.queue_redraw()
        if event.index == look_finger:
            look_finger=-1

func _unhandled_input(event: InputEvent) -> void:
    if not playing or paused:
        return
    var size := get_viewport().get_visible_rect().size
    if event is InputEventScreenTouch and event.pressed:
        if event.position.x < size.x*0.43 and event.position.y > size.y*0.4 and move_finger == -1:
            move_finger=event.index
            origin=event.position
            joystick.position=origin
            joystick.queue_redraw()
        elif event.position.x > size.x*0.45 and look_finger == -1:
            look_finger=event.index
    if event is InputEventScreenDrag:
        if event.index == move_finger:
            move_axis=((event.position-origin)/72).limit_length(1)
            joystick.queue_redraw()
        elif event.index == look_finger:
            look_delta+=event.relative

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        reset_touch()
        if playing and not paused:
            toggle_pause()

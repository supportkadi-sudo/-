extends Node3D

const PORT := 28765
const MAX_PLAYERS := 4
const PlayerScript = preload("res://scripts/player.gd")
var players: Dictionary = {}
var status_label: Label
var ip_field: LineEdit
var prop: RigidBody3D
var carried_by := 0
var elapsed := 0.0
var touch_move_id := -1
var touch_origin := Vector2.ZERO

func _ready() -> void:
    _setup_input()
    _build_world()
    _build_ui()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_disconnected)

func _setup_input() -> void:
    var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S, "interact": KEY_E}
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var key := InputEventKey.new()
        key.physical_keycode = keys[action]
        InputMap.action_add_event(action, key)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh.material_override = material
    mesh.position = pos
    add_child(mesh)
    var body := StaticBody3D.new()
    var collision := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    collision.shape = box_shape
    body.position = pos
    body.add_child(collision)
    add_child(body)

func _build_world() -> void:
    _box(Vector3(0,-0.2,0), Vector3(14,0.4,12), Color(0.28,0.25,0.23))
    _box(Vector3(0,2.5,-6), Vector3(14,5,0.3), Color(0.33,0.28,0.24))
    _box(Vector3(-7,2.5,0), Vector3(0.3,5,12), Color(0.33,0.28,0.24))
    _box(Vector3(7,2.5,0), Vector3(0.3,5,12), Color(0.33,0.28,0.24))
    _box(Vector3(0,2.5,6), Vector3(14,5,0.3), Color(0.33,0.28,0.24))
    _box(Vector3(0,0.6,-2), Vector3(3,1.2,0.8), Color(0.3,0.18,0.12))
    var light := OmniLight3D.new()
    light.position = Vector3(0,3.7,0)
    light.light_energy = 2.0
    light.omni_range = 16
    add_child(light)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(0.07,0.07,0.09)
    add_child(env)
    prop = RigidBody3D.new()
    prop.position = Vector3(0,1.7,-2)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3(0.35,0.35,0.35)
    mesh.mesh = cube
    prop.add_child(mesh)
    var collider := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = cube.size
    collider.shape = box_shape
    prop.add_child(collider)
    add_child(prop)
    prop.freeze = true

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var panel := VBoxContainer.new()
    panel.position = Vector2(20,20)
    canvas.add_child(panel)
    status_label = Label.new()
    status_label.text = "Hookah Bros | Offline"
    panel.add_child(status_label)
    ip_field = LineEdit.new()
    ip_field.text = "127.0.0.1"
    ip_field.custom_minimum_size = Vector2(300,45)
    panel.add_child(ip_field)
    var solo := Button.new()
    solo.text = "Play solo (offline)"
    solo.pressed.connect(_solo)
    panel.add_child(solo)
    var host := Button.new()
    host.text = "Host LAN"
    host.pressed.connect(_host)
    panel.add_child(host)
    var join := Button.new()
    join.text = "Join IP"
    join.pressed.connect(_join)
    panel.add_child(join)
    var action := Button.new()
    action.text = "Pick / Throw"
    action.position = Vector2(20,210)
    action.pressed.connect(_request_interact)
    canvas.add_child(action)

func _solo() -> void:
    if multiplayer.has_multiplayer_peer():
        return
    _spawn(1)
    status_label.text = "Solo test | WASD / touch"

func _host() -> void:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, MAX_PLAYERS - 1)
    if error != OK:
        status_label.text = "Host failed: %d" % error
        return
    multiplayer.multiplayer_peer = peer
    _spawn(1)
    status_label.text = "Hosting LAN UDP %d" % PORT

func _join() -> void:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(ip_field.text.strip_edges(), PORT)
    if error != OK:
        status_label.text = "Join failed: %d" % error
        return
    multiplayer.multiplayer_peer = peer
    status_label.text = "Connecting..."

func _on_connected() -> void:
    status_label.text = "Connected"
    _spawn(multiplayer.get_unique_id())

func _on_connection_failed() -> void:
    status_label.text = "Connection failed"
    multiplayer.multiplayer_peer = null

func _on_disconnected() -> void:
    for id in players.keys():
        players[id].queue_free()
    players.clear()
    status_label.text = "Disconnected"
    multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
    if not multiplayer.is_server():
        return
    for existing in players.keys():
        spawn_remote.rpc_id(id, existing)
    spawn_remote.rpc(id)
    _spawn(id)
    if prop != null:
        prop_state.rpc_id(id, prop.global_position, prop.linear_velocity, carried_by)

func _on_peer_disconnected(id: int) -> void:
    if multiplayer.is_server():
        despawn_remote.rpc(id)
    _despawn(id)

func _spawn(id: int) -> void:
    if players.has(id):
        return
    var player: HookahPlayer = PlayerScript.new()
    player.name = "Player_%d" % id
    player.local_control = id == multiplayer.get_unique_id()
    player.position = Vector3((id % 4) * 1.2 - 2.0,0,3)
    add_child(player)
    players[id] = player

func _despawn(id: int) -> void:
    if players.has(id):
        players[id].queue_free()
        players.erase(id)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(id: int) -> void:
    _spawn(id)

@rpc("authority", "call_remote", "reliable")
func despawn_remote(id: int) -> void:
    _despawn(id)

func _process(delta: float) -> void:
    if Input.is_action_just_pressed("interact"):
        _request_interact()
    if not multiplayer.has_multiplayer_peer():
        return
    elapsed += delta
    if elapsed >= 0.05:
        elapsed = 0.0
        var id := multiplayer.get_unique_id()
        if players.has(id):
            var player: HookahPlayer = players[id]
            if multiplayer.is_server():
                state_remote.rpc(id, player.global_position, player.rotation.y, player.camera.rotation.x)
            else:
                submit_state.rpc_id(1, player.global_position, player.rotation.y, player.camera.rotation.x)
        if multiplayer.is_server():
            prop_state.rpc(prop.global_position, prop.linear_velocity, carried_by)

@rpc("any_peer", "call_remote", "unreliable")
func submit_state(pos: Vector3, yaw: float, pitch: float) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    var player: HookahPlayer = players[id]
    if not pos.is_finite() or not is_finite(yaw) or not is_finite(pitch):
        return
    if pos.distance_to(player.global_position) > 3.0 or absf(pitch) > 1.35:
        return
    player.global_position = pos
    player.sync_target = pos
    player.rotation.y = yaw
    player.camera.rotation.x = pitch
    state_remote.rpc(id, pos, yaw, pitch)

@rpc("authority", "call_remote", "unreliable")
func state_remote(id: int, pos: Vector3, yaw: float, pitch: float) -> void:
    if id == multiplayer.get_unique_id() or not players.has(id):
        return
    var player: HookahPlayer = players[id]
    player.sync_target = pos
    player.rotation.y = yaw
    player.camera.rotation.x = pitch

func _request_interact() -> void:
    if not multiplayer.has_multiplayer_peer():
        if players.has(1):
            _interact(1)
        return
    if multiplayer.is_server():
        _interact(1)
    else:
        interact_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func interact_request() -> void:
    if multiplayer.is_server():
        _interact(multiplayer.get_remote_sender_id())

func _interact(id: int) -> void:
    if not players.has(id):
        return
    var player: HookahPlayer = players[id]
    if carried_by == id:
        carried_by = 0
        prop.freeze = false
        prop.linear_velocity = -player.global_transform.basis.z * 5.0 + Vector3.UP * 2.0
    elif carried_by == 0 and player.global_position.distance_to(prop.global_position) < 2.5:
        carried_by = id
        prop.freeze = true

@rpc("authority", "call_remote", "unreliable")
func prop_state(pos: Vector3, vel: Vector3, holder: int) -> void:
    carried_by = holder
    prop.freeze = holder != 0
    prop.global_position = pos
    prop.linear_velocity = vel

func _physics_process(_delta: float) -> void:
    if (multiplayer.is_server() or not multiplayer.has_multiplayer_peer()) and carried_by != 0 and players.has(carried_by):
        var player: HookahPlayer = players[carried_by]
        prop.global_position = player.global_position + Vector3.UP * 1.25 - player.global_transform.basis.z * 0.9

func _input(event: InputEvent) -> void:
    if not OS.has_feature("mobile"):
        return
    var size := get_viewport().get_visible_rect().size
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < size.x * 0.45 and event.position.y > size.y * 0.45:
            touch_move_id = event.index
            touch_origin = event.position
        elif not event.pressed and event.index == touch_move_id:
            touch_move_id = -1
            var id := multiplayer.get_unique_id()
            if players.has(id):
                players[id].movement = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == touch_move_id:
        var id := multiplayer.get_unique_id()
        if players.has(id):
            players[id].movement = ((event.position - touch_origin) / 65.0).limit_length(1.0)

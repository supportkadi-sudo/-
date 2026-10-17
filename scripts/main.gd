extends Node3D

const PORT := 28765
const MAX_PLAYERS := 4
const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world.gd")
const UIScript = preload("res://scripts/ui.gd")
var players: Dictionary = {}
var world: Node3D
var ui: CanvasLayer
var holders: Array[int] = []
var hoses: Dictionary = {}
var cooldowns: Dictionary = {}
var action_times: Dictionary = {}
var input_times: Dictionary = {}
var elapsed := 0.0
var active := false
var connecting := false
var connection_time := 0.0
var jump_pending := false
var session_kind := ""
var smoke_events := 0
var menu_camera: Camera3D

func _ready() -> void:
    _setup_input()
    world = WorldScript.new()
    add_child(world)
    for prop in world.props:
        holders.append(0)
    menu_camera = Camera3D.new()
    menu_camera.position = Vector3(0,2,5)
    add_child(menu_camera)
    menu_camera.current = true
    ui = UIScript.new()
    add_child(ui)
    ui.solo.connect(_solo)
    ui.host.connect(_host)
    ui.join.connect(_join_ip)
    ui.leave.connect(_leave)
    ui.action.connect(_request_action)
    ui.changed.connect(_settings_changed)
    print("HB_MENU_READY")
    _settings_changed()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_disconnected)

func _setup_input() -> void:
    var keys := {"move_left":KEY_A,"move_right":KEY_D,"move_forward":KEY_W,"move_back":KEY_S,"interact":KEY_E,"jump":KEY_SPACE,"throw":KEY_Q,"use":KEY_F,"pause":KEY_ESCAPE}
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var key := InputEventKey.new()
        key.physical_keycode = keys[action]
        InputMap.action_add_event(action,key)

func local_id() -> int:
    return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

func authority() -> bool:
    return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _settings_changed() -> void:
    for p in players.values():
        p.sensitivity = ui.sensitivity*0.0025
    for child in world.get_children():
        if child is OmniLight3D:
            child.visible = ui.quality == 1

func _solo() -> void:
    if active or connecting:
        return
    print("HB_SOLO_READY")
    session_kind="Одиночная игра"
    active=true
    _spawn(1)
    ui.set_playing(true)

func _host() -> void:
    if active or connecting:
        return
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, MAX_PLAYERS - 1)
    if error != OK:
        ui.status.text="Не удалось создать комнату: %d" % error
        return
    multiplayer.multiplayer_peer=peer
    active=true
    session_kind="LAN • UDP %d" % PORT
    _spawn(1)
    ui.set_playing(true)
    var addresses := PackedStringArray()
    for address in IP.get_local_addresses():
        if address.is_valid_ip_address() and not address.contains(":") and not address.begins_with("127."):
            addresses.append(address)
    ui.status.text="IP хоста: "+", ".join(addresses)

func _join() -> void:
    _join_ip(ui.ip.text)

func _join_ip(address: String) -> void:
    if active or connecting:
        return
    if not address.is_valid_ip_address():
        ui.status.text="Введите корректный IP-адрес хоста"
        return
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address,PORT)
    if error != OK:
        ui.status.text="Не удалось подключиться: %d" % error
        return
    multiplayer.multiplayer_peer=peer
    connecting=true
    connection_time=0
    ui.status.text="Подключаемся…"
    for prop in world.props:
        prop.freeze=true

func _on_connected() -> void:
    connecting=false
    active=true
    session_kind="LAN • подключено"
    ui.set_playing(true)

func _on_connection_failed() -> void:
    _leave("Нет соединения: проверьте IP, Wi-Fi и свободные места")

func _on_disconnected() -> void:
    _leave("Хост вышел. Комната закрыта")

func _leave(message: String = "Сессия завершена") -> void:
    active=false
    connecting=false
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer=null
    for p in players.values():
        remove_child(p)
        p.queue_free()
    players.clear()
    hoses.clear()
    cooldowns.clear()
    action_times.clear()
    input_times.clear()
    for i in range(holders.size()):
        holders[i]=0
        var prop: RigidBody3D=world.props[i]
        prop.freeze=false
        prop.linear_velocity=Vector3.ZERO
        prop.angular_velocity=Vector3.ZERO
        prop.position=Vector3(-2.5+float(i%4)*1.5,0.5,1.7)
    jump_pending=false
    menu_camera.current=true
    ui.set_playing(false)
    ui.status.text=message

func _spawn(id: int, spawn_position: Vector3 = Vector3.INF) -> void:
    if players.has(id) or players.size() >= MAX_PLAYERS:
        return
    var p: HookahPlayer=PlayerScript.new()
    p.name="Player_%d" % id
    p.local_control=id==local_id()
    p.authoritative=authority()
    p.position=spawn_position if spawn_position.is_finite() else world.spawns[players.size()]
    add_child(p)
    p.sensitivity=ui.sensitivity*0.0025
    players[id]=p

func _on_peer_connected(id: int) -> void:
    if not multiplayer.is_server() or not active:
        return
    if players.size() >= MAX_PLAYERS:
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    # Choose an actually vacant spawn after a disconnect/rejoin.
    var pos: Vector3=world.spawns[0]
    for candidate in world.spawns:
        var vacant := true
        for p in players.values():
            if p.position.distance_to(candidate) < 0.8:
                vacant=false
        if vacant:
            pos=candidate
            break
    _spawn(id,pos)
    for existing in players:
        spawn_remote.rpc_id(id,existing,players[existing].position)
    for existing in players:
        if existing != 1 and existing != id:
            spawn_remote.rpc_id(existing,id,pos)

func _on_peer_disconnected(id: int) -> void:
    if not active or not authority():
        return
    for i in range(holders.size()):
        if holders[i] == id:
            _release(i,id,false)
    hoses.erase(id)
    action_times.erase(id)
    cooldowns.erase(id)
    input_times.erase(id)
    if players.has(id):
        players[id].queue_free()
        players.erase(id)
    despawn_remote.rpc(id)

@rpc("authority","call_remote","reliable")
func spawn_remote(id: int,pos: Vector3) -> void:
    _spawn(id,pos)

@rpc("authority","call_remote","reliable")
func despawn_remote(id: int) -> void:
    if players.has(id):
        players[id].queue_free()
        players.erase(id)

func _process(delta: float) -> void:
    if connecting:
        connection_time+=delta
        if connection_time > 10:
            _leave("Таймаут: хост недоступен или комната заполнена")
    if not active:
        return
    var id := local_id()
    if players.has(id):
        var p: HookahPlayer=players[id]
        if not ui.paused:
            p.look(ui.look_delta)
            for kind in ["jump","interact","throw","use"]:
                if Input.is_action_just_pressed(kind):
                    _request_action(kind)
        ui.look_delta=Vector2.ZERO
        _update_hint(p)
    elapsed+=delta
    if elapsed < 0.05:
        return
    elapsed=0
    if players.has(id):
        var p: HookahPlayer=players[id]
        var axis: Vector2=Input.get_vector("move_left","move_right","move_forward","move_back")+ui.move_axis
        if ui.paused:
            axis=Vector2.ZERO
            jump_pending=false
        if authority():
            p.accept_input(axis,p.rotation.y,p.camera.rotation.x,jump_pending)
        else:
            submit_input.rpc_id(1,axis.limit_length(1),p.rotation.y,p.camera.rotation.x,jump_pending)
        jump_pending=false
    if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
        var states: Array=[]
        for pid in players:
            var p: HookahPlayer=players[pid]
            states.append([pid,p.position,p.rotation.y,p.camera.rotation.x])
        var objects: Array=[]
        for i in range(world.props.size()):
            var prop: RigidBody3D=world.props[i]
            objects.append([prop.transform,holders[i]])
        snapshot.rpc(states,objects,hoses)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func submit_input(axis: Vector2,yaw: float,pitch: float,jump: bool) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id) or not axis.is_finite() or not is_finite(yaw) or not is_finite(pitch):
        return
    var now := Time.get_ticks_msec()
    if now-int(input_times.get(id,0)) < 25:
        return
    input_times[id]=now
    players[id].accept_input(axis.limit_length(1.0),wrapf(yaw,-PI,PI),clampf(pitch,-1.3,1.3),jump)

@rpc("authority","call_remote","unreliable_ordered",2)
func snapshot(states: Array,objects: Array,hose_states: Dictionary) -> void:
    for state in states:
        if players.has(state[0]):
            var p: HookahPlayer=players[state[0]]
            p.sync_target=state[1]
            p.target_yaw=state[2]
            p.target_pitch=state[3]
    for i in range(mini(objects.size(),world.props.size())):
        var prop: RigidBody3D=world.props[i]
        prop.freeze=true
        prop.transform=objects[i][0]
        holders[i]=objects[i][1]
    hoses=hose_states

func target(p: HookahPlayer) -> Object:
    p.ray.force_raycast_update()
    if p.ray.is_colliding():
        var ray_object := p.ray.get_collider()
        if _is_interactable(ray_object):
            return ray_object

    p.aim_cast.force_shapecast_update()
    var nearest: Object = null
    var nearest_distance := INF
    for index in range(p.aim_cast.get_collision_count()):
        var collider := p.aim_cast.get_collider(index)
        var distance := p.camera.global_position.distance_to(p.aim_cast.get_collision_point(index))
        if distance < nearest_distance:
            nearest = collider
            nearest_distance = distance

    if not _is_interactable(nearest):
        return null
    # Keep nearby walls and furniture authoritative: assistance can widen an
    # object's hit area, but cannot select it through a closer ray obstruction.
    if p.ray.is_colliding() and p.camera.global_position.distance_to(p.ray.get_collision_point()) < nearest_distance - 0.08:
        return null
    return nearest

func _is_interactable(object: Object) -> bool:
    return object is Node and (object.has_meta("prop_index") or object.has_meta("hookah_index"))

func _update_hint(p: HookahPlayer) -> void:
    var text := "%s • %d/4" % [session_kind,players.size()]
    var mobile := OS.has_feature("mobile")
    if holders.has(local_id()):
        text+=" | %s: бросить" % ("Кнопка «Бросить»" if mobile else "Q")
    elif hoses.has(local_id()):
        text+=" | %s: дым • %s: отпустить шланг" % (["«Использовать»", "«Взять / шланг»"] if mobile else ["F", "E"])
    else:
        var object := target(p)
        if object != null:
            if object.has_meta("prop_index"):
                text+=" | %s: взять %s" % (["«Взять / шланг»", str(object.get_meta("title"))] if mobile else ["E", str(object.get_meta("title"))])
            elif object.has_meta("hookah_index"):
                text+=" | %s: использовать кальян" % ("«Взять / шланг»" if mobile else "E")
        elif mobile:
            text+=" | Наведи прицел на предмет"
    ui.hint.text=text

func _request_interact() -> void:
    _request_action("interact")

func _request_action(kind: String) -> void:
    if not active or ui.paused:
        return
    if kind == "jump":
        print("HB_JUMP_REQUEST")
        jump_pending=true
    elif authority():
        _action(local_id(),kind)
    else:
        action_request.rpc_id(1,kind)

@rpc("any_peer","call_remote","reliable",3)
func action_request(kind: String) -> void:
    if multiplayer.is_server():
        _action(multiplayer.get_remote_sender_id(),kind)

func _action(id: int,kind: String) -> bool:
    if not players.has(id) or kind not in ["interact","throw","use"]:
        return false
    var now := Time.get_ticks_msec()
    if now-int(action_times.get(id,-1000)) < 180:
        return false
    action_times[id]=now
    var p: HookahPlayer=players[id]
    if kind == "throw":
        var index := holders.find(id)
        if index >= 0:
            _release(index,id,true)
            return true
        return false
    if kind == "use" and hoses.has(id):
        var hookah: StaticBody3D=world.hookahs[int(hoses[id])]
        if p.position.distance_to(hookah.position) > 3.0:
            hoses.erase(id)
            return false
        if now-int(cooldowns.get(id,-3000)) < 2000:
            return false
        cooldowns[id]=now
        var pos: Vector3=p.camera.global_position-p.camera.global_basis.z*0.5
        smoke_event(pos,id)
        if multiplayer.has_multiplayer_peer():
            smoke_event.rpc(pos,id)
        return true
    if kind != "interact":
        return false
    if hoses.has(id):
        hoses.erase(id)
        return true
    if holders.has(id):
        return false
    var object := target(p)
    if object == null:
        return false
    if object.has_meta("prop_index"):
        var index: int=object.get_meta("prop_index")
        if holders[index] != 0:
            return false
        holders[index]=id
        object.freeze=true
        return true
    if object.has_meta("hookah_index"):
        var index: int=object.get_meta("hookah_index")
        if hoses.values().has(index):
            return false
        hoses[id]=index
        return true
    return false

func _release(index: int,id: int,thrown: bool) -> void:
    var prop: RigidBody3D=world.props[index]
    holders[index]=0
    prop.freeze=false
    if players.has(id):
        prop.linear_velocity=-players[id].camera.global_basis.z*(6.0 if thrown else 0.0)+Vector3.UP
    else:
        prop.linear_velocity=Vector3.ZERO
    prop.angular_velocity=Vector3(1,2,0) if thrown else Vector3.ZERO

func _physics_process(_delta: float) -> void:
    if not authority():
        return
    for i in range(world.props.size()):
        var prop: RigidBody3D=world.props[i]
        if holders[i] != 0 and players.has(holders[i]):
            var p: HookahPlayer=players[holders[i]]
            var start := p.camera.global_position
            var end := start-p.camera.global_basis.z*0.9
            # Sweep the entire held object's box; stop before walls and furniture.
            var query := PhysicsShapeQueryParameters3D.new()
            query.shape=prop.get_child(prop.get_child_count()-1).shape
            query.transform=Transform3D(Basis.IDENTITY,start)
            query.motion=end-start
            query.collision_mask=1
            var fractions := get_world_3d().direct_space_state.cast_motion(query)
            var fraction := fractions[0] if not fractions.is_empty() else 0.0
            prop.global_position=start+(end-start)*maxf(0,fraction-0.05)
            prop.rotation=Vector3.ZERO
        elif prop.position.y < -3:
            prop.position=Vector3(0,1,1)
            prop.linear_velocity=Vector3.ZERO
        if prop.linear_velocity.length() > 12:
            prop.linear_velocity=prop.linear_velocity.limit_length(12)
    for id in hoses.keys():
        if not players.has(id) or players[id].position.distance_to(world.hookahs[int(hoses[id])].position)>3:
            hoses.erase(id)

@rpc("authority","call_remote","reliable",3)
func smoke_event(pos: Vector3,id: int) -> void:
    smoke_events+=1
    world.smoke(pos)
    if players.has(id):
        var p: HookahPlayer=players[id]
        var tween := create_tween()
        tween.tween_property(p.camera,"fov",78.0,0.15)
        tween.tween_property(p.camera,"fov",75.0,0.3)

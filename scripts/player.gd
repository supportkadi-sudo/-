extends CharacterBody3D
class_name HookahPlayer

const SPEED := 4.2
const GRAVITY := 18.0
var local_control := false
var authoritative := true
var movement := Vector2.ZERO
var camera: Camera3D
var ray: RayCast3D
var sync_target := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var jump_pending := false
var sensitivity := 0.0025
var input_age := 0.0
var avatar: MeshInstance3D
var step_time := 0.0

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.7
    collider.shape = capsule
    collider.position.y = 0.85
    add_child(collider)
    avatar = MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.32
    mesh.height = 1.7
    avatar.position.y = 0.85
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.from_hsv(float(get_index() % 4) / 4.0, 0.45, 0.75)
    mesh.material = mat
    if DisplayServer.get_name() != "headless":
        avatar.mesh = mesh
    avatar.visible = not local_control
    add_child(avatar)
    camera = Camera3D.new()
    camera.position.y = 1.55
    camera.near = 0.08
    camera.far = 40.0
    add_child(camera)
    camera.current = local_control
    ray = RayCast3D.new()
    ray.target_position = Vector3(0, 0, -2.5)
    ray.collision_mask = 5
    camera.add_child(ray)
    sync_target = global_position

func look(relative: Vector2) -> void:
    rotation.y = wrapf(rotation.y - relative.x * sensitivity, -PI, PI)
    camera.rotation.x = clampf(camera.rotation.x - relative.y * sensitivity, -1.3, 1.3)

func _unhandled_input(event: InputEvent) -> void:
    if local_control and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        look(event.relative)

func accept_input(axis: Vector2, yaw: float, pitch: float, jump: bool) -> void:
    movement = axis.limit_length(1.0)
    rotation.y = yaw
    camera.rotation.x = clampf(pitch, -1.3, 1.3)
    jump_pending = jump_pending or jump
    input_age = 0.0

func _physics_process(delta: float) -> void:
    if not authoritative:
        global_position = global_position.lerp(sync_target, minf(delta * 16.0, 1.0))
        if not local_control:
            rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 16.0, 1.0))
            camera.rotation.x = target_pitch
        return
    input_age += delta
    if local_control and not OS.has_feature("mobile"):
        movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
        jump_pending = jump_pending or Input.is_action_just_pressed("jump")
    elif input_age > 0.4:
        movement = Vector2.ZERO
    var direction := transform.basis * Vector3(movement.x, 0, movement.y)
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
    if is_on_floor():
        velocity.y = 6.0 if jump_pending else -0.1
    else:
        velocity.y -= GRAVITY * delta
    jump_pending = false
    move_and_slide()
    if global_position.y < -4:
        global_position = Vector3(0, 0.1, 3)
        velocity = Vector3.ZERO
    step_time += delta * Vector2(velocity.x, velocity.z).length()
    avatar.rotation.z = sin(step_time * 3.0) * 0.035

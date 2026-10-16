extends CharacterBody3D
class_name HookahPlayer

const SPEED := 4.2
const GRAVITY := 18.0
var local_control := false
var movement := Vector2.ZERO
var camera: Camera3D
var sync_target := Vector3.ZERO
var touch_look := -1

func _ready() -> void:
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.7
    collider.shape = capsule
    collider.position.y = 0.85
    add_child(collider)
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.32
    mesh.height = 1.7
    body.mesh = mesh
    body.position.y = 0.85
    add_child(body)
    camera = Camera3D.new()
    camera.position.y = 1.55
    add_child(camera)
    camera.current = local_control
    sync_target = global_position
    if local_control and not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if not local_control:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _look(event.relative)
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
            touch_look = event.index
        elif not event.pressed and event.index == touch_look:
            touch_look = -1
    if event is InputEventScreenDrag and event.index == touch_look:
        _look(event.relative)

func _look(delta: Vector2) -> void:
    rotation.y -= delta.x * 0.0025
    camera.rotation.x = clamp(camera.rotation.x - delta.y * 0.0025, -1.35, 1.35)

func _physics_process(delta: float) -> void:
    if not local_control:
        global_position = global_position.lerp(sync_target, min(delta * 12.0, 1.0))
        return
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if OS.has_feature("mobile"):
        input = movement
    var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = -0.1
    move_and_slide()

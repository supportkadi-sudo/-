extends Node3D
# The room uses small CC0 glTF/FBX props; collisions stay deliberately simple.
const SOFA_LONG := preload("res://assets/models/loungeSofaLong.glb")
const COFFEE_TABLE := preload("res://assets/models/tableCoffee.glb")
const COUNTER := preload("res://assets/models/kitchenBar.glb")
const OPEN_SHELF := preload("res://assets/models/bookcaseOpen.glb")
const CEILING_LAMP := preload("res://assets/models/lampSquareCeiling.glb")
const TRASH_CAN := preload("res://assets/models/trashcan.glb")
const PLANT := preload("res://assets/models/pottedPlant.glb")
const BOTTLE := preload("res://assets/models/soda-bottle.glb")
const GLASS := preload("res://assets/models/glass.glb")
const BOX_PROP := preload("res://assets/models/cardboardBoxClosed.glb")
const ASHTRAY := preload("res://assets/models/plate-broken.glb")
const PIZZA_BOX := preload("res://assets/models/pizza-box.glb")
const HOOKAH_MODEL := preload("res://assets/models/hookah_shisha.fbx")
var bubble: AudioStreamWAV
var props: Array[RigidBody3D] = []
var hookahs: Array[StaticBody3D] = []
var spawns := [Vector3(-1.8, 0.1, 3.8), Vector3(-0.6, 0.1, 3.8), Vector3(0.6, 0.1, 3.8), Vector3(1.8, 0.1, 3.8)]

func material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    return mat

func box(pos: Vector3, size: Vector3, color: Color, parent: Node = self, solid: bool = true) -> Node3D:
    var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
    body.position = pos
    parent.add_child(body)
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    if DisplayServer.get_name() != "headless":
        mesh.mesh = shape
    shape.material = material(color)
    body.add_child(mesh)
    if solid:
        var collider := CollisionShape3D.new()
        var collision := BoxShape3D.new()
        collision.size = size
        collider.shape = collision
        body.add_child(collider)
    return body

func add_model(asset: PackedScene, parent: Node3D, center: Vector3, scale: Vector3 = Vector3.ONE, yaw: float = 0.0, local_center: Vector3 = Vector3.ZERO) -> Node3D:
    var instance := asset.instantiate() as Node3D
    instance.scale = scale
    instance.rotation.y = yaw
    instance.position = center - Basis(Vector3.UP, yaw) * (local_center * scale)
    # Keep Kenney's wood and upholstery in the room's muted, worn palette.
    for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := mesh_node as MeshInstance3D
        if mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var original := mesh_instance.get_active_material(surface) as StandardMaterial3D
            if original == null:
                continue
            var material_name := original.resource_name.to_lower()
            var tint := Color.WHITE
            match material_name:
                "carpet": tint = Color(0.34, 0.27, 0.16)
                "wood": tint = Color(0.58, 0.37, 0.22)
                "wooddark": tint = Color(0.36, 0.21, 0.12)
                "metal": tint = Color(0.65, 0.62, 0.53)
            if tint != Color.WHITE:
                var adjusted := original.duplicate() as StandardMaterial3D
                adjusted.albedo_color = tint
                mesh_instance.set_surface_override_material(surface, adjusted)
    parent.add_child(instance)
    return instance

func static_collision(pos: Vector3, size: Vector3, parent: Node3D = self) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    parent.add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    body.add_child(collider)
    return body

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var mesh := MeshInstance3D.new()
    var shape := CylinderMesh.new()
    shape.top_radius = radius * 0.8
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = 10
    if DisplayServer.get_name() != "headless":
        mesh.mesh = shape
    mesh.position = pos
    shape.material = material(color)
    parent.add_child(mesh)

func sign_at(text: String, pos: Vector3, font_size: int = 44) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var label := Label3D.new()
    label.text = text
    label.position = pos
    label.font_size = font_size
    label.pixel_size = 0.009
    label.modulate = Color(0.94, 0.83, 0.61)
    add_child(label)

func _ready() -> void:
    bubble = AudioStreamWAV.new()
    bubble.format = AudioStreamWAV.FORMAT_16_BITS
    bubble.mix_rate = 22050
    var audio := PackedByteArray()
    audio.resize(22050)
    for i in range(11025):
        var t := float(i)/22050.0
        var envelope := sin(PI*float(i)/11025.0)
        var wave := sin(TAU*(140.0*t+sin(t*35.0)*0.7))*sin(t*70.0)
        var sample := int(wave*envelope*3800.0)
        audio.encode_s16(i*2,sample)
    bubble.data=audio
    var brown := Color(0.31, 0.19, 0.12)
    var wall := Color(0.47, 0.38, 0.28)
    box(Vector3(0,-0.2,0), Vector3(14,0.4,12), Color(0.30,0.25,0.19))
    box(Vector3(0,2.2,-6), Vector3(14,4.4,0.3), wall)
    box(Vector3(0,2.2,6), Vector3(14,4.4,0.3), wall)
    for x in [-7,7]:
        box(Vector3(x,2.2,0),Vector3(0.3,4.4,12),wall)
    box(Vector3(0,4.4,0),Vector3(14,0.2,12),Color(0.20,0.18,0.16))
    # Wood floor strips and scuffs, all decorative geometry without duplicate collisions.
    for z in range(-5,6):
        box(Vector3(0,0.008,z),Vector3(13.6,0.008,0.025),brown,self,false)
    for x in [-4.7,4.7]:
        for z in [-3.4,1.0]:
            # Kenney sofas face toward the room; invisible boxes preserve stable walking collisions.
            add_model(SOFA_LONG,self,Vector3(x,0,z),Vector3(2.85,2.25,1.35),PI,Vector3(0.49,0,0))
            static_collision(Vector3(x,0.56,z),Vector3(2.75,1.12,1.05))
            add_model(COFFEE_TABLE,self,Vector3(x,0,z-1.25),Vector3(3.0,2.4,2.45),PI,Vector3(-0.13,0,-0.1))
            static_collision(Vector3(x,0.28,z-1.25),Vector3(1.95,0.56,0.86))
            make_hookah(Vector3(x,0.56,z-1.25))
    add_model(COUNTER,self,Vector3(0,0,-4.3),Vector3(8.0,3.4,4.0),0.0,Vector3(0.215,0,-0.105))
    static_collision(Vector3(0,0.68,-4.3),Vector3(3.5,1.36,0.95))
    # One continuous low-poly shelf asset replaces the old pair of floating planks.
    add_model(OPEN_SHELF,self,Vector3(0,2.15,-5.65),Vector3(8.75,1.5,1.4),0.0,Vector3(0.2,0.44,0.125))
    static_collision(Vector3(0,2.15,-5.65),Vector3(3.5,1.35,0.35))
    for y in [1.82,2.48]:
        for x in [-1.2,-0.6,0.0,0.6,1.2]:
            add_model(BOTTLE,self,Vector3(x,y,-5.42),Vector3(0.42,0.42,0.42))
    sign_at("HOOKAH BROS",Vector3(0,3.65,-5.8),64)
    sign_at("ДЫМ ЕСТЬ. WI-FI НЕТ.",Vector3(-4.6,2.7,-5.78),29)
    sign_at("НЕ КИДАЙ В АДМИНА",Vector3(4.4,2.7,-5.78),29)
    box(Vector3(4,1.25,5.8),Vector3(1.3,2.5,0.12),brown)
    box(Vector3(3.5,1.2,5.67),Vector3(0.08,0.08,0.12),Color(0.7,0.6,0.3),self,false)
    for x in [-3,0]:
        box(Vector3(x,2.2,5.78),Vector3(2.3,1.6,0.1),Color(0.18,0.25,0.28),self,false)
        box(Vector3(x,2.2,5.65),Vector3(0.08,1.65,0.08),brown,self,false)
    # Real kit pieces add scale and color without adding expensive dynamic bodies.
    add_model(TRASH_CAN,self,Vector3(5.9,0,4.8),Vector3(1.8,1.5,2.0))
    static_collision(Vector3(5.9,0.35,4.8),Vector3(0.48,0.7,0.48))
    add_model(PLANT,self,Vector3(-6.1,0,4.9),Vector3(3.0,3.0,3.0))
    add_model(PLANT,self,Vector3(6.05,0,0.2),Vector3(2.6,2.6,2.6),PI * 0.5)
    add_model(PIZZA_BOX,self,Vector3(1.0,0.08,-0.7),Vector3(0.48,0.48,0.48),0.12)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(0.15,0.12,0.09)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color(0.95,0.86,0.73)
    env.environment.ambient_light_energy = 0.82
    add_child(env)
    for x in [-3,3]:
        for z in [-2.8,2.6]:
            add_model(CEILING_LAMP,self,Vector3(x,3.84,z),Vector3(2.7,1.2,2.7))
        var light := OmniLight3D.new()
        light.position = Vector3(x,3.55,0.0)
        light.light_color = Color(1,0.82,0.58)
        light.light_energy = 1.6
        light.omni_range = 11
        light.shadow_enabled = false
        add_child(light)
    for i in range(8):
        make_prop(i,Vector3(-2.5 + float(i%4)*1.5,1.7 if i<4 else 0.5,-2.8 if i<4 else 1.7))

func make_prop(index: int, pos: Vector3) -> void:
    var prop := RigidBody3D.new()
    prop.name = "Prop%d" % index
    prop.position = pos
    prop.collision_layer = 4
    prop.collision_mask = 5
    prop.mass = 0.4
    prop.continuous_cd = true
    prop.linear_damp = 0.35
    prop.angular_damp = 0.6
    prop.set_meta("prop_index",index)
    prop.set_meta("title",["Бутылка","Стакан","Коробка","Пепельница"][index%4])
    add_child(prop)
    var sizes := [Vector3(0.18,0.45,0.18),Vector3(0.23,0.28,0.23),Vector3(0.34,0.45,0.34),Vector3(0.32,0.07,0.32)]
    var size: Vector3 = sizes[index%4]
    match index % 4:
        0:
            add_model(BOTTLE,prop,Vector3(0,-size.y*0.5,0),Vector3(1.0,0.78,1.15))
        1:
            add_model(GLASS,prop,Vector3.ZERO,Vector3(1.35,0.98,1.25))
        2:
            add_model(BOX_PROP,prop,Vector3(0,-size.y*0.5,0),Vector3(1.6,1.6,1.6))
        _:
            add_model(ASHTRAY,prop,Vector3.ZERO,Vector3(0.58,0.58,0.58))
    var c := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    c.shape = shape
    prop.add_child(c)
    props.append(prop)

func make_hookah(pos: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    body.set_meta("hookah_index",hookahs.size())
    add_child(body)
    add_model(HOOKAH_MODEL,body,Vector3(0,0,0),Vector3(0.8,0.8,0.8))
    var c := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.42,0.95,0.4)
    c.shape = shape
    c.position.y = 0.45
    body.add_child(c)
    hookahs.append(body)

func smoke(pos: Vector3) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var sound := AudioStreamPlayer3D.new()
    sound.stream=bubble
    sound.position=pos
    sound.unit_size=3.0
    add_child(sound)
    sound.play()
    sound.finished.connect(sound.queue_free)
    var particles := CPUParticles3D.new()
    particles.position = pos
    particles.amount = 14
    particles.one_shot = true
    particles.explosiveness = 0.3
    particles.lifetime = 1.4
    particles.direction = Vector3(0,1,0)
    particles.spread = 35
    particles.gravity = Vector3(0,0.3,0)
    particles.initial_velocity_min = 0.3
    particles.initial_velocity_max = 0.8
    particles.scale_amount_min = 0.05
    particles.scale_amount_max = 0.15
    var mesh := SphereMesh.new()
    mesh.radial_segments = 6
    mesh.rings = 3
    mesh.material = material(Color(0.65,0.63,0.58))
    particles.mesh = mesh
    add_child(particles)
    particles.emitting = true
    get_tree().create_timer(2.5).timeout.connect(particles.queue_free)

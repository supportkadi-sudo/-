extends Node3D
# Procedural original geometry: no external assets or licensing dependencies.
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

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var shape := CylinderMesh.new()
    shape.top_radius = radius * 0.8
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = 10
    mesh.mesh = shape
    mesh.position = pos
    shape.material = material(color)
    parent.add_child(mesh)

func sign_at(text: String, pos: Vector3, font_size: int = 44) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = pos
    label.font_size = font_size
    label.pixel_size = 0.009
    label.modulate = Color(0.94, 0.83, 0.61)
    add_child(label)

func _ready() -> void:
    var brown := Color(0.27, 0.17, 0.12)
    var wall := Color(0.38, 0.31, 0.23)
    box(Vector3(0,-0.2,0), Vector3(14,0.4,12), Color(0.22,0.20,0.17))
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
            box(Vector3(x,0.35,z),Vector3(2.8,0.7,1.1),Color(0.28,0.26,0.17))
            box(Vector3(x,0.90,z+0.45),Vector3(2.8,0.7,0.3),Color(0.34,0.30,0.20))
            for side in [-1,1]:
                box(Vector3(x+side*1.3,0.65,z),Vector3(0.2,0.55,1.1),brown)
            box(Vector3(x,0.78,z-1.25),Vector3(2.0,0.15,0.85),brown)
            box(Vector3(x,0.37,z-1.25),Vector3(0.5,0.74,0.5),brown)
            make_hookah(Vector3(x,0.87,z-1.25))
    box(Vector3(0,0.65,-4.3),Vector3(3.4,1.3,0.9),brown)
    box(Vector3(0,1.34,-4.3),Vector3(3.7,0.1,1.1),Color(0.48,0.39,0.27))
    for y in [1.8,2.7]:
        box(Vector3(0,y,-5.65),Vector3(3.5,0.13,0.45),brown)
        for x in [-1.2,-0.6,0.0,0.6,1.2]:
            cylinder(self,Vector3(x,y+0.27,-5.6),0.09,0.4,Color(0.24,0.35,0.22))
    sign_at("HOOKAH BROS",Vector3(0,3.65,-5.8),64)
    sign_at("ДЫМ ЕСТЬ. WI-FI НЕТ.",Vector3(-4.6,2.7,-5.78),29)
    sign_at("НЕ КИДАЙ В АДМИНА",Vector3(4.4,2.7,-5.78),29)
    box(Vector3(4,1.25,5.8),Vector3(1.3,2.5,0.12),brown)
    box(Vector3(3.5,1.2,5.67),Vector3(0.08,0.08,0.12),Color(0.7,0.6,0.3),self,false)
    for x in [-3,0]:
        box(Vector3(x,2.2,5.78),Vector3(2.3,1.6,0.1),Color(0.18,0.25,0.28),self,false)
        box(Vector3(x,2.2,5.65),Vector3(0.08,1.65,0.08),brown,self,false)
    cylinder(self,Vector3(5.9,0.35,4.8),0.35,0.7,Color(0.16,0.18,0.16))
    box(Vector3(5.9,0.35,4.8),Vector3(0.65,0.7,0.65),Color(0.16,0.18,0.16))
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(0.15,0.12,0.09)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color(0.86,0.75,0.60)
    env.environment.ambient_light_energy = 0.7
    add_child(env)
    for x in [-3,3]:
        cylinder(self,Vector3(x,3.95,-0.5),0.45,0.18,Color(0.70,0.56,0.31))
        var light := OmniLight3D.new()
        light.position = Vector3(x,3.65,-0.5)
        light.light_color = Color(1,0.82,0.58)
        light.light_energy = 1.5
        light.omni_range = 10
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
    var sizes := [Vector3(0.18,0.45,0.18),Vector3(0.23,0.28,0.23),Vector3(0.38,0.32,0.38),Vector3(0.3,0.08,0.3)]
    var size: Vector3 = sizes[index%4]
    if index%4 < 2:
        cylinder(prop,Vector3.ZERO,size.x/2,size.y,Color(0.28,0.43,0.30) if index%4 == 0 else Color(0.65,0.64,0.53))
    else:
        box(Vector3.ZERO,size,Color(0.52,0.36,0.20),prop,false)
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
    cylinder(body,Vector3(0,0.15,0),0.16,0.3,Color(0.20,0.37,0.37))
    cylinder(body,Vector3(0,0.5,0),0.045,0.5,Color(0.58,0.53,0.40))
    cylinder(body,Vector3(0,0.78,0),0.12,0.12,Color(0.30,0.21,0.15))
    box(Vector3(0.22,0.38,0.08),Vector3(0.42,0.045,0.045),Color(0.12,0.11,0.10),body,false)
    var c := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.42,0.95,0.4)
    c.shape = shape
    c.position.y = 0.45
    body.add_child(c)
    hookahs.append(body)

func smoke(pos: Vector3) -> void:
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

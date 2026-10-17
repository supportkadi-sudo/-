extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
    if not condition:
        push_error("TEST_FAILED: "+message)
        failures+=1
    else:
        print("PASS: "+message)

func _initialize() -> void:
    call_deferred("run")

func wait(seconds: float) -> void:
    await create_timer(seconds).timeout

func run() -> void:
    change_scene_to_file("res://scenes/main.tscn")
    for frame in range(5):
        await process_frame
    var main := current_scene
    main._solo()
    await wait(0.8)
    check(main.players.size()==1,"solo creates one player")
    var p: CharacterBody3D=main.players[1]
    check(p.is_on_floor() and absf(p.position.y)<0.15,"spawn and gravity settle on floor")
    # Exercise selection and the same UI signal used by the mobile action button
    # against a prop in its actual room position, with a slight aim offset.
    var room_prop: RigidBody3D=main.world.props[4]
    await wait(1.0)
    p.camera.look_at(room_prop.global_position+Vector3(0.22,0.04,0))
    await physics_frame
    var selected: Object=main.target(p)
    if selected != room_prop:
        print("AIM_DEBUG camera=",p.camera.global_position," prop=",room_prop.global_position," ray_hit=",p.ray.get_collider() if p.ray.is_colliding() else "none"," ray_point=",p.ray.get_collision_point() if p.ray.is_colliding() else Vector3.ZERO," cast_count=",p.aim_cast.get_collision_count())
        for collision in range(p.aim_cast.get_collision_count()):
            var collider: Object=p.aim_cast.get_collider(collision)
            print("AIM_DEBUG cast=",collider.name," interactable=",main._is_interactable(collider)," point=",p.aim_cast.get_collision_point(collision))
    check(selected==room_prop,"touch-friendly aim selects a nearby room prop")
    main._update_hint(p)
    check(main.ui.hint.text.contains("взять Бутылка"),"mobile interaction hint names the target prop")
    main.ui.action.emit("interact")
    check(main.holders[4]==1 and room_prop.freeze,"mobile action signal picks up room prop")
    check(main.ui.hint.text.contains("Q: бросить"),"HUD switches to the throw hint after pickup")
    await wait(0.2)
    main.ui.action.emit("throw")
    check(main.holders[4]==0 and not room_prop.freeze,"mobile action signal throws held prop")
    main.jump_pending=true
    await wait(0.2)
    check(p.position.y>0.4,"jump leaves floor")
    await wait(1)
    check(p.is_on_floor(),"jump lands")
    p.rotation.y=0
    p.camera.rotation=Vector3.ZERO
    # Place a real rigid object on the camera ray; exercise authoritative ray selection.
    var prop: RigidBody3D=main.world.props[0]
    prop.freeze=true
    prop.global_position=p.camera.global_position+Vector3(0,0,-1.2)
    await physics_frame
    check(main._action(1,"interact"),"ray pickup")
    check(main.holders[0]==1,"one owner")
    await wait(0.25)
    check(main._action(1,"throw"),"throw accepted")
    check(main.holders[0]==0 and not prop.freeze,"throw releases physics")
    check(prop.linear_velocity.length()>4,"throw gives impulse")
    await wait(0.25)
    prop.freeze=true
    prop.position=Vector3(0,1,-5)
    p.position=Vector3(0,0,3)
    await physics_frame
    check(not main._action(1,"interact"),"reject distant interaction")
    # Approach first table from front; aim camera directly at hookah body.
    var hookah: StaticBody3D=main.world.hookahs[0]
    p.position=Vector3(hookah.position.x,0,hookah.position.z+1.6)
    p.camera.look_at(hookah.global_position+Vector3(0,0.5,0))
    await wait(0.25)
    check(main._action(1,"interact"),"take hookah hose")
    await wait(0.25)
    check(main._action(1,"use"),"hookah smoke event")
    await wait(0.25)
    check(not main._action(1,"use"),"hookah cooldown")
    # Independent multitouch fingers: movement and look must coexist.
    var left := InputEventScreenTouch.new()
    left.index=0
    left.position=Vector2(120,560)
    left.pressed=true
    main.ui._unhandled_input(left)
    var right := InputEventScreenTouch.new()
    right.index=1
    right.position=Vector2(800,350)
    right.pressed=true
    main.ui._unhandled_input(right)
    var move := InputEventScreenDrag.new()
    move.index=0
    move.position=Vector2(180,560)
    main.ui._unhandled_input(move)
    var look := InputEventScreenDrag.new()
    look.index=1
    look.relative=Vector2(40,10)
    main.ui._unhandled_input(look)
    check(main.ui.move_axis.x>0.5 and main.ui.look_delta.x>0,"multitouch movement and look coexist")
    left.pressed=false
    main.ui._input(left)
    check(main.ui.move_axis==Vector2.ZERO and main.ui.look_finger==1,"release movement preserves look finger")
    main.ui.reset_touch()
    var config := ConfigFile.new()
    check(config.load("user://settings.cfg")==OK,"settings persisted")
    # Physics collision: held item sweeps before a wall; player stays within room bounds.
    p.position=Vector3(0,0,-5.3)
    p.rotation.y=0
    p.camera.rotation=Vector3.ZERO
    main.holders[0]=1
    prop.freeze=true
    await physics_frame
    await physics_frame
    check(prop.position.z>-5.8,"held item stops before wall")
    main.holders[0]=0
    for tick in range(25):
        p.accept_input(Vector2(0,-1),0,0,false)
        await physics_frame
    check(p.position.z>-5.55,"host physics blocks walking through wall")
    main.ui.toggle_pause()
    check(main.ui.paused,"pause opens menu")
    main.ui.reset_touch()
    check(main.ui.move_finger==-1 and main.ui.look_finger==-1,"touch reset")
    main._leave()
    await process_frame
    check(main.players.is_empty() and not main.active and main.ui.menu.visible,"return to menu")
    main._host()
    check(main.active and main.multiplayer.is_server(),"host creates ENet session")
    main._leave()
    main._join_ip("bad ip")
    check(not main.connecting,"invalid IP rejected")
    main._solo()
    check(main.players.size()==1,"session restart")
    main._leave()
    print("GAMEPLAY_RESULT failures=",failures)
    quit(1 if failures else 0)

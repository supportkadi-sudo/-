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
    main.jump_pending=true
    await wait(0.2)
    check(p.position.y>0.4,"jump leaves floor")
    await wait(1)
    check(p.is_on_floor(),"jump lands")
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

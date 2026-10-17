extends SceneTree
var main: Node3D
var failures := 0
var mode := ""
func check(value: bool,message: String) -> void:
    if value:
        print("PASS "+message)
    else:
        push_error("OBJECT_NETWORK_FAILED "+message)
        failures+=1
func _initialize() -> void:
    mode=OS.get_cmdline_user_args()[0]
    call_deferred("run")
func run() -> void:
    change_scene_to_file("res://scenes/main.tscn")
    for i in range(5): await process_frame
    main=current_scene
    if mode=="host":
        main._host()
        # Stable test arrangement: pickup and hookah targets on the client's line of sight.
        main.world.props[0].freeze=true
        main.world.props[0].position=Vector3(-0.6,1.55,2.6)
        var hookah: StaticBody3D=main.world.hookahs[0]
        hookah.position=Vector3(-0.6,0.9,1.5)
        await create_timer(2.6).timeout
        check(main.holders[0]!=0,"server accepts client ray pickup")
        var held_position: Vector3=main.world.props[0].position
        await create_timer(1.8).timeout
        check(main.holders[0]==0,"server accepts client throw")
        check(main.world.props[0].position.distance_to(held_position)>0.7,"host simulates thrown item")
        await create_timer(2.0).timeout
        check(main.smoke_events==1,"server validates client hookah event")
        # Host also attempts use while hose is claimed, and distant item interaction.
        main.players[1].position=Vector3(-0.6,0,3.8)
        main.players[1].camera.rotation=Vector3.ZERO
        check(not main._action(1,"interact"),"second player cannot claim owned hose")
        main._leave()
    else:
        main._join_ip("127.0.0.1")
        await create_timer(1.3).timeout
        check(main.active,"object client connects")
        main._request_action("interact")
        await create_timer(0.7).timeout
        check(main.holders[0]==main.local_id(),"pickup ownership replicated")
        main._request_action("throw")
        await create_timer(1.1).timeout
        check(main.holders[0]==0,"release replicated")
        main._request_action("interact")
        await create_timer(0.6).timeout
        check(main.hoses.has(main.local_id()),"hose ownership replicated")
        main._request_action("use")
        await create_timer(0.5).timeout
        check(main.smoke_events==1,"smoke event replicated")
        main._request_action("use")
        await create_timer(0.5).timeout
        check(main.smoke_events==1,"network cooldown enforced")
        await create_timer(4).timeout
        check(not main.active,"objects session closes cleanly")
    print("OBJECT_NETWORK_RESULT ",mode," ",failures)
    quit(1 if failures else 0)

extends SceneTree
var mode := ""
var main: Node3D
var failures := 0
func _initialize() -> void:
    mode=OS.get_cmdline_user_args()[0]
    call_deferred("run")
func check(value: bool,message: String) -> void:
    if not value:
        push_error("NETWORK_FAILED "+message)
        failures+=1
    else:
        print("PASS "+message)
func run() -> void:
    change_scene_to_file("res://scenes/main.tscn")
    for frame in range(5):
        await process_frame
    main=current_scene
    if mode == "host":
        main._host()
        await create_timer(4).timeout
        check(main.players.size()==4,"host plus three clients")
        # A fifth process must fail admission while room is full.
        await create_timer(3).timeout
        check(main.players.size()==4,"capacity remains four")
        var moved := false
        for id in main.players:
            if id != 1 and main.players[id].position.z < 2.5:
                moved=true
        check(moved,"server simulates client movement")
        await create_timer(2).timeout
        check(main.players.size()==3,"client disconnect removes avatar")
        await create_timer(3).timeout
        check(main.players.size()==4,"client reconnects")
        main._leave()
        print("NETWORK_HOST_RESULT ",failures)
        quit(1 if failures else 0)
    else:
        main._join_ip("127.0.0.1")
        if mode == "overflow":
            await create_timer(3).timeout
            check(not main.active,"fifth player rejected")
            main._leave()
            quit(1 if failures else 0)
            return
        await create_timer(2).timeout
        check(main.active,"client connected")
        check(main.players.size()==4,"client sees four avatars")
        if not main.active or not main.players.has(main.local_id()):
            quit(1)
            return
        main.ui.move_axis=Vector2(0,-1)
        await create_timer(1).timeout
        main.ui.move_axis=Vector2.ZERO
        await create_timer(0.5).timeout
        check(main.players[main.local_id()].position.z<2.5,"authoritative movement replicated")
        check(main.world.props[0].freeze,"client physics remains frozen")
        if mode == "reconnect":
            await create_timer(4).timeout
            main._leave()
            await create_timer(2).timeout
            main._join_ip("127.0.0.1")
            await create_timer(1).timeout
            check(main.active and main.players.has(main.local_id()),"rejoin succeeds")
        await create_timer(10).timeout
        check(not main.active,"host exit returns client to menu")
        print("NETWORK_CLIENT_RESULT ",mode," ",failures)
        quit(1 if failures else 0)

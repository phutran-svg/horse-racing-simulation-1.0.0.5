extends SceneTree
## renders race3d at points in the race (local test tool). args: course dist
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	if args.size() > 2 and args[2] == "noterrain": TrackBuilder.use_terrain3d = false
	AppState.course = args[0] if args.size() > 0 else "tokyo"
	AppState.dist = int(args[1]) if args.size() > 1 else 2400
	AppState.build_field("rand", 16)
	var t0 := Time.get_ticks_msec()
	var sc: Node3D = load("res://race3d/race_3d.tscn").instantiate()
	root.add_child(sc)
	while sc.race == null or sc.loading.visible: await process_frame
	print("build ms ", Time.get_ticks_msec() - t0)
	var tag: String = AppState.course + str(AppState.dist)
	await shot(tag + "_0gate")
	var marks := [6.0, 30.0, 70.0]
	var r = sc.race
	var D: int = r.opts.dist
	sc.running = false
	var plan := [[2.0, -1, "1start"], [D * 0.25 / 16.0, 3, "2blimp"], [-1.0, 1, "3side"], [-2.0, 2, "4headon"], [-3.0, 1, "5final"], [-4.0, 4, "6follow"]]
	for p in plan:
		var target: float = p[0]
		while not r.done:
			var L = RaceCommentary.standings(r)[0]
			var rem: float = D - L.dist
			var ok := false
			if target >= 0.0: ok = r.t >= target
			elif target == -1.0: ok = L.dist > D * 0.45
			elif target == -2.0: ok = rem < r.course.finish - 60.0
			elif target == -3.0: ok = rem < 120.0
			elif target == -4.0: ok = r.done or rem < 30.0
			if ok: break
			for x in r.runners:
				sc.prev_d[x.i] = x.dist; sc.prev_l[x.i] = x.lane
			RaceEngine.step(r)
			if not sc.gates_open and r.t > 0.05: sc.gates_open = true; sc.tb.open_gates()
			sc.tb.remove_gates(r.t > 9.0)
		if p[1] >= 0: sc.cam.set_mode(p[1])
		else: sc.cam.set_mode(0)
		sc._place_horses(1.0)
		sc.cam.update_cam(0.0)
		sc._update_hud()
		await shot(tag + "_" + p[2])
	quit()

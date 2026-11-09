extends SceneTree
## career → enter → advance → watch replay in 3D (local test tool)
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "c3d_" + name + ".png")
func _init() -> void:
	root.size = Vector2i(1600, 900)
	await process_frame
	load("res://ui/main.gd").create_career({ "role": "owner", "diff": "normal", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#ec4899", "package": 2 })
	var racer = null
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h.c.status == "active" and int(h.age) >= 3: racer = h
	var rid := -1
	for r in Career.W.races:
		if Career.eligible(racer, r) and Career.enter(int(racer.id), int(r.id)) == "ok": rid = int(r.id); break
	print("entered ", racer.name, " race ", rid)
	Career.advance_week()
	var ids: Array = []
	for k in Career.W.replays: ids.append(k)
	print("replays ", ids)
	Game.mode = "career"
	Game.pending_replay = { "queue": ids }
	var sc: Node3D = load("res://race3d/race_3d.tscn").instantiate()
	root.add_child(sc)
	while sc.race == null or sc.loading.visible: await process_frame
	var r = sc.race
	var D: int = r.opts.dist
	sc.running = false
	sc.gates_open = true; sc.tb.open_gates()
	for side in [0, 1, 2]:
		while not r.done and RaceCommentary.standings(r)[0].dist < D * (0.3 + side * 0.25):
			for x in r.runners: sc.prev_d[x.i] = x.dist; sc.prev_l[x.i] = x.lane
			RaceEngine.step(r)
		sc.tb.remove_gates(r.t > 9.0)
		sc.cam.side = side
		sc.cam.set_mode(CameraDirector.Mode.SIDE)
		sc._place_horses(1.0)
		sc.cam.update_cam(0.0)
		sc._update_hud()
		await shot("side%d" % side)
	while not r.done:
		RaceEngine.step(r)
	sc._update_hud()
	sc._show_results() if sc.has_method("_show_results") else null
	await shot("results")
	quit()

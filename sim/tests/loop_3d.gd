extends SceneTree
func _init() -> void:
	root.size = Vector2i(1280, 720)
	AppState.course = "hanshin"; AppState.dist = 1600
	AppState.build_field("rand", 16)
	var sc: Node3D = load("res://race3d/race_3d.tscn").instantiate()
	root.add_child(sc)
	while sc.race == null or sc.loading.visible: await process_frame
	sc.speed = 4.0
	sc._toggle_play()
	var t0 := Time.get_ticks_msec()
	var shots := {}
	var lines := 0
	var worst := 0
	var last := t0
	var frames := 0
	while not sc.race.done and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last); last = now; frames += 1
		var nm: String = CameraDirector.NAMES[sc.cam.shot]
		if not shots.has(nm): shots[nm] = "%.1f" % sc.race.t
	await process_frame
	print("race done=%s t=%.1f wall=%.1fs frames=%d worst frame %d ms" % [sc.race.done, sc.race.t, (Time.get_ticks_msec() - t0) / 1000.0, frames, worst])
	print("auto camera cuts (first time each shot used, race seconds): ", shots)
	print("commentary lines: ", sc.comm.lines.size(), " last: ", sc.comm.lines[-1].text if sc.comm.lines.size() else "")
	print("results shown: ", sc.results.visible)
	quit()

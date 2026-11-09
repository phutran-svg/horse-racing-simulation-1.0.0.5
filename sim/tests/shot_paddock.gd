extends SceneTree
## paddock pictures: overview from the stand, the ring with walking horses, a close look, the far end
func _init() -> void:
	root.size = Vector2i(1600, 900)
	AppState.course = "tokyo"; AppState.dist = 2400
	AppState.build_field("rand", 16)
	var sc: Node3D = load("res://race3d/race_3d.tscn").instantiate()
	root.add_child(sc)
	while sc.race == null or sc.loading.visible: await process_frame
	sc.hud.visible = false
	var coats := ["bay", "dark bay", "chestnut", "black", "grey", "bay", "chestnut", "dark bay"]
	var pk: Node3D = sc.tb.paddock
	var cam := Camera3D.new(); cam.far = 2000.0; cam.fov = 55.0
	sc.add_child(cam)
	# let them walk a few seconds so the animation and spacing settle
	for i in 30:
		sc._update_paddock(0.1)
		await process_frame
	var P := func(v: Vector3) -> Vector3: return pk.global_transform * v
	var shots := [
		["overview", P.call(Vector3(-62.0, 26.0, -40.0)), P.call(Vector3(0, 0, 0))],
		["stand_side", P.call(Vector3(-10.0, 9.0, -33.0)), P.call(Vector3(8.0, 1.0, 4.0))],
		["ring", P.call(Vector3(-28.0, 4.2, -30.0)), P.call(Vector3(-6.0, 1.2, -17.0))],
		["close", P.call(Vector3(6.0, 2.2, -24.5)), P.call(Vector3(-2.0, 1.3, -17.0))],
		["screen_end", P.call(Vector3(-50.0, 7.0, 8.0)), P.call(Vector3(40.0, 6.0, 0.0))],
		["top", P.call(Vector3(0.0, 95.0, 0.5)), P.call(Vector3(0, 0, 0))],
		["horse_close", Vector3.ZERO, Vector3.ZERO],
		["horse_side", Vector3.ZERO, Vector3.ZERO],
	]
	for s in shots:
		sc.cam.current = false
		cam.current = true
		if s[0] == "horse_close" or s[0] == "horse_side":
			var ph: Node3D = sc.paddock_horses[3 if s[0] == "horse_close" else 6]
			var off := Vector3(-4.5, 1.7, 3.5) if s[0] == "horse_close" else Vector3(-6.5, 1.5, 0.0)
			cam.global_position = ph.global_transform * off
			cam.look_at(ph.global_transform * Vector3(0, 1.1, 0.3), Vector3.UP)
		else:
			cam.global_position = s[1]
			cam.look_at(s[2], Vector3.UP)
		for i in 6:
			if not s[0].begins_with("horse"): sc._update_paddock(0.05)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pk_%s.png" % s[0])
	quit()

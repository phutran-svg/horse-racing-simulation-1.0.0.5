extends SceneTree
## marking test sheet: each face marking (3/4 front view) and leg levels, greys by age (side view)
func _init() -> void:
	root.size = Vector2i(700, 600)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("e9efe7")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.92, 0.95); env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 40, 0); sun.light_energy = 1.1; sun.shadow_enabled = true
	root.add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("7f877c"); fl.material_override = fm
	root.add_child(fl)
	var cam := Camera3D.new(); cam.fov = 22.0
	root.add_child(cam)
	var scene: PackedScene = load(PaddockHorse.MODEL)
	var cases := [
		["star", "bay", [0, 0, 1, 0], 4], ["stripe", "bay", [0, 0, 2, 2], 4], ["star_stripe", "chestnut", [0, 1, 3, 3], 4], ["snip", "dark bay", [0, 0, 0, 1], 4],
		["blaze", "chestnut", [3, 3, 3, 3], 4], ["blaze_snip", "bay", [2, 0, 3, 4], 4], ["bald", "chestnut", [4, 4, 4, 4], 4], ["star", "black", [0, 0, 3, 0], 4],
		["none", "grey", [0, 0, 0, 0], 2], ["none", "grey", [0, 0, 0, 0], 4], ["none", "grey", [0, 0, 0, 0], 6], ["none", "grey", [0, 0, 0, 0], 9],
	]
	var k := 0
	for c in cases:
		var h := { "id": 100 + k, "coat": c[1], "age": c[3], "marks": { "face": c[0], "legs": c[2] } }
		var model: Node3D = scene.instantiate()
		model.scale = Vector3.ONE * PaddockHorse.SCALE
		root.add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var src = mi.get_active_material(0)
			mi.mesh = PaddockHorse.prepared_mesh(mi.mesh)
			if src is StandardMaterial3D: mi.material_override = PaddockHorse.coat_material(src, c[1], h)
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(ap.get_animation_list()[0]); ap.seek(0.25, true); ap.pause()
		if k < 8:
			cam.fov = 13.0
			cam.look_at_from_position(Vector3(2.2, 2.0, 4.9), Vector3(0.05, 1.45, 1.05))
		else:
			cam.fov = 20.0
			cam.look_at_from_position(Vector3(8.5, 1.35, 0.35), Vector3(0, 1.05, 0.2))
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/mk_%02d.png" % k)
		model.queue_free()
		await process_frame
		k += 1
	quit()

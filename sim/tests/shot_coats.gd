extends SceneTree
## the Hyper3D horse in every coat colour, side view, one picture each
func _init() -> void:
	root.size = Vector2i(900, 700)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("e9efe7")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.92, 0.95); env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 55, 0); sun.light_energy = 1.1; sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, -120, 0); fill.light_energy = 0.4
	root.add_child(fill)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("7f877c"); floor.material_override = fm
	root.add_child(floor)
	var cam := Camera3D.new(); cam.fov = 20.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(8.5, 1.35, 0.35), Vector3(0, 1.05, 0.2))
	var scene: PackedScene = load(PaddockHorse.MODEL)
	for coat in ["bay", "dark bay", "chestnut", "black", "grey"]:
		var model: Node3D = scene.instantiate()
		model.scale = Vector3.ONE * PaddockHorse.SCALE
		root.add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var src = mi.get_active_material(0)
			if src is StandardMaterial3D: mi.material_override = PaddockHorse.coat_material(src, coat)
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(ap.get_animation_list()[0]); ap.seek(0.25, true); ap.pause()
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/coat_%s.png" % coat.replace(" ", "_"))
		model.queue_free()
		await process_frame
	quit()

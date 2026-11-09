extends SceneTree
## eight horses from a new world (their own inherited markings) and one grey at four ages
func _init() -> void:
	Career.init(31)
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
	var cam := Camera3D.new()
	root.add_child(cam)
	var scene: PackedScene = load(PaddockHorse.MODEL)
	# pick a varied set: different coats and markings
	var picks: Array = []
	var seen := {}
	for h in Career.active():
		var m := Markings.of(h)
		var key := String(h.coat) + String(m.face)
		if seen.has(key) or h.coat == "grey": continue
		var nl := 0
		for x in m.legs: if int(x) > 0: nl += 1
		if m.face == "none" and nl == 0 and picks.size() > 0: continue
		seen[key] = true
		picks.append(h)
		if picks.size() >= 8: break
	var grey: Dictionary = {}
	for h in Career.active():
		if h.coat == "grey": grey = h; break
	var lines: Array = []
	var k := 0
	var jobs: Array = []
	for h in picks: jobs.append([h, -1])
	for a in [2, 4, 6, 9]: jobs.append([grey, a])
	for j in jobs:
		var h: Dictionary = j[0].duplicate()
		if int(j[1]) > 0: h["age"] = j[1]
		var model: Node3D = scene.instantiate()
		model.scale = Vector3.ONE * PaddockHorse.SCALE
		root.add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var src = mi.get_active_material(0)
			mi.mesh = PaddockHorse.prepared_mesh(mi.mesh)
			if src is StandardMaterial3D: mi.material_override = PaddockHorse.coat_material(src, String(h.coat), h)
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(ap.get_animation_list()[0]); ap.seek(0.25, true); ap.pause()
		if k < 8:
			cam.fov = 24.0
			cam.look_at_from_position(Vector3(3.6, 2.1, 5.0), Vector3(0.0, 0.9, 0.5))
		else:
			cam.fov = 20.0
			cam.look_at_from_position(Vector3(8.5, 1.35, 0.35), Vector3(0, 1.05, 0.2))
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/mk2_%02d.png" % k)
		lines.append("%d|%s|%s|%s" % [k, h.name, Markings.coat_text(h) + (" · age %d" % int(h.age) if int(j[1]) > 0 else ""), Markings.describe(h)])
		model.queue_free()
		await process_frame
		k += 1
	var f := FileAccess.open("/tmp/mk2.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	quit()

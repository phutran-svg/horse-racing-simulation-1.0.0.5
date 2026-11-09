extends SceneTree
func _init() -> void:
	root.size = Vector2i(1400, 700)
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.6, 0.6); e.ambient_light_energy = 0.8
	env.environment = e; w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); sun.shadow_enabled = true; w.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.25, 0.5, 0.25); ground.material_override = gm; w.add_child(ground)
	var scene: PackedScene = load("res://assets/models/horse/Horse.glb")
	var coats := ["Brown", "Dark Brown", "Black", "Grey", "White"]
	var anims := ["Gallop", "Gallop", "Trot", "Walk", "Rest"]
	for i in 5:
		var h: Node3D = scene.instantiate()
		h.position = Vector3(-6.0 + i * 3.0, 0, 0)
		h.rotation_degrees.y = 90
		w.add_child(h)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/models/horse/Horse %s.png" % coats[i])
		for m in h.find_children("*", "MeshInstance3D", true, false): m.material_override = mat
		var ap: AnimationPlayer = h.find_children("*", "AnimationPlayer", true, false)[0]
		if i == 0: print("anims: ", ap.get_animation_list())
		ap.play(anims[i]); ap.seek(0.1 * i, true)
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.2, 9.5); cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0)); cam.fov = 55; w.add_child(cam)
	for f in 20: await process_frame
	root.get_texture().get_image().save_png("/home/claude/godot/shots/horse_preview.png")
	# side close-up gallop phases
	for i in 4:
		var ap: AnimationPlayer = w.get_child(3).find_children("*", "AnimationPlayer", true, false)[0]
	quit()

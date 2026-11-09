extends SceneTree
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.95, 0.95, 0.93)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e; w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, -20, 0); w.add_child(sun)
	var hs: Array = []
	for i in 8:
		var h := Horse3D.new(); w.add_child(h)
		h.setup({ "coat": "black", "color": "#e5484d" }, 3, 0.0)
		h.position = Vector3(i * 2.75 - 9.6, 0, 0)
		h.rotation_degrees.y = 90
		h.animate(17.0, 2.0, false)
		h.ap.speed_scale = 0.0
		h.ap.play("Gallop", 0.0)
		h.ap.seek(i * 0.5 / 8.0, true)
		var l := Label3D.new(); l.text = str(i + 1); l.font_size = 120; l.pixel_size = 0.004; l.modulate = Color.BLACK; l.position = Vector3(0, 0.1, 1.6); h.add_child(l)
		hs.append(h)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.85, 0.83, 0.78); g.material_override = gm; w.add_child(g)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 12.5
	w.add_child(cam); cam.look_at_from_position(Vector3(0, 1.4, 12), Vector3(0, 0.9, -1.5)); cam.current = true
	for f in 8: await process_frame
	root.get_texture().get_image().save_png("/home/claude/godot/shots/gallop_frames.png")
	quit()

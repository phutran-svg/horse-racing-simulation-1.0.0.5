extends SceneTree
## horse profile pages with the 3D portrait
func shot(n: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pf_%s.png" % n)
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	for i in 3: await process_frame
	m.create_career({ "role": "owner", "diff": "normal", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#d32f2f", "package": 2 })
	m._show_shell("home")
	var sh = m.screen
	var want := { "chestnut": null, "grey": null, "dark bay": null, "bay": null }
	for h in Career.active():
		var c := String(h.coat)
		if want.has(c) and want[c] == null and int(h.age) >= 3:
			var mk := Markings.of(h)
			if c == "grey" or mk.face != "none": want[c] = h
	for c in want:
		if want[c] != null:
			sh.open_horse(int(want[c].id)); await shot(c.replace(" ", "_"))
	quit()

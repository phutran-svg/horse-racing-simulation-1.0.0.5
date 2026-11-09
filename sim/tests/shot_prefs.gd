extends SceneTree
## horse page screenshots showing growth type, soft-ground preference and distance chart (local test tool)
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "p_" + name + ".png")
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.create_career({ "role": "owner", "diff": "normal", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#ec4899", "package": 1 })
	for w in 3: Career.advance_week()
	m._show_shell("home")
	var sh = m.screen
	sh.open_horse(int(Bloodlines.by_name["Kitasan Black"].id), "stud"); await shot("kitasan_stud")
	# a 3-year-old by Kitasan Black and one by Lord Kanaloa
	for nm in ["Kitasan Black", "Lord Kanaloa", "Drefong"]:
		var sid := int(Bloodlines.by_name[nm].id)
		var kids: Array = Career.active().filter(func(h): return h.sire == sid and int(h.age) == 3)
		if not kids.is_empty():
			sh.open_horse(int(kids[0].id)); await shot(nm.replace(" ", "_") + "_foal")
	quit()

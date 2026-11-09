extends SceneTree
## Ratings screenshots (local test tool). arg: weeks to advance first
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "r_" + name + ".png")
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.create_career({ "role": "owner", "diff": "normal", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#ec4899", "package": 1 })
	for w in (int(a[0]) if a.size() > 0 else 110): Career.advance_week()
	m._show_shell("home")
	var sh = m.screen
	sh.open("ratings", ["jpn", int(Career.W.year) - 1]); await shot("jpn")
	sh.open("ratings", ["races", null]); await shot("races")
	sh.open("ratings", ["pre", null]); await shot("pre")
	sh.open("results", null); await shot("results")
	sh.open("ratings", ["world", int(Career.W.year) - 1]); await shot("world")
	var g: Dictionary = Career.W.rankings.get(str(int(Career.W.year) - 1), {})
	var arr: Array = g.get("4yo+ Turf", [])
	if not arr.is_empty():
		sh.open_horse(int(arr[0].id)); await shot("horse")
		sh.open_horse(int(arr[0].id), "history"); await shot("history")
	quit()

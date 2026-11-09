extends SceneTree
## Breeding tab screenshots (local test tool). arg: weeks to advance first
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "b_" + name + ".png")
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.create_career({ "role": "owner", "diff": "normal", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#ec4899", "package": 1 })     # Breeder package
	for w in (int(a[0]) if a.size() > 0 else 3): Career.advance_week()
	m._show_shell("home")
	var sh = m.screen
	var mares: Array = sh.my_horses().filter(func(h): return h.sex == "F" and h.get("retired", false))
	var mid: int = int(mares[0].id) if not mares.is_empty() else -1
	sh.open("breeding", ["overview"]); await shot("overview")
	sh.open("breeding", ["stallions"]); await shot("stallions")
	var kb: Dictionary = Bloodlines.by_name["Kitasan Black"]
	sh.open("breeding", ["planner", mid, int(kb.id)]); await shot("planner")
	sh.open("breeding", ["planner", mid, int(Bloodlines.by_name["Frankel"].id)]); await shot("planner_os")
	sh.open_horse(int(Bloodlines.by_name["Equinox"].id), "pedigree"); await shot("ped_equinox")
	sh.open_horse(int(kb.id)); await shot("kitasan")
	sh.open("breeding", ["young"]); await shot("young")
	quit()

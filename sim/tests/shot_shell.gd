extends SceneTree
var out := "/home/claude/godot/shots/"
var n := 0
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "s%02d_%s.png" % [n, name]); n += 1
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await shot("menu")
	var t0 := Time.get_ticks_msec()
	m.create_career({ "role": "owner", "diff": "normal", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#ec4899", "package": 2 })
	print("career created ms ", Time.get_ticks_msec() - t0, " stable ", Career.W.stable)
	m._show_shell("home")
	var sh = m.screen
	await shot("home")
	sh.open("stable"); await shot("stable")
	var mine = sh.my_horses()
	var racer = null
	for h in mine:
		if h.c.status == "active" and int(h.age) >= 3 and racer == null: racer = h
	sh.open_horse(int(racer.id)); await shot("profile")
	sh.open_horse(int(racer.id), "entries"); await shot("entries")
	# enter the first eligible race
	var entered := false
	for hh in mine:
		if entered: break
		for r in Career.W.races:
			if Career.eligible(hh, r) and Career.enter(int(hh.id), int(r.id)) == "ok":
				print("enter: ", hh.name, " ", r.name); entered = true; break
	sh.open_horse(int(racer.id), "pedigree"); await shot("pedigree")
	sh.open("horses"); await shot("horses")
	sh.open("schedule"); await shot("schedule")
	sh.refresh_bar(); await shot("raceday_bar")
	t0 = Time.get_ticks_msec()
	await sh._advance(false)
	print("advance ms ", Time.get_ticks_msec() - t0)
	await shot("results")
	sh.open("home"); await shot("home2")
	quit()

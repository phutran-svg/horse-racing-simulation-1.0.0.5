extends SceneTree
## renders ui/main.tscn and saves screenshots at points in a race (local test tool)
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 3: await process_frame
	root.get_texture().get_image().save_png(out + name + ".png")
func adv(rs, t: float) -> void:
	while rs.race.t < t and not rs.race.done:
		RaceEngine.step(rs.race)
		if int(rs.race.t / 0.05) % 4 == 0: rs.comm.update()
	rs.comm.update()
	rs._process(0.016)
	rs._refresh_panels()
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var size := Vector2i(1600, 900) if args.is_empty() else Vector2i(int(args[0]), int(args[1]))
	root.size = size
	DisplayServer.window_set_size(size)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	for i in 5: await process_frame
	var rs = m.screens["race"]
	await shot("ui_start_%d" % size.x)
	rs.running = false
	adv(rs, 30.0); rs.view.update_camera(0.0); await shot("ui_t30_%d" % size.x)
	rs._on_cam(); rs._on_cam(); rs.view.update_camera(0.0); await shot("ui_full_%d" % size.x)
	rs._on_cam(); rs.view.zoom = 9.0
	adv(rs, 135.0); rs.view.update_camera(0.0); await shot("ui_t135_%d" % size.x)
	adv(rs, 999.0)
	for i in 3: rs._process(0.016)
	await shot("ui_results_%d" % size.x)
	rs.results_panel.visible = false
	rs.view.update_camera(0.0)
	await shot("ui_end_%d" % size.x)
	quit()

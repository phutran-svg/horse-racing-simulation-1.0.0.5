extends SceneTree
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	for i in 5: await process_frame
	var rs = m.screens["race"]
	rs.speed = 16.0
	rs._on_play()
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var last := t0
	var frames := 0
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last); last = now; frames += 1
	print("16x: race time %.1f s after 4 s wall, %d frames, worst frame %d ms" % [rs.race.t, frames, worst])
	rs._on_finish_now()
	t0 = Time.get_ticks_msec(); worst = 0; last = t0
	while not rs.race.done:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last); last = now
	print("finish now: done in %d ms, worst frame %d ms, results visible %s" % [Time.get_ticks_msec() - t0, worst, rs.results_panel.visible])
	for i in 3: await process_frame
	print("results visible after frames: ", rs.results_panel.visible, "  commentary lines: ", rs.comm.lines.size())
	quit()

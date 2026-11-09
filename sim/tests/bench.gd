extends SceneTree
func _init():
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("/home/claude/cmp/cases.json"))
	var o: Dictionary = data[1]
	var t0 := Time.get_ticks_usec()
	var race := RaceEngine.create_race(o.field.duplicate(true), { "course": "tokyo", "dist": 2400, "seed": 11 })
	while not race.done: RaceEngine.step(race)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	print("16 runners tokyo 2400: %.0f ms, %.3f ms/step" % [dt, dt / (race.t / 0.05)])
	quit()

extends SceneTree
## Same-seed comparison against the JavaScript engine (cases.json made by mkfields.js).
func _init() -> void:
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("/home/claude/cmp/cases.json"))
	var worst := 0.0
	for o in data:
		var c: Dictionary = o.c
		var race := RaceEngine.run_headless(o.field.duplicate(true), { "course": c.course, "dist": int(c.dist), "going": c.going, "seed": int(c.seed) })
		var res := RaceEngine.results(race)
		var line := "%s %d steps %d/%d ev %d/%d" % [c.course, c.dist, roundi(race.t / 0.05), int(o.steps), race.events.size(), int(o.events)]
		var maxd := 0.0
		var same_order := true
		for k in o.rows.size():
			var a: Dictionary = o.rows[k]
			var b: Dictionary = res.rows[k]
			if a.name != b.name: same_order = false
			if a.time != null and b.time >= 0.0: maxd = maxf(maxd, absf(float(a.time) - float(b.time)))
		var lapd := 0.0
		for k in mini(o.laps.size(), res.laps.size()): lapd = maxf(lapd, absf(float(o.laps[k]) - float(res.laps[k])))
		worst = maxf(worst, maxd)
		print(line, " order ", "SAME" if same_order else "DIFF", " max|dt| %.9f lap|d| %.9f  win %s %.4f" % [maxd, lapd, res.rows[0].name, res.rows[0].time])
	print("WORST ", worst)
	quit()

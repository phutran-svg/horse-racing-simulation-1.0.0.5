extends SceneTree
func _init() -> void:
	var T = load("res://sim/tests/sim_tests.gd").new()
	var R := SimRng.new(777)
	var fields: Array = []
	for g in T.GOLDEN:
		var field: Array = []
		for i in int(g[2]): field.append(T.test_horse(R, i, 70))
		fields.append(field)
	for gi in T.GOLDEN.size():
		var g: Array = T.GOLDEN[gi]
		var race := RaceEngine.run_headless(fields[gi].duplicate(true), { "course": g[0], "dist": g[1], "going": g[3], "seed": g[4] })
		var res := RaceEngine.results(race)
		print('\t["%s", %d, %d, "%s", %d, "%s", %s, %d],' % [g[0], g[1], g[2], g[3], g[4], res.rows[0].name, var_to_str(float(res.rows[0].time)), roundi(race.t / RaceEngine.DT)])
	Career.init(5)
	var ys := Career.buy_yearling()
	Career.add_to_stable(ys[0].id); Career.add_to_stable(ys[1].id)
	for h in Career.active():
		if h.age == 3:
			Career.add_to_stable(h.id); break
	for i in 20:
		Career.advance_week()
		if i == 7: print("w8 ", Career.R.state)
	print("w20 ", Career.R.state)
	T.free()
	quit()

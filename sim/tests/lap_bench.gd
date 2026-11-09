extends SceneTree
## Lap-shape benchmark (local test tool): builds class-level fields from a career world and runs the full engine.
## args: weeks_to_simulate races_per_case going
const CASES := [
	# course, dist, class, age ("O" = older horses 4+)
	["tokyo", 1600, "2W", "O"], ["tokyo", 2000, "2W", "O"], ["tokyo", 2400, "2W", "O"],
	["nakayama_o", 1200, "2W", "O"], ["nakayama", 2000, "2W", "O"], ["nakayama", 2500, "2W", "O"],
	["nakayama_d", 1800, "2W", "O"], ["tokyo_d", 1600, "2W", "O"],
	["tokyo", 2000, "1W", "O"], ["tokyo", 2400, "OP", "O"],
	["hanshin", 1400, "2W", "O"], ["chukyo", 1200, "2W", "O"], ["kokura", 1800, "1W", "O"], ["fukushima", 2600, "1W", "O"],
	["kyoto", 3000, "OP", "O"], ["kyoto", 2400, "2W", "O"], ["hanshin_d", 1400, "2W", "O"], ["kyoto_d", 1900, "2W", "O"],
	["fukushima_d", 1700, "1W", "O"], ["nakayama_d", 2400, "2W", "O"], ["niigata_s", 1000, "1W", "O"], ["sapporo", 2000, "1W", "O"],
]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var weeks := int(a[0]) if a.size() > 0 else 40
	var reps := int(a[1]) if a.size() > 1 else 12
	var going: String = a[2] if a.size() > 2 else "firm"
	for kv in a.slice(4):
		var parts: PackedStringArray = kv.split("=")
		if RaceEngine.CAL.has(parts[0]): RaceEngine.CAL[parts[0]] = float(parts[1])
		else:
			var v := float(parts[1])
			match parts[0]:
				"PACE_A": RaceEngine.PACE_A = v
				"TFAT_K": RaceEngine.TFAT_K = v
				"TFAT_T0": RaceEngine.TFAT_T0 = v
				"TFAT_PROJ": RaceEngine.TFAT_PROJ = v
				"PACE_D": RaceEngine.PACE_D = v
				"FAT0": RaceEngine.FAT0 = v
				"FATK": RaceEngine.FATK = v
				"LULLK": RaceEngine.LULLK = v
				"OVERPUSH": RaceEngine.OVERPUSH = v
				"GAPK": RaceEngine.GAPK = v
				"KF": for k in RaceEngine.STYLES: RaceEngine.STYLES[k].kf *= v
				"DCS": RaceEngine.SURF.dirt.cs = v
				"LULLLEN": RaceEngine.LULLLEN = v
				"DVMAX": RaceEngine.SURF.dirt.vmax = v
		print("set ", parts[0], " = ", parts[1])
	Career.init(5)
	for w in weeks: Career.advance_week()
	var out := FileAccess.open("/home/claude/godot/laps_%s.csv" % (a[3] if a.size() > 3 else going), FileAccess.WRITE)
	out.store_line("course,dist,cls,age,going,n,win,laps")
	var rng := SimRng.new(99)
	for cs in CASES:
		var pool: Array = []
		for h in Career.active():
			if h.c.out > 0 or h.age < 2: continue
			var cl: String = Career.class_of(h.c)
			var age_ok: bool = (h.age >= 4) if cs[3] == "O" else (h.age == int(cs[3]))
			var cls_ok: bool = cl == cs[2] or (cs[2] == "OP" and cl == "OP")
			if age_ok and cls_ok: pool.append(h)
		if pool.size() < 8: print("pool too small ", cs, " ", pool.size()); continue
		var race := { "age": "4+" if cs[3] == "O" else cs[3], "cls": cs[2], "handicap": false, "sex": "", "dist": cs[1] }
		var lap_sum: Array = []
		var wins: Array = []
		for k in reps:
			var field: Array = []
			var idx: Array = range(pool.size())
			for i in idx.size():   # shuffle
				var j := i + int(floor(rng.next() * (idx.size() - i)))
				var t = idx[i]; idx[i] = idx[j]; idx[j] = t
			for i in mini(14, idx.size()):
				var h: Dictionary = pool[idx[i]].duplicate(true)
				h["carried"] = Career.weight_for(h, race); h["ageF"] = Career.age_factor(h, Career.W.week); h["fitF"] = Career.fit_factor(h)
				if not h.get("jockey"): h["jockey"] = 70
				field.append(h)
			var r := RaceEngine.run_headless(field, { "course": cs[0], "dist": cs[1], "going": going, "seed": 1000 + k, "injuries": false, "eiph": true, "risk": 1 })
			var res := RaceEngine.results(r)
			if res.rows[0].time <= 0: continue
			wins.append(res.rows[0].time)
			if lap_sum.is_empty(): lap_sum.resize(res.laps.size()); lap_sum.fill(0.0)
			for i in mini(lap_sum.size(), res.laps.size()): lap_sum[i] += res.laps[i] / reps
		var s := 0.0
		for x in wins: s += x
		var ls: PackedStringArray = []
		for x in lap_sum: ls.append("%.2f" % x)
		out.store_line("%s,%d,%s,%s,%s,%d,%.2f,%s" % [cs[0], cs[1], cs[2], cs[3], going, wins.size(), s / wins.size(), " ".join(ls)])
		print(cs, " pool ", pool.size(), " win %.2f" % (s / wins.size()), " laps ", " ".join(ls))
	quit()

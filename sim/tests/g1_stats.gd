extends SceneTree
## average stats of G1 / G2 / G3 / maiden winners (local test tool). args: years seed
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var years := int(a[0]) if a.size() > 0 else 6
	Career.init(int(a[1]) if a.size() > 1 else 3)
	var acc := {}
	for w in years * 52:
		var yr := int(Career.W.year)
		for r in Career.advance_week():
			if yr < 2029 or r.result.is_empty(): continue
			var h = Breeding.get_horse(r.result[0].id)
			if h == null: continue
			var k: String = r.cls
			var surf: String = RaceEngine.COURSES[r.course].surface
			for key in [k, k + " " + surf] if k == "G1" else [k]:
				if not acc.has(key): acc[key] = { "n": 0, "rating": 0.0, "dist": 0.0 }
				var b: Dictionary = acc[key]
				b.n += 1; b.rating += Career.rating(h); b.dist += absf(float(r.dist) - Career.best_dist(h))
				for s in Breeding.STATS: b[s] = float(b.get(s, 0.0)) + float(h.stats[s])
				for g in ["CC", "CT", "TT"]: b[g] = float(b.get(g, 0.0)) + (1.0 if h.gene == g else 0.0)
	# all active racehorses for comparison
	var all := { "n": 0, "rating": 0.0, "dist": 0.0 }
	for h in Career.active():
		if int(h.age) < 3: continue
		all.n += 1; all.rating += Career.rating(h)
		for s in Breeding.STATS: all[s] = float(all.get(s, 0.0)) + float(h.stats[s])
	acc["ALL 3yo+"] = all
	var hdr := "%-10s %5s %6s" % ["class", "wins", "rating"]
	for s in Breeding.STATS: hdr += " %7s" % s.substr(0, 7)
	print(hdr + "   CC/CT/TT %")
	for key in ["G1", "G1 turf", "G1 dirt", "G2", "G3", "OP", "3W", "1W", "MDN", "ALL 3yo+"]:
		if not acc.has(key): continue
		var b: Dictionary = acc[key]
		var n := float(b.n)
		var line := "%-10s %5d %6.1f" % [key, b.n, b.rating / n]
		for s in Breeding.STATS: line += " %7.1f" % (b[s] / n)
		if b.has("CC"): line += "   %d/%d/%d" % [roundi(100 * b.CC / n), roundi(100 * b.CT / n), roundi(100 * b.TT / n)]
		print(line)
	quit()

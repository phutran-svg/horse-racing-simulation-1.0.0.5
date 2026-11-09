extends SceneTree
## how often horses run: starts per horse per year (2yo / 3yo+), gaps between starts, quick returns after graded races
func _init() -> void:
	Career.init(31)
	var log := {}      # id -> [[abs_week, cls, dist, pos]]
	for wk in 52:
		Career.advance_week()
		var aw := int(Career.W.year) * 52 + int(Career.W.week)
		for h in Career.active():
			var hs: Array = h.c.get("history", [])
			if hs.is_empty(): continue
			var e: Dictionary = hs[0]
			var ew := int(e.y) * 52 + int(e.w)
			if not log.has(int(h.id)): log[int(h.id)] = []
			var L: Array = log[int(h.id)]
			if L.is_empty() or int(L[-1][0]) != ew: L.append([ew, String(e.cls), int(e.dist), e.pos, int(h.age)])
	var by_age := { "2": [0, 0], "3+": [0, 0] }
	var gaps := {}
	var quick_g := 0; var after_g := 0
	var gsum := 0.0; var gn := 0
	var top: Array = []
	for id in log:
		var L: Array = log[id]
		var a := "2" if int(L[0][4]) <= 2 else "3+"
		by_age[a][0] += L.size(); by_age[a][1] += 1
		for k in range(1, L.size()):
			var g := int(L[k][0]) - int(L[k - 1][0])
			var b := str(mini(g, 13))
			gaps[b] = gaps.get(b, 0) + 1
			gsum += g; gn += 1
			if L[k - 1][1] in ["G1", "G2", "G3"]:
				after_g += 1
				if g <= 3: quick_g += 1
		var gr := L.filter(func(x): return x[1] == "G1").size()
		if gr >= 1: top.append(L.size())
	print("starts per horse  2yo %.2f (%d horses)   3yo+ %.2f (%d horses)" % [float(by_age["2"][0]) / maxf(1, by_age["2"][1]), by_age["2"][1], float(by_age["3+"][0]) / maxf(1, by_age["3+"][1]), by_age["3+"][1]])
	print("mean gap between starts %.1f weeks" % (gsum / maxf(1, gn)))
	var ks := gaps.keys(); ks.sort_custom(func(a, b): return int(a) < int(b))
	var line := ""
	for k in ks: line += "%s%s:%.0f%%  " % [k, "+" if k == "13" else "", 100.0 * gaps[k] / gn]
	print("gap (weeks) share: ", line)
	print("after a graded race, back within 3 weeks: %d of %d (%.0f%%)" % [quick_g, after_g, 100.0 * quick_g / maxf(1, after_g)])
	var ts := 0.0
	for x in top: ts += x
	print("G1 runners: %.1f starts in the season (%d horses)" % [ts / maxf(1, top.size()), top.size()])
	quit()

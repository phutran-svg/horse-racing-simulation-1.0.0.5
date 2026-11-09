extends SceneTree
## Rating calibration (local test tool). args: years seed
## Prints annual race ratings of the G1s (vs real IFHA/JRA figures), JPN-ranking tops, marks by class and the fit of
## year-best ratings to the game's ability rating (for the starting marks).
const REAL := { "Japan Cup": "122.5–126.75", "Takarazuka Kinen": "124.25 (2023)", "Tenno Sho (Autumn)": "119.75–123.5",
	"Arima Kinen": "120.25–123", "Yasuda Kinen": "118.5–120.5", "Osaka Hai": "117.75", "Tokyo Yushun (Derby)": "117.5",
	"Kikuka Sho": "117.5" }

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var years := int(a[0]) if a.size() > 0 else 6
	if a.size() > 2: Ratings.LEVEL_OFF = float(a[2])
	if a.size() > 3: Ratings.BOOT_A = float(a[3])
	if a.size() > 4: Ratings.BOOT_B = float(a[4])
	Career.init(int(a[1]) if a.size() > 1 else 3)
	var y0 := int(Career.W.year)
	var lv := []
	for w in years * 52:
		for r in Career.advance_week():
			if r.has("level") and int(Career.W.year) >= y0 + 2: lv.append([r.cls, float(r.level)])
	var W: Dictionary = Career.W
	# G1 race ratings (mean over the years from y0+2)
	print("G1 annual race ratings (mean of years %d–%d) — real IFHA/JRA in brackets" % [y0 + 2, int(W.year) - 1])
	var rows := []
	for name in W.raceRt:
		var lst: Array = W.raceRt[name]
		var s := 0.0
		var n := 0
		var cls := ""
		for e in lst:
			if int(e.y) >= y0 + 2: s += float(e.rr); n += 1; cls = e.cls
		if n > 0: rows.append([name, cls, s / n])
	rows = SimUtil.stable_sort(rows, func(x, y): return y[2] - x[2])
	for x in rows:
		if x[1] == "G1": print("  %-34s %6.2f  %s" % [x[0], x[2], ("(" + REAL[x[0]] + ")") if REAL.has(x[0]) else ""])
	var by := { "G1": [], "G2": [], "G3": [] }
	for x in rows:
		if by.has(x[1]): by[x[1]].append(x[2])
	for k in by:
		var arr: Array = by[k]
		if arr.is_empty(): continue
		var m := 0.0
		for v in arr: m += v
		print("  mean %s race rating %.1f (%d races)" % [k, m / arr.size(), arr.size()])
	# JPN ranking tops
	for yk in W.rankings:
		if int(yk) < y0 + 2: continue
		var g: Dictionary = W.rankings[yk]
		var line := "JPN ranking %s:" % yk
		for grp in g:
			var arr: Array = g[grp]
			line += "  %s %s (%d≥100)" % [grp, ("%d %s" % [int(arr[0].r), arr[0].name]) if not arr.is_empty() else "-", arr.size()]
		print(line)
	# marks by class and fit to ability
	var cls_m := {}
	var sx := 0.0; var sy := 0.0; var sxx := 0.0; var sxy := 0.0; var nn := 0.0
	for h in Career.active():
		var m = Ratings.mark(h)
		if m == null: continue
		var cl := Career.class_of(h.c) if int(h.c.get("g1", 0)) == 0 else "G1w"
		if int(h.c.get("graded", 0)) > 0 and cl != "G1w": cl = "Gw"
		if not cls_m.has(cl): cls_m[cl] = []
		cls_m[cl].append(float(m))
		var yb = Ratings.year_best(h, int(W.year) - 1)
		if yb != null and int(h.age) >= 5:
			var x := Career.rating(h) - 66.5
			var y := float(yb.r)
			sx += x; sy += y; sxx += x * x; sxy += x * y; nn += 1
	var line2 := "marks by class (mean, n):"
	for k in ["MDN", "1W", "2W", "3W", "OP", "Gw", "G1w"]:
		if not cls_m.has(k): continue
		var arr: Array = cls_m[k]
		var m2 := 0.0
		for v in arr: m2 += v
		line2 += "  %s %.0f (%d)" % [k, m2 / arr.size(), arr.size()]
	print(line2)
	if nn > 10:
		var b := (nn * sxy - sx * sy) / (nn * sxx - sx * sx)
		print("fit of year-best (4yo+) to ability: rating ≈ %.1f + %.2f × (ability − 66.5)  (n %d)" % [(sy - b * sx) / nn, b, nn])
	print("grade changes: ", W.get("gradeOverride", {}))
	var yl := "mean G1 race rating by year:"
	for y in range(y0, int(W.year)):
		var ss := 0.0
		var nn2 := 0
		for name in W.raceRt:
			for e in W.raceRt[name]:
				if int(e.y) == y and e.cls == "G1": ss += float(e.rr); nn2 += 1
		if nn2 > 0: yl += "  %d %.1f" % [y, ss / nn2]
	print(yl)
	var lc := {}
	for e in lv:
		if not lc.has(e[0]): lc[e[0]] = [0.0, 0]
		lc[e[0]][0] += e[1]; lc[e[0]][1] += 1
	var line3 := "race level (winner speed, lb) by class:"
	for k in ["NEW", "MDN", "1W", "2W", "3W", "OP", "G3", "G2", "G1"]:
		if lc.has(k): line3 += "  %s %.0f" % [k, lc[k][0] / lc[k][1]]
	print(line3)
	quit()

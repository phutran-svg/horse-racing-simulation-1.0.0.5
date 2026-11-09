extends SceneTree
## counts races run by class and field sizes, and runners/winners per crop (local test tool). args: years seed
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var years := int(a[0]) if a.size() > 0 else 7
	Career.init(int(a[1]) if a.size() > 1 else 3)
	var y0 := int(Career.W.year)
	var cnt := {}; var fs := {}; var built := {}
	for w in years * 52:
		var yr := int(Career.W.year)
		var nb: int = Career.W.races.size()
		var done: Array = Career.advance_week()
		if yr >= y0 + 3:
			for r in done:
				if not r.cls in ["G1", "G2", "G3"]:
					var sf: String = RaceEngine.COURSES[r.course].surface
					var b := int(r.dist / 200) * 200
					var key := "%s %d" % [sf, b]
					fs["d:" + key] = int(fs.get("d:" + key, 0)) + 1
				cnt[r.cls] = int(cnt.get(r.cls, 0)) + 1
				fs[r.cls] = int(fs.get(r.cls, 0)) + r.entries.size()
	var yrs := years - 3
	print("per year (last %d years):" % yrs)
	var dk := fs.keys().filter(func(k): return str(k).begins_with("d:"))
	dk.sort()
	for k in dk: print("  ", k, "  ", fs[k])
	for k in cnt: print("  %-4s races %6.1f  mean field %.1f" % [k, cnt[k] / float(yrs), fs[k] / float(cnt[k])])
	var crops := {}
	for h in Breeding.book.values():
		if not h.has("c"): continue
		var b := int(h.c.get("born", 0))
		if not crops.has(b): crops[b] = [0, 0, 0]
		crops[b][0] += 1
		if int(h.c.starts) > 0: crops[b][1] += 1
		if int(h.c.wins) > 0: crops[b][2] += 1
	var ks := crops.keys(); ks.sort()
	for b in ks: print("  crop %d: foals %d runners %d winners %d (%.0f%%)" % [b, crops[b][0], crops[b][1], crops[b][2], 100.0 * crops[b][2] / maxf(1, crops[b][1])])
	quit()

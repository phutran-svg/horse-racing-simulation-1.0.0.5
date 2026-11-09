extends SceneTree
## 6-year world check: crops, stallion turnover, fees, inbreeding trend, live-foal rate
func _init() -> void:
	Career.init(9)
	var t0 := Time.get_ticks_msec()
	for y in 6:
		var mares := 0
		var infoal := 0
		for i in 52: Career.advance_week()
		for m in Breeding.mares():
			if int(m.age) > 20: continue
			mares += 1
			if Stud.repro(m).due > 0: infoal += 1
		var fs: Array = []
		for s in Breeding.stallions(): fs.append(Stud.stud(s).fee)
		fs.sort()
		var F := 0.0
		var n := 0
		var fmax := 0.0
		var ages := {}
		for m in Breeding.mares():
			var b: int = int(m.age) / 3 * 3
			ages[b] = ages.get(b, 0) + 1
		print("   mare ages ", ages)
		for h in Career.active():
			if int(h.age) <= 1:
				F += float(h.F); n += 1; fmax = maxf(fmax, float(h.F))
		print("%d: crop %d · mares %d in foal %d (%.0f%%) · stallions %d fees min %.1f med %.1f max %.1f · foal F mean %.3f max %.3f · book %d · %d ms" % [Career.W.year, Career.W.crops.get(Career.W.year - 1, {"n":0}).n, mares, infoal, 100.0 * infoal / maxf(1, mares), fs.size(), fs[0], fs[fs.size() / 2], fs[-1], F / maxf(1, n), fmax, Breeding.book.size(), Time.get_ticks_msec() - t0])
	quit()

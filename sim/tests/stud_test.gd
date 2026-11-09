extends SceneTree
## Step 3 breeding check (local test tool): fertility, crops, foaling dates, fees, player bookings.
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	Career.init(5)
	print("init ms ", Time.get_ticks_msec() - t0, " book ", Breeding.book.size(), " stallions ", Breeding.stallions().size(), " mares ", Breeding.mares().size())
	var fees: Array = []
	for s in Breeding.stallions(): fees.append([Stud.stud(s).fee, Stud.stud(s).cap, Stud.stud(s).book, s.name])
	fees.sort_custom(func(a, b): return a[0] > b[0])
	print("fees/cap/book (top 6): ", fees.slice(0, 6))
	print("fees (bottom 4): ", fees.slice(fees.size() - 4))
	var due := 0
	for m in Breeding.mares(): if Stud.repro(m).due > 0: due += 1
	print("mares in foal at start: ", due, " / ", Breeding.mares().size())
	# player gets two mares
	var ms := Breeding.mares()
	var mine: Array = [ms[3], ms[10]]
	for m in mine: Career.add_to_stable(m.id)
	var births := {}
	var weeks := {}
	t0 = Time.get_ticks_msec()
	for i in 110:
		var n0 := Breeding.book.size()
		Career.advance_week()
		if Career.W.week == 3:
			var st := Breeding.stallions()
			# book player mares to the 2 best-matching stallions
			for m in mine:
				var best = null
				var bs := -99.0
				for s in st:
					var p := Stud.plan(m, s)
					var sc: float = p.rating - p.fee * 0.2 - p.F * 50.0
					if sc > bs: bs = sc; best = s
				print("book ", m.name, " -> ", best.name, ": ", Stud.book(m.id, best.id), " F=", "%.3f" % Breeding.kin(best, m))
		var born := 0
		for h in Career.active():
			if int(h.age) == 0 and int(h.c.born) == int(Career.W.year) and int(h.get("foaled", 0)) == int(Career.W.week): born += 1
		if born > 0:
			births[Career.W.year] = births.get(Career.W.year, 0) + born
			var k := "%d-w%02d" % [Career.W.year, Career.W.week]
			weeks[int(Career.W.week)] = weeks.get(int(Career.W.week), 0) + born
	print("110 weeks ms ", Time.get_ticks_msec() - t0)
	print("foals per year (crops) ", Career.W.crops.keys().map(func(k): return [k, Career.W.crops[k].n]))
	var wk: Array = weeks.keys(); wk.sort()
	var ws: PackedStringArray = []
	for w in wk: ws.append("%d:%d" % [w, weeks[w]])
	print("foals by week ", " ".join(ws))
	var nr := 0; var un := 0
	for h in Breeding.book.values():
		var c = h.get("c")
		if c != null and str(c.get("retiredWhy", "")).begins_with("did not make"): un += 1
	print("never raced (dev) so far ", un)
	for e in Career.W.log.slice(0, 400):
		if e.mine: print("  ", e.y, "-w", e.w, " ", e.msg)
	print("ledger ", Career.W.get("ledger", []))
	var m0: Dictionary = mine[0]
	var s0 = Breeding.stallions()[0]
	var p := Stud.plan(m0, s0)
	print("plan sample: rating %.1f ±%.1f F %.3f dist %d dirt %.0f raced %.2f live %.2f dups %s cross %s" % [p.rating, p.spread, p.F, p.dist, p.dirt, p.raced, p.p_live, p.dups, p.cross])
	quit()

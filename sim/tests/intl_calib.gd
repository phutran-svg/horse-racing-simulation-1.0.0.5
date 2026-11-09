extends SceneTree
## Overseas G1s check (local test tool). args: years seed [FA_turf FA_dirt FB]
## Prints each overseas race (field, Japanese runners, winner, race level), how foreign horses' performances compare
## with their starting marks (calibration of their ability), the Top G1 races and the world ranking.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var years := int(a[0]) if a.size() > 0 else 2
	if a.size() > 3: Intl.FA = { "turf": float(a[2]), "dirt": float(a[3]) }
	if a.size() > 4: Intl.FB = float(a[4])
	Career.init(int(a[1]) if a.size() > 1 else 3)
	var y0 := int(Career.W.year)
	var dev := { "turf": [0.0, 0], "dirt": [0.0, 0] }
	var jp_w := 0
	var n_int := 0
	var verbose := years <= 2
	for w in years * 52:
		var pre := {}
		for h in Breeding.book.values():
			if h.has("foreign") and h.has("c") and h.c.get("mark") != null: pre[int(h.id)] = float(h.c.mark)
		for r in Career.advance_week():
			if not r.get("intl", false) and r.name != "Japan Cup": continue
			var njp := 0
			for x in r.result:
				var h = Breeding.get_horse(x.id)
				if h.get("foreign") == null: njp += 1
				elif x.get("rt") != null and pre.has(int(x.id)) and int(str(x.pos)) <= 6 if str(x.pos).is_valid_int() else false:
					var sf: String = Intl.REGIONS[h.foreign][0]
					dev[sf][0] += float(x.rt) - pre[int(x.id)]; dev[sf][1] += 1
			var wh = Breeding.get_horse(r.result[0].id)
			var wjp: bool = wh.get("foreign") == null
			if r.get("intl", false):
				n_int += 1
				if wjp: jp_w += 1
			if verbose:
				print("%d w%d %-38s %2d runners (%d JPN)  won by %-22s [%s] rt %s  level %.0f  going %s" % [int(Career.W.year), int(Career.W.week) - 1, r.name, r.result.size(), njp,
					wh.name, str(wh.get("trained", "JPN")), str(r.result[0].get("rt")), float(r.get("level", 0)), r.going])
	print("Japanese wins in overseas G1s: %d of %d" % [jp_w, n_int])
	for sf in dev:
		if dev[sf][1] > 0: print("foreign %s horses (top 6): performance − starting mark = %+.1f lb (n %d)" % [sf, dev[sf][0] / dev[sf][1], dev[sf][1]])
	var y := int(Career.W.year) - 1
	var tr := Intl.top_races(y)
	print("Top G1 races %d:" % y)
	for i in mini(15, tr.size()): print("  %2d %-40s %6.2f  %s" % [i + 1, tr[i].name, tr[i].rr, tr[i].country])
	var wr := Intl.world_ranking(y)
	print("World ranking %d (115+): %d horses" % [y, wr.size()])
	for i in mini(15, wr.size()): print("  %2d %3d %s %-24s %-4s %s" % [i + 1, int(wr[i].r), wr[i].cat, wr[i].name, wr[i].trained, wr[i].race])
	var by := {}
	for e in wr: by[e.trained] = int(by.get(e.trained, 0)) + 1
	print("  by country: ", by)
	quit()

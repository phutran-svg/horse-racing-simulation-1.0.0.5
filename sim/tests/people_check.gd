extends SceneTree
## Step 4B check: one season with real jockeys and trainers — leading tables, injuries, ride skill.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	Career.init(int(a[0]) if a.size() > 0 else 99)
	Career.build_week()
	var t0 := Time.get_ticks_msec()
	var inj := 0
	var sk := 0.0
	var n := 0
	for w in 52:
		Career.advance_week()
		for r in Career.W.lastWeek.races:
			for e in r.entries:
				var h = Breeding.get_horse(e)
				if h != null and h.has("jockey"): sk += float(h.jockey); n += 1
	for x in Career.W.log: if String(x.msg).contains("injured"): inj += 1
	var y := int(Career.W.year) - 1
	print("season %d in %.1f s; mean ride skill %.1f (%d rides); injuries logged %d" % [y, (Time.get_ticks_msec() - t0) / 1000.0, sk / maxf(1, n), n, inj])
	print("JOCKEYS")
	for e in People.leaders("jockeys", y).slice(0, 12):
		print("  %-22s skill %4.1f  %3d rides %3d-%3d-%3d  %5.1f%%  ¥%.0fM" % [e.p.name, e.p.skill, e.rides, e.w, e.w2, e.w3, 100.0 * e.w / maxf(1, e.rides), e.prize])
	print("TRAINERS")
	for e in People.leaders("trainers", y).slice(0, 10):
		print("  %-22s skill %4.1f  %3d starts %3d wins  %5.1f%%  ¥%.0fM %s" % [e.p.name, e.p.skill, e.rides, e.w, 100.0 * e.w / maxf(1, e.rides), e.prize, e.p.centre])
	var act := People.active_jockeys().size()
	print("active jockeys %d, trainers %d" % [act, People.active_trainers().size()])
	quit()

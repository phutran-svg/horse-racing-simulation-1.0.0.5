extends SceneTree
func f(x) -> String:
	if x == null: return "-"
	if x is float or x is int: return "%.6f" % float(x)
	return str(x)
func _init() -> void:
	var out: PackedStringArray = []
	Career.init(5)
	var hs := Career.active().filter(func(h): return h.age >= 2 and h.age <= 4).slice(0, 6)
	for h in hs: Career.add_to_stable(h.id)
	for i in 30:
		for id in Career.W.stable:
			var rr = null
			for r in Career.W.races:
				if Career.eligible(Breeding.get_horse(id), r):
					rr = r; break
			out.append("enter|%d|%s" % [id, Career.enter(id, rr.id) if rr != null else "none"])
		var races := Career.advance_week()
		for r in races:
			if Career.W.replays.has(r.id):
				var a: PackedStringArray = []
				for x in r.result: a.append("%d:%s:%s" % [x.id, str(x.pos), f(x.time)])
				out.append("mine|%d|%s|%s|%s" % [r.id, r.name, r.going, " ".join(a)])
				var rp := RaceEngine.results(Career.replay_race(r.id))
				var b: PackedStringArray = []
				for x in rp.rows: b.append(str(x.r.h.id))
				out.append("replay|" + ",".join(b))
		out.append("w|%d|%d" % [Career.W.week, Career.R.state])
	for id in Career.W.stable:
		var h: Dictionary = Breeding.get_horse(id)
		out.append("h|%s|%s|%d|%d|%s|%s|%s" % [h.name, h.c.status, h.c.starts, h.c.wins, f(h.c.earn), f(h.c.fit), f(h.c.fat)])
	var lg: PackedStringArray = []
	for x in Career.W.log.slice(0, 20): lg.append(x.msg)
	out.append("log|" + " // ".join(lg))
	var fa := FileAccess.open("/home/claude/cmp/career2_gd.txt", FileAccess.WRITE)
	fa.store_string("\n".join(out) + "\n"); fa.close()
	quit()

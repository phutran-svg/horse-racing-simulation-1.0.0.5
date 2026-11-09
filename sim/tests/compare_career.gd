extends SceneTree
var out: PackedStringArray = []
func f(x) -> String:
	if x == null: return "-"
	if x is float or x is int: return "%.6f" % float(x)
	return str(x)
func jtiers(t: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in t: parts.append('"%s":%d' % [k, t[k]])
	return "{" + ",".join(parts) + "}"
func wk() -> void:
	var races := Career.advance_week()
	var parts: PackedStringArray = []
	for r in races: parts.append("%d:%s:%d:%s:%d:%d:%s" % [r.id, r.course, r.dist, r.going, r.entries.size(), r.result[0].id, f(r.result[0].time)])
	out.append("w|%d|%d|%d|%d|" % [Career.W.year, Career.W.week, races.size(), Career.R.state] + " ".join(parts))
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	Career.init(5)
	var ys := Career.buy_yearling()
	Career.add_to_stable(ys[0].id); Career.add_to_stable(ys[1].id)
	for h in Career.active():
		if h.age == 3:
			Career.add_to_stable(h.id); break
	out.append("init|%d|%s|stable %s" % [Breeding.book.size(), jtiers(Career.stats().tiers), ",".join(Career.W.stable.map(func(x): return str(x)))])
	for i in 60:
		if i == 20:
			for id in Career.W.stable:
				for r in Career.W.races:
					if Career.eligible(Breeding.get_horse(id), r):
						out.append("enter|%d|%s" % [id, Career.enter(id, r.id)]); break
		wk()
	var s := Career.stats()
	out.append("stats|%d|%d|%s|fav %d/%d" % [s.n, s.total, jtiers(s.tiers), Career.W.favW, Career.W.favN])
	for id in Career.W.stable:
		var h: Dictionary = Breeding.get_horse(id)
		var hs: PackedStringArray = []
		for x in h.c.history: hs.append("%s#%s" % [x.race, str(x.pos)])
		out.append("mine|%s|%d|%d|%s|%s|%s" % [h.name, h.c.starts, h.c.wins, f(h.c.earn), f(h.c.cm), ";".join(hs)])
	var lg: PackedStringArray = []
	for x in Career.W.log.slice(0, 15): lg.append(x.msg)
	out.append("log|" + " // ".join(lg))
	var t1 := Time.get_ticks_msec()
	var sv := Career.save_json()
	Career.load_json(sv)
	for i in 4: wk()
	var fa := FileAccess.open("/home/claude/cmp/career_gd.txt", FileAccess.WRITE)
	fa.store_string("\n".join(out) + "\n"); fa.close()
	print(out.size(), " lines; 60 weeks ", (t1 - t0) / 1000.0, " s; save ", sv.length() / 1024, " KB; total ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit()

extends SceneTree
func f(x) -> String:
	if x == null: return "null"
	if x is float: return "%.9f" % x
	return str(x)
func line(h: Dictionary) -> String:
	var a := [h.id, h.name, h.sex, f(h.sire), f(h.dam), h.mstn, h.gene, h.coat, h.style, h.bw, h.carried, f(float(h.F)), h.dirt]
	for k in Breeding.STATS: a.append(h.stats[k])
	for k in Breeding.TRAITS: a.append(f(float(h.gv[k])))
	return "|".join(a.map(func(x): return str(x)))
func _init() -> void:
	var rng := SimRng.new(42)
	var out: PackedStringArray = []
	Breeding.seed_book(rng, 6, 10)
	var st := Breeding.stallions()
	var ma := Breeding.mares()
	for i in 40: Breeding.breed(st[i % st.size()], ma[(i * 7) % ma.size()], rng)
	var all := Breeding.book.values()
	for i in 60:
		var ms := all.filter(func(h): return h.sex == "M")
		var fs2 := Breeding.book.values().filter(func(h): return h.sex == "F")
		var s: Dictionary = ms[int(floor(rng.next() * ms.size()))]
		var d: Dictionary = fs2[int(floor(rng.next() * fs2.size()))]
		Breeding.breed(s, d, rng)
	for h in Breeding.book.values(): out.append(line(h))
	var fem := Breeding.book.values().filter(func(h): return h.sex == "F")
	var p := Breeding.predict(st[0], fem[fem.size() - 1])
	var ck: Array = p.coat.keys(); ck.sort()
	var evs: Array = []
	for k in Breeding.TRAITS: evs.append(f(p.ev[k]))
	var mj := '{"CC":%s,"CT":%s,"TT":%s}' % [str(p.mstn.CC), str(p.mstn.CT), str(p.mstn.TT)]
	out.append("pred|" + f(p.F) + "|" + mj + "|" + ",".join(ck.map(func(k): return k + ":" + f(p.coat[k]))) + "|" + ",".join(evs))
	out.append("byline|" + Breeding.byline(Breeding.book.values().back()))
	var fa := FileAccess.open("/home/claude/cmp/breed_gd.txt", FileAccess.WRITE)
	fa.store_string("\n".join(out) + "\n")
	fa.close()
	print(out.size(), " lines")
	quit()

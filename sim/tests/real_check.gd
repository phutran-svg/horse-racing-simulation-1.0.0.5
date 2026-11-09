extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	Career.init(5)
	print("init ms ", Time.get_ticks_msec() - t0, " book ", Breeding.book.size(), " stallions ", Breeding.stallions().size(), " mares ", Breeding.mares().size())
	var st := Breeding.stallions()
	st.sort_custom(func(a, b): return Stud.stud(a).fee > Stud.stud(b).fee)
	for s in st.slice(0, 8):
		var pr := Stud.progeny(s)
		print("%-16s fee %5.1f cap %3d book %3d line %-16s rating %.1f gene %s runners %d g %d  %s" % [s.name, Stud.stud(s).fee, Stud.stud(s).cap, Stud.stud(s).book, Stud.sire_line(s), Career.rating(s), s.gene, pr.runners, pr.graded, Breeding.byline(s)])
	# top racehorses sires
	var act := Career.active()
	act.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
	for h in act.slice(0, 6): print("  ", h.name, " ", h.age, "yo ", Breeding.byline(h), " r %.1f" % Career.rating(h))
	# a crossing example
	var m: Dictionary = Breeding.mares()[3]
	print("mare ", m.name, " ", Breeding.byline(m))
	for s in st.slice(0, 5):
		var d := Stud.duplicates(s, m)
		var dl := []
		for x in d: dl.append("%s %s" % [x.name, x.label])
		print("  x ", s.name, " F=%.3f " % Breeding.kin(s, m), dl)
	# avg rating by age (calibration check)
	for a in [3, 4]:
		var v := act.filter(func(h): return h.age == a)
		var sm := 0.0
		for h in v: sm += Career.rating(h)
		print("age ", a, " n ", v.size(), " mean rating %.2f" % (sm / v.size()))
	var counts := {}
	for h in act:
		var s = Breeding.get_horse(h.sire)
		counts[s.name] = counts.get(s.name, 0) + 1
	var ks := counts.keys(); ks.sort_custom(func(a, b): return counts[a] > counts[b])
	print("sires of active: ", ks.slice(0, 15).map(func(k): return "%s %d" % [k, counts[k]]))
	quit()

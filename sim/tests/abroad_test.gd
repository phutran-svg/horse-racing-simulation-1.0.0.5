extends SceneTree
func _init() -> void:
	Career.init(5)
	var ms := Breeding.mares()
	var m: Dictionary = ms[7]
	Career.add_to_stable(m.id)
	var fr: Dictionary = Bloodlines.by_name["Frankel"]
	var kb: Dictionary = Bloodlines.by_name["Kitasan Black"]
	for w in 60:
		Career.advance_week()
		if Career.W.week == 3 and Career.W.year == 2027:
			print("book Frankel: ", Stud.book(int(m.id), int(fr.id)), " plan F=%.3f" % Stud.plan(m, fr).F, " dups ", Stud.plan(m, fr).dups.map(func(x): return x.name + " " + x.label))
	for e in Career.W.get("ledger", []): print("ledger ", e)
	for l in Career.W.log:
		if l.get("mine", false): print(l.y, "-w", l.w, " ", l.msg)
	var foals: Array = Stud.repro(m).foals
	for fid in foals:
		var f = Breeding.get_horse(fid)
		print("foal ", f.name, " ", Breeding.byline(f), " line ", Stud.sire_line(f))
	quit()

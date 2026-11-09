extends SceneTree
## Step 4 world check: build time, size, real mares, extra stallions, pedigree completeness.
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	Career.init(7)
	Career.build_week()
	var ms := Breeding.mares()
	var real := ms.filter(func(m): return m.get("realMare", false)).size()
	var st := Breeding.stallions()
	print("world built in %.1f s: %d horses in the book, %d active, %d mares (%d real), %d stallions in Japan, %d abroad" % [(Time.get_ticks_msec() - t0) / 1000.0, Breeding.book.size(), Career.active().size(), ms.size(), real, st.size(), Stud.overseas().size()])
	var fill := 0
	var tot := 0
	for h in Career.active().filter(func(x): return int(x.age) == 2):
		var lvl: Array = [h]
		for g in 5:
			var nx: Array = []
			for x in lvl:
				for p in ["sire", "dam"]:
					var a = Breeding.get_horse(x.get(p)) if x != null else null
					tot += 1
					if a != null: fill += 1
					nx.append(a)
			lvl = nx
	print("2-year-olds: %.0f%% of 5-generation pedigree slots filled" % (100.0 * fill / tot))
	for n in ["Kitasan Black", "Equinox", "Justify", "Kingman", "Bricks And Mortar"]:
		var s = Bloodlines.by_name.get(n)
		if s == null: print(n, " missing"); continue
		var d = Breeding.get_horse(s.dam)
		print("  %s (%d) by %s out of %s · fee %s" % [n, int(s.born), Breeding.get_horse(s.sire).name if s.sire != null else "?", d.name if d != null else "?", Stud.fee_text(s) if s.has("stud") else "-"])
	var t1 := Time.get_ticks_msec()
	for w in 26: Career.advance_week()
	print("26 weeks in %.1f s; book %d" % [(Time.get_ticks_msec() - t1) / 1000.0, Breeding.book.size()])
	var bytes := Career.save_data().size()
	print("save size %d KB" % (bytes / 1024))
	quit()

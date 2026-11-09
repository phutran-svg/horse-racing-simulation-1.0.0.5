extends SceneTree
## Step 4A check: play a career for N years without input and print the money and the career path.
## args: role bg diff years [focus]   e.g.  -- trainer young normal 10 study
## The player's own horses get simple automatic race entries (like the AI) so money flows.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var rl := a[0] if a.size() > 0 else "owner"
	var bg := a[1] if a.size() > 1 else "pro"
	var diff := a[2] if a.size() > 2 else "normal"
	var years := int(a[3]) if a.size() > 3 else 2
	var focus := a[4] if a.size() > 4 else "balanced"
	var main = load("res://ui/main.gd")
	var t0 := Time.get_ticks_msec()
	main.create_career({ "role": rl, "bg": bg, "diff": diff, "name": "Test", "stable_name": "Test Stable", "center": "ritto", "age": 20, "package": 2 })
	var W := Career.W
	W.player.focus = focus
	print("start %s/%s/%s: cash %.1f, horses %d, boxes %d, job %s" % [rl, bg, diff, Finance.money(), W.stable.size(), int(W.player.boxes), W.player.job])
	var y0 := int(W.year)
	var last_y := y0
	while int(W.year) < y0 + years:
		_auto_enter()
		_auto_breed()
		if rl == "trainer" and Profile.licensed_trainer():
			while not W.player.offers.is_empty() and W.stable.size() < int(W.player.boxes): Profile.accept_offer(0)
		Career.advance_week()
		if W.player.get("over", false):
			print("GAME OVER in %d week %d" % [W.year, W.week]); break
		if int(W.year) != last_y:
			var st := Finance.statement(last_y)
			var p: Dictionary = W.player
			var by: Dictionary = st.by
			var parts: PackedStringArray = []
			for k in by: parts.append("%s %.1f" % [k, float(by[k])])
			print("%d  net %+.1f  cash %.1f  debt %.1f  horses %d  | %s" % [last_y, st.net, Finance.money(), Finance.debt(), W.stable.size(), ", ".join(parts)])
			if rl == "trainer":
				var s: Dictionary = p.skills
				print("      age %d job %s rep %.0f boxes %d skills h%.0f r%.0f k%.0f b%.0f exams %s" % [Profile.age(), p.job, p.rep, int(p.boxes), s.horse, s.riding, s.know, s.business, str(p.exams.map(func(e): return "%d/%d:%s" % [e.y, e.stage, "P" if e.pass else "F"]))])
			last_y = int(W.year)
	print("done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	for x in W.log.slice(0, 12): print("  log: ", x.msg)
	quit()

## enter the player's ready horses in a suitable race each week (what a player would do)
func _auto_enter() -> void:
	var W := Career.W
	if W.races.is_empty(): return
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h == null or h.c.status != "active" or int(h.age) < 2 or int(h.c.get("out", 0)) > 0 or h.c.get("entry") != null: continue
		if int(W.week) - int(h.c.get("last", -99)) < 4 and int(h.c.get("lastY", 0)) == int(W.year): continue
		var best = null
		var bs := -1.0
		for r in W.races:
			if not Career.eligible(h, r) or r.entries.size() >= 16: continue
			var s := Game.suit(h, float(r.dist), RaceEngine.COURSES[r.course].surface == "dirt")
			if s > bs: bs = s; best = r
		if best != null and bs > 0.3: Career.enter(int(h.id), int(best.id))

## owners/breeders: book every unbooked mare to an affordable stallion in January; sell yearlings in August
func _auto_breed() -> void:
	var W := Career.W
	if int(W.week) == 3:
		var studs: Array = Breeding.stallions().filter(func(s): return float(Stud.stud(s).fee) <= 6.0 and not s.has("abroad"))
		for id in W.stable:
			var m = Breeding.get_horse(id)
			if m == null or m.sex != "F" or not m.get("retired", false) or studs.is_empty(): continue
			var s: Dictionary = studs[(int(id) * 7 + int(W.year)) % studs.size()]
			Stud.book(int(m.id), int(s.id))
	if int(W.week) == 33 and Profile.role() == "breeder":
		for id in W.stable.duplicate():
			var h = Breeding.get_horse(id)
			if h != null and int(h.age) == 1 and h.c.status == "active": Finance.sell(h, Finance.offer_price(h), "yearling sale")

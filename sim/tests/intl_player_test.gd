extends SceneTree
## the player's horse goes to the Dubai Sheema Classic (full engine on Meydan) — local test tool
func _init() -> void:
	Career.init(4)
	# best Japanese 4yo+ turf middle-distance horse joins the stable
	var best = null
	for h in Career.active():
		if h.has("foreign") or int(h.age) < 4 or int(h.dirt) > 50 or Career.best_dist(h) < 1900: continue
		if best == null or float(h.c.get("mark", 0)) > float(best.c.get("mark", 0)): best = h
	Career.add_to_stable(int(best.id))
	print("horse: %s mark %d best %d m" % [best.name, int(best.c.mark), int(Career.best_dist(best))])
	while int(Career.W.week) < 13:
		Career.advance_week()
	var rid := -1
	for r in Career.W.races:
		if r.name == "Dubai Sheema Classic": rid = int(r.id)
	print("enter: ", Career.enter(int(best.id), rid))
	var done := Career.advance_week()
	for r in done:
		if r.name != "Dubai Sheema Classic": continue
		print("%s at %s (%s), %d runners, going %s, level %.0f" % [r.name, RaceEngine.COURSES[r.course].name, r.country, r.result.size(), r.going, float(r.get("level", 0))])
		for x in r.result.slice(0, 6):
			var h = Breeding.get_horse(x.id)
			print("  %s %-24s %-4s %s %s rt %s" % [str(x.pos), x.name, str(h.get("trained", "JPN")), RaceEngine.fmt_time(float(x.time)) if x.time != null else "-", str(x.get("margin", "")), str(x.get("rt"))])
		for x in r.result:
			if int(x.id) == int(best.id): print("  our horse finished ", x.pos, " rated ", x.get("rt"))
	print("replay saved: ", Career.W.replays.size() > 0)
	for l in Career.W.get("ledger", []).slice(0, 4): print("  ledger: ", l.text, " ", l.amt)
	quit()

extends SceneTree
func _init() -> void:
	Career.init(5)
	var act := Career.active().filter(func(h): return h.sex == "M" and int(h.age) >= 4)
	act.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
	var c: Dictionary = act[0]
	Career.add_to_stable(c.id)
	print("to stud: ", Stud.to_stud(c), " ", c.name, " fee ", Stud.stud(c).fee, " ", Breeding.byline(c))
	Stud.set_fee(c, 3.0)
	for w in 70: Career.advance_week()
	var inc := 0.0
	var n := 0
	for e in Career.W.get("ledger", []):
		if String(e.text).begins_with("Stud fee received"): inc += e.amt; n += 1
	print("fees received: ", n, " total ¥%.1fM" % inc, " book ", Stud.stud(c).book, "/", Stud.stud(c).cap, " progeny foals ", Stud.progeny(c).foals)
	quit()

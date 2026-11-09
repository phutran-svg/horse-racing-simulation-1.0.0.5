extends SceneTree
func _init() -> void:
	Career.init(5)
	var dy := {}
	for m in Breeding.mares():
		var r := Stud.repro(m)
		if r.due > 0: dy[Stud.year_of(r.due)] = dy.get(Stud.year_of(r.due), 0) + 1
	print("due years ", dy, " now ", Stud.now(), " y ", Career.W.year)
	var c0: int = Career.W.crops.get(2027, {"n":0}).n
	for i in 30:
		Career.advance_week()
	var n := 0
	for m in Breeding.mares():
		if Stud.repro(m).due > 0 and Stud.year_of(Stud.repro(m).due) == 2027: n += 1
	print("after 30w crops 2027 ", Career.W.crops.get(2027), " still due 2027 ", n, " mares ", Breeding.mares().size())
	quit()

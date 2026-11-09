extends SceneTree
## Step 4A: save slots, autosave rotation, load gives the same game, old saves are migrated.
func _init() -> void:
	var main = load("res://ui/main.gd")
	main.create_career({ "role": "breeder", "diff": "hard", "name": "T", "stable_name": "Save Farm" })
	for w in 6: Career.advance_week()
	var ok := true
	var e := Saves.save_slot(3, "test")
	var m0 := Finance.money()
	var st0: Array = Career.W.stable.duplicate()
	for i in 4:
		Career.advance_week(); Saves.autosave()
	var autos := Saves.list().filter(func(s): return s.kind == "auto")
	print("autosaves kept: %d (expect 3), newest week %d" % [autos.size(), int(autos[0].meta.week)])
	ok = ok and autos.size() == 3
	Saves.load_path(Saves.DIR + "slot_3.sav")
	print("slot 3 reload: money %.2f vs %.2f, stable same %s, role %s, label '%s'" % [Finance.money(), m0, str(Career.W.stable == st0), Profile.role(), Career.W.get("saveLabel", "")])
	ok = ok and absf(Finance.money() - m0) < 0.001 and Career.W.stable == st0 and Profile.role() == "breeder"
	# a save from before Step 4 (no player profile)
	Career.W.erase("player"); Career.W.erase("money")
	var f := FileAccess.open("user://career.sav", FileAccess.WRITE); f.store_buffer(Career.save_data()); f.close()
	Saves.load_path("user://career.sav")
	print("old save migrated: role %s, money %.1f, farm %s, stable %d" % [Profile.role(), Finance.money(), str(Profile.P().farm), Career.W.stable.size()])
	ok = ok and Profile.role() == "owner" and Finance.money() > 290.0
	DirAccess.remove_absolute("user://career.sav")
	print("SAVES TEST %s" % ("PASSED" if ok else "FAILED"))
	quit()

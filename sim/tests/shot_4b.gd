extends SceneTree
## Step 4B/4C screenshots: training tab, Training page, jockeys & trainers, auction ring, 5-generation pedigree.
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "b_" + name + ".png")
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.create_career({ "role": "owner", "diff": "easy", "name": "Trinh", "stable_name": "Sakura Racing", "silk": "#ec4899", "package": 0 })
	while int(Career.W.week) < 27: Career.advance_week()
	m._show_shell("home")
	var sh = m.screen
	var hs: Array = sh.my_horses().filter(func(x): return x.c.status == "active" and int(x.age) >= 2)
	if not hs.is_empty():
		var h: Dictionary = hs[0]
		# enter a race and book a jockey so the Connections card shows it
		for r in Career.W.races:
			if Career.eligible(h, r): Career.enter(int(h.id), int(r.id)); break
		Training.set_plan(h, "manual", "slope", "hard")
		sh.open_horse(int(h.id), "training"); await shot("horse_training")
		sh.open_horse(int(h.id), "pedigree"); await shot("ped_mine")
	sh.open("training"); await shot("training_page")
	sh.open("people"); await shot("people")
	var kb = Bloodlines.by_name.get("Equinox")
	if kb != null: sh.open_horse(int(kb.id), "pedigree"); await shot("ped_equinox")
	Career.advance_week()     # week 28: Select Sale
	sh.open("auctions"); await shot("auction_cat")
	var a := Auction.current()
	if not a.is_empty():
		Auction.open_lot(0)
		Auction.player_bid()
		sh.open("auctions"); await shot("auction_ring")
	quit()

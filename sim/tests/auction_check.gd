extends SceneTree
## Step 4C check: one season of sales — lots, clearance and average prices against the real 2025 figures;
## the player consigns a yearling and buys a lot.
func _init() -> void:
	var main = load("res://ui/main.gd")
	main.create_career({ "role": "breeder", "diff": "easy", "name": "T", "stable_name": "Test Farm" })
	var W := Career.W
	var bought := false
	while int(W.year) == 2027:
		# consign the first yearling to the Summer Sale
		if int(W.week) == 25:
			for id in W.stable:
				var h = Breeding.get_horse(id)
				if h != null and int(h.age) == 1 and h.c.status == "active":
					h.c["consign"] = "summer"; h.c["reserve"] = 1.0; print("consigned %s (est %.1f)" % [h.name, Auction.market_value(h)]); break
		if Auction.is_sale_week() and not bought and Auction.current().key == "summer":
			var a := Auction.current()
			for i in a.lots.size():
				if a.lots[i].cons == "ai":
					Auction.open_lot(i)
					for k in 30:
						if not Auction.player_bid(): break
						if Auction.current().bid.high == "you": break
					var res := Auction.hammer()
					print("player bid on lot %d: %s at %.1f" % [int(res.lot), res.buyer, float(res.price)])
					bought = true
					break
		Career.advance_week()
	var real := { "training": 7.4, "select_y": 65.0, "select_f": 69.4, "selection": 18.1, "summer": 7.8, "autumn": 4.0, "mixed": 0.0 }
	for k in W.sales.get("2027", {}):
		var r: Dictionary = W.sales["2027"][k]
		print("%-10s lots %3d sold %3d (%.0f%%) avg ¥%.1fM (real ~¥%.1fM) top ¥%.0fM" % [k, r.n, r.sold, 100.0 * r.sold / maxf(1, r.n), r.gross / maxf(1, r.sold), real.get(k, 0.0), r.top[0][0] if not r.top.is_empty() else 0.0])
	for e in W.ledger.slice(0, 200):
		if String(e.cat) in ["sale", "purchase"]: print("  ledger: ", e.text, " ", e.amt)
	quit()

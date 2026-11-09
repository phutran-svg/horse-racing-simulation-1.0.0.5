class_name AuctionPage
extends ScrollContainer
## Step 4C — sales calendar, catalogue, live bidding (in the sale week) and results.

var shell

func setup(s, _arg = null) -> AuctionPage:
	shell = s
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var a := Auction.current()
	shell._set_title("Auctions", "Cash %s%s" % [Game.money(Finance.money()), " · SALE WEEK" if Auction.is_sale_week() else ""])
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	# the sale ring in 3D: open in the sale week
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	v.add_child(bar)
	if Auction.is_sale_week():
		var go := Button.new()
		go.text = "🔨 Enter the sale ring (3D)"
		go.custom_minimum_size = Vector2(300, 48)
		go.add_theme_font_size_override("font_size", 18)
		go.pressed.connect(func(): AuctionPage.enter_ring(shell))
		bar.add_child(go)
		bar.add_child(UiTheme.label("The %s is on today." % Auction.sale(String(a.lots[0].sale if not a.lots.is_empty() else a.key)).name, 15, UiTheme.ACC))
	else:
		var ns := Auction.next_sale()
		var wk := int(ns.week) - int(Career.W.week)
		if wk < 0: wk += 52
		bar.add_child(UiTheme.label("Next sale: %s in %d week%s (%s). The sale ring opens in the sale week — press Continue until then." % [ns.name, wk, "" if wk == 1 else "s", ns.place], 14))
	if not Profile.can_own():
		bar.add_child(UiTheme.label("You need an owner licence to bid.", 13, UiTheme.BAD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_calendar(shell._card("Sales calendar %d" % int(Career.W.year), row))
	if Auction.is_sale_week(): _live(shell._card("Live bidding", row), a)
	else: _results(shell._card("Results this year", row))
	if not a.is_empty(): _catalogue(shell._card("Catalogue", v), a)
	else: v.add_child(UiTheme.dim_label("The next catalogue comes out three weeks before the sale.", 13))
	return self

static func enter_ring(sh) -> void:
	Game.return_page = "auctions"
	sh.get_tree().change_scene_to_file("res://race3d/auction_3d.tscn")

func _calendar(c: VBoxContainer) -> void:
	c.get_parent().custom_minimum_size.x = 520
	for s in Auction.SALES:
		var past := int(s.week) < int(Career.W.week)
		var t := "%s  %s · %s" % [Game.date_text(int(Career.W.year), int(s.week)).substr(4), s.name, s.place]
		c.add_child(UiTheme.label(t, 13, UiTheme.DIM if past else (UiTheme.ACC if int(s.week) == int(Career.W.week) else UiTheme.TEXT)))
	c.add_child(UiTheme.dim_label("Real Japanese sales (JRHA, HBA). Prices follow 2025 levels: Select Sale ~¥65–70M average, Summer Sale ~¥8M. Buyers pay the hammer price; sellers pay 5% commission.", 11))

func _results(c: VBoxContainer) -> void:
	var ys := str(int(Career.W.year))
	var r: Dictionary = Career.W.get("sales", {}).get(ys, {})
	if r.is_empty(): c.add_child(UiTheme.dim_label("No sales held yet this year.", 13))
	for k in r:
		var x: Dictionary = r[k]
		c.add_child(UiTheme.label("%s — %d/%d sold, avg %s" % [Auction.sale(k).name, int(x.sold), int(x.n), Game.money(float(x.gross) / maxf(1, x.sold))], 13))
		for t in x.top.slice(0, 3):
			var h = Breeding.get_horse(t[1])
			if h != null: c.add_child(UiTheme.dim_label("   %s  %s (by %s)" % [Game.money(float(t[0])), h.name, Breeding.get_horse(h.sire).name if Breeding.get_horse(h.sire) != null else "?"], 12))

func _live(c: VBoxContainer, a: Dictionary) -> void:
	c.get_parent().custom_minimum_size.x = 640
	var b = a.get("bid")
	var nxt := -1
	for i in a.lots.size():
		if not a.lots[i].done: nxt = i; break
	if b == null and nxt < 0:
		c.add_child(UiTheme.label("All lots have been offered.", 14))
		var fb := Button.new()
		fb.text = "Close the sale and see the results"
		fb.pressed.connect(func(): Auction.finish(a); shell.open("auctions"))
		c.add_child(fb)
		return
	if b == null:
		var lot: Dictionary = a.lots[nxt]
		var h = Breeding.get_horse(lot.id)
		c.add_child(UiTheme.label("Next: Lot %d — %s" % [int(lot.lot), h.name if h != null else "?"], 16, UiTheme.STRONG))
		var hb := HBoxContainer.new()
		var ob := Button.new()
		ob.text = "Into the ring ›"
		ob.pressed.connect(func(): Auction.open_lot(nxt); shell.open("auctions"))
		hb.add_child(ob)
		var sk := Button.new()
		sk.text = "Skip (sell without me)"
		sk.pressed.connect(func(): Auction.auto_lot(lot); shell.open("auctions"))
		hb.add_child(sk)
		var fin := Button.new()
		fin.text = "Leave — sell the rest"
		fin.pressed.connect(func(): Auction.finish(a); shell.open("auctions"))
		hb.add_child(fin)
		c.add_child(hb)
		return
	var lot2: Dictionary = a.lots[int(b.i)]
	var h2 = Breeding.get_horse(lot2.id)
	c.add_child(UiTheme.label("Lot %d — %s" % [int(lot2.lot), h2.name], 18, UiTheme.STRONG))
	c.add_child(UiTheme.dim_label(_lot_line(h2, lot2), 12))
	c.add_child(UiTheme.label(Game.money(float(b.price)), 34, UiTheme.ACC))
	c.add_child(UiTheme.label("Highest bid: %s" % ("YOU" if b.high == "you" else (b.high if b.high != "" else "no bids yet")), 14, UiTheme.GOOD if b.high == "you" else UiTheme.TEXT))
	var hb2 := HBoxContainer.new()
	var nb := Button.new()
	nb.text = "Bid %s" % Game.money(float(b.price) + Auction.increment(float(b.price)))
	nb.disabled = b.high == "you" or lot2.cons == "player" or not Profile.can_own()
	nb.pressed.connect(func():
		if not Auction.player_bid(): shell.toast("Not enough money (cash plus bank credit)")
		shell.open("auctions"))
	hb2.add_child(nb)
	var hm := Button.new()
	hm.text = "Going, going… (stop bidding)"
	hm.pressed.connect(func():
		var res := Auction.hammer()
		shell.toast("Lot %d: %s at %s" % [int(res.lot), "yours!" if res.buyer == "you" else ("bought back" if res.buyer == "bought back" else "sold to " + String(res.buyer)), Game.money(float(res.price))])
		shell.open("auctions"))
	hb2.add_child(hm)
	c.add_child(hb2)
	for l in b.log.slice(0, 6): c.add_child(UiTheme.dim_label(l, 12))
	if not Profile.can_own(): c.add_child(UiTheme.dim_label("You need an owner licence to buy.", 12))

func _lot_line(h: Dictionary, lot: Dictionary) -> String:
	var s = Breeding.get_horse(h.sire)
	var d = Breeding.get_horse(h.dam)
	var ds = Breeding.get_horse(d.sire) if d != null else null
	var age := int(h.get("age", 0))
	var what := "broodmare" if h.get("retired", false) else ("foal" if age == 0 else ("yearling" if age == 1 else "2-year-old"))
	return "%s %s · by %s out of %s (%s) · %s · estimate %s–%s" % [h.get("coat", ""), Game.sex_word(h) if what != "broodmare" else "", s.name if s != null else "?", d.name if d != null else "?",
		ds.name if ds != null else "?", what, Game.money(float(lot.mv) * 0.7), Game.money(float(lot.mv) * 1.4)]

func _catalogue(c: VBoxContainer, a: Dictionary) -> void:
	var names: Array = []
	for lot in a.lots:
		if not names.has(lot.sale): names.append(lot.sale)
	c.add_child(UiTheme.dim_label("%s · week %d · %d lots · double-click a horse to inspect it" % [", ".join(names.map(func(k): return Auction.sale(k).name)), int(a.week), a.lots.size()], 12))
	var t := Tree.new()
	t.hide_root = true
	t.columns = 8
	t.column_titles_visible = true
	var cols := ["Lot", "Horse", "Sex", "Sire", "Dam (damsire)", "Consignor", "Estimate", "Result"]
	var w := [50, 200, 80, 170, 260, 110, 150, 200]
	for i in cols.size():
		t.set_column_title(i, cols[i]); t.set_column_custom_minimum_width(i, w[i]); t.set_column_expand(i, i == 4)
	t.custom_minimum_size.y = 520
	var root := t.create_item()
	for lot in a.lots:
		var h = Breeding.get_horse(lot.id)
		if h == null: continue
		var it := t.create_item(root)
		var s = Breeding.get_horse(h.sire)
		var d = Breeding.get_horse(h.dam)
		var ds = Breeding.get_horse(d.sire) if d != null else null
		it.set_text(0, str(int(lot.lot)))
		it.set_text(1, h.name); it.set_metadata(1, int(h.id))
		it.set_text(2, ("%s %d" % [Game.sex_word(h), int(h.age)]) if not h.get("retired", false) else "Mare %d" % int(h.age))
		it.set_text(3, s.name if s != null else "?")
		it.set_text(4, "%s (%s)" % [d.name if d != null else "?", ds.name if ds != null else "?"])
		it.set_text(5, "YOU" if lot.cons == "player" else "Breeder")
		it.set_text(6, "%s–%s" % [Game.money(float(lot.mv) * 0.7), Game.money(float(lot.mv) * 1.4)])
		it.set_text(7, ("%s · %s" % [Game.money(float(lot.price)), "YOU" if lot.buyer == "you" else String(lot.buyer)]) if lot.done else "-")
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null and it.get_metadata(1) != null: shell.open_horse(int(it.get_metadata(1))))
	c.add_child(t)

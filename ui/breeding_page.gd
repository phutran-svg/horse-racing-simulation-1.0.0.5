class_name BreedingPage
extends VBoxContainer
## Breeding tab (Step 3): Overview · Stallions · Mating planner · Young stock.

var shell
var sub := "overview"
var mare_id := -1
var sel_stallion := -1

func setup(game_shell, arg) -> BreedingPage:
	shell = game_shell
	if arg is Array and arg.size() > 0:
		sub = arg[0]
		if arg.size() > 1 and arg[1] != null: mare_id = int(arg[1])
		if arg.size() > 2 and arg[2] != null: sel_stallion = int(arg[2])
	add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 22)
	for t in [["overview", "Overview"], ["stallions", "Stallions"], ["planner", "Mating planner"], ["young", "Foals & yearlings"]]:
		var b := Button.new()
		b.text = t[1]
		b.flat = true
		b.add_theme_color_override("font_color", UiTheme.ACC if t[0] == sub else UiTheme.DIM)
		b.add_theme_color_override("font_hover_color", UiTheme.STRONG)
		b.pressed.connect(func(): shell.open("breeding", [t[0], mare_id if mare_id >= 0 else null]))
		tabs.add_child(b)
	add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	match sub:
		"overview": _overview(v)
		"stallions": _stallions(v)
		"planner": _planner(v)
		"young": _young(v)
	return self

func _card(title: String, parent: Control, expand := true) -> VBoxContainer:
	var pc := PanelContainer.new()
	if expand: pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	pc.add_child(v)
	if title != "": v.add_child(UiTheme.section(title))
	return v

func _my(filter: Callable) -> Array:
	var out: Array = []
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h != null and filter.call(h): out.append(h)
	return out

func _mares() -> Array:
	return _my(func(h): return h.sex == "F" and h.get("c", {}).get("status", "") == "broodmare")

func _season_text() -> String:
	var w := int(Career.W.week)
	if Stud.in_season(): return "Breeding season OPEN · %d weeks left (ends 30 Jun)" % (Stud.SEASON_END - w + 1)
	if w < Stud.SEASON_START: return "Breeding season opens 10 Feb (in %d weeks) · you can book stallions now" % (Stud.SEASON_START - w)
	return "Breeding season closed · next season opens 10 Feb · you can book for next year"


# ---------------- overview ----------------
func _overview(v: VBoxContainer) -> void:
	shell._set_title("Breeding", _season_text())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var a := _card("My broodmares", row)
	var ms := _mares()
	if ms.is_empty(): a.add_child(UiTheme.dim_label("You have no broodmares. Retire a filly to breeding from her profile, or buy one (auctions come in step 4).", 13))
	for m in ms:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var nm: Button = shell._horse_link(m, 15)
		nm.custom_minimum_size.x = 170
		hb.add_child(nm)
		hb.add_child(UiTheme.label("%d yo" % int(m.age), 13, UiTheme.DIM))
		var st := UiTheme.label(Stud.mare_status(m), 13)
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hb.add_child(st)
		var pb := Button.new()
		pb.text = "Plan mating ›"
		pb.pressed.connect(func(): shell.open("breeding", ["planner", int(m.id)]))
		hb.add_child(pb)
		a.add_child(hb)
	var b := _card("Breeding facts", row, false)
	b.get_parent().custom_minimum_size.x = 430
	for t in ["Season: 10 Feb – 30 Jun (JBBA). Mares only cycle once days lengthen, mostly from March.",
		"Each heat (every 3 weeks) gives about a 55–60% chance of pregnancy; less for older or barren mares.",
		"Pregnancy lasts about 11 months (≈340 days). About 12–20% of pregnancies are lost; twins are reduced to one by the vet.",
		"The stud fee is paid only when a live foal is born.",
		"Inbreeding: about 7% less chance of ever racing for each 10% of inbreeding, and weaker legs."]:
		var l := UiTheme.label("• " + t, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(l)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	var c := _card("Foals & yearlings", row2)
	var ys := _my(func(h): return h.get("c", {}).get("status", "") == "active" and int(h.get("age", 0)) <= 1)
	if ys.is_empty(): c.add_child(UiTheme.dim_label("No foals or yearlings yet.", 13))
	else:
		var t := HorseTable.new(["name", "age", "sex", "gene", "sire", "pot", "status"])
		t.custom_minimum_size.y = 40 + 32 * ys.size()
		t.horse_opened.connect(shell.open_horse)
		t.set_horses(ys)
		c.add_child(t)
	var d := _card("Breeding news", row2)
	d.get_parent().custom_minimum_size.x = 430
	var n := 0
	for x in Career.W.log:
		if n >= 12: break
		if not x.get("mine", false): continue
		var m: String = x.msg
		if not (m.contains("cover") or m.contains("foal") or m.contains("booked") or m.contains("season") or m.contains("weaned") or m.contains("yearling") or m.contains("broken") or m.contains("stud") or m.contains("barren")): continue
		var l := UiTheme.label("%s  %s" % [Game.date_text(int(x.y), int(x.w)).substr(4), m], 12, UiTheme.MINE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_child(l)
		n += 1
	if n == 0: d.add_child(UiTheme.dim_label("No breeding news yet.", 13))
	var mine_st := _my(func(h): return h.get("c", {}).get("status", "") == "stud")
	if not mine_st.is_empty():
		var e := _card("My stallions", v)
		var t2 := HorseTable.new(["name", "age", "fee", "book", "runners", "winners", "sw", "aei"])
		t2.custom_minimum_size.y = 40 + 32 * mine_st.size()
		t2.horse_opened.connect(shell.open_horse)
		t2.set_horses(mine_st)
		e.add_child(t2)


# ---------------- stallions ----------------
func _stallions(v: VBoxContainer) -> void:
	shell._set_title("Stallions", "%d stallions at stud · %s" % [Breeding.stallions().size(), _season_text()])
	var c := _card("Stallion directory · double-click to open · click a column to sort", v)
	var t := HorseTable.new(["name", "age", "line", "fee", "book", "ab", "runners", "winners", "sw", "aei", "dist", "surf"])
	t.sort_col = "fee"
	t.custom_minimum_size.y = 760
	t.horse_opened.connect(shell.open_horse)
	t.set_horses(Breeding.stallions())
	c.add_child(t)
	var c2 := _card("Overseas stallions · send your mare abroad: fee + about %s for shipping and boarding" % Game.money(Bloodlines.ABROAD_COST), v)
	var t2 := HorseTable.new(["name", "age", "country", "line", "fee", "ab", "dist", "surf"])
	t2.sort_col = "fee"
	t2.custom_minimum_size.y = 40 + 32 * Stud.overseas().size()
	t2.horse_opened.connect(shell.open_horse)
	t2.set_horses(Stud.overseas())
	c2.add_child(t2)
	var n := UiTheme.dim_label("Names, pedigrees and 2026 fees are real (Shadai Stallion Station and others; ~ = estimated fee). Ability, genes and breeding values are game estimates, not real data.", 11)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)


# ---------------- young stock ----------------
func _young(v: VBoxContainer) -> void:
	shell._set_title("Foals & yearlings", "Your young horses · their ability becomes clearer as they grow and train")
	for g in [["Foals (born this year)", 0], ["Yearlings", 1], ["2-year-olds", 2]]:
		var ys := _my(func(h): return h.get("c", {}).get("status", "") == "active" and int(h.get("age", 0)) == g[1])
		var c := _card("%s (%d)" % [g[0], ys.size()], v)
		if ys.is_empty():
			c.add_child(UiTheme.dim_label("None.", 13)); continue
		var t := HorseTable.new(["name", "sex", "gene", "sire", "dist", "surf", "ab", "pot", "report"])
		t.custom_minimum_size.y = 40 + 32 * ys.size()
		t.horse_opened.connect(shell.open_horse)
		t.set_horses(ys)
		c.add_child(t)
	var l := UiTheme.dim_label("Milestones: weaning (Aug–Sep) · yearling (1 Jan) · broken in (Oct) · training centre (spring at 2) · newcomer races from June at 2. Around 9% of horses never make the races; more if inbred.", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)


# ---------------- mating planner ----------------
func _planner(v: VBoxContainer) -> void:
	shell._set_title("Mating planner", _season_text())
	var ms := _mares()
	if ms.is_empty():
		_card("Mating planner", v).add_child(UiTheme.dim_label("You have no broodmares yet.", 13)); return
	if mare_id < 0 or not ms.any(func(m): return int(m.id) == mare_id): mare_id = int(ms[0].id)
	var m: Dictionary = Breeding.get_horse(mare_id)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	top.add_child(UiTheme.label("Mare:", 15))
	var opt := OptionButton.new()
	for i in ms.size():
		opt.add_item("%s (%d yo)" % [ms[i].name, int(ms[i].age)], int(ms[i].id))
		if int(ms[i].id) == mare_id: opt.select(i)
	opt.item_selected.connect(func(i): shell.open("breeding", ["planner", opt.get_item_id(i)]))
	top.add_child(opt)
	var st := UiTheme.label(Stud.mare_status(m), 14, UiTheme.ACC)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	# stallion list ranked for this mare
	var left := _card("Stallions for %s · click one to see the predicted foal" % m.name, row)
	var plans := {}
	for s in Breeding.stallions() + Stud.overseas(): plans[int(s.id)] = Stud.plan(m, s)
	var ids: Array = plans.keys()
	ids.sort_custom(func(a, b): return plans[a].rating > plans[b].rating)
	var t := Tree.new()
	t.hide_root = true
	t.columns = 8
	t.column_titles_visible = true
	t.select_mode = Tree.SELECT_ROW
	t.custom_minimum_size = Vector2(0, 700)
	var heads := [["Stallion", 170], ["Fee", 76], ["Book", 64], ["Expected foal", 120], ["Best dist.", 86], ["Surface", 86], ["Inbreeding", 90], ["Live foal", 76]]
	for i in heads.size():
		t.set_column_title(i, heads[i][0]); t.set_column_custom_minimum_width(i, heads[i][1]); t.set_column_expand(i, i == 0)
		t.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	var root := t.create_item()
	var r := Stud.repro(m)
	if sel_stallion < 0: sel_stallion = int(r.plan) if r.plan != null else int(ids[0])
	for id in ids:
		var s: Dictionary = Breeding.get_horse(id)
		var p: Dictionary = plans[id]
		var sd := Stud.stud(s)
		var it := t.create_item(root)
		it.set_metadata(0, id)
		it.set_text(0, s.name + (" (%s)" % s.abroad if s.has("abroad") else "") + ("  ✓ booked" if r.plan != null and int(r.plan) == int(id) else ""))
		it.set_text(1, Stud.fee_text(s))
		it.set_text(2, "abroad" if s.has("abroad") else "%d/%d" % [int(sd.book), int(sd.cap)])
		if s.has("abroad"): it.set_custom_color(0, Color("9cc7ff"))
		it.set_text(3, UiTheme.stars(_stars(p.rating)))
		it.set_custom_color(3, UiTheme.ACC)
		it.set_text(4, "%d m" % (int(p.dist / 100.0) * 100))
		it.set_text(5, "Dirt" if p.dirt >= 62 else ("Turf" if p.dirt <= 38 else "Both"))
		it.set_text(6, "%.1f %%" % (p.F * 100.0))
		if p.F >= 0.0625: it.set_custom_color(6, UiTheme.BAD)
		elif p.F >= 0.03: it.set_custom_color(6, UiTheme.ACC)
		it.set_text(7, "%d %%" % roundi(p.p_live * 100.0))
		if sd.book >= sd.cap: it.set_custom_color(2, UiTheme.BAD)
		if int(id) == sel_stallion: it.select(0)
	t.item_selected.connect(func():
		var it2 := t.get_selected()
		if it2 != null and int(it2.get_metadata(0)) != sel_stallion: shell.open("breeding", ["planner", mare_id, int(it2.get_metadata(0))], false))
	left.add_child(t)
	# predicted foal
	var right := _card("Predicted foal", row, false)
	right.get_parent().custom_minimum_size.x = 520
	var s: Dictionary = Breeding.get_horse(sel_stallion)
	var p: Dictionary = plans[sel_stallion]
	right.add_child(UiTheme.label("%s  ×  %s" % [s.name, m.name], 18, UiTheme.STRONG))
	right.add_child(UiTheme.dim_label("by %s (%s line) · out of %s (by %s) · %s" % [s.name, Stud.sire_line(s), m.name, Stud._name(m.sire), Stud.fee_text(s) + " on a live foal" + (" + about %s shipping to %s" % [Game.money(Bloodlines.ABROAD_COST), s.abroad] if s.has("abroad") else "")], 12))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	var lo: float = p.rating - p.spread * 1.28
	var hi: float = p.rating + p.spread * 1.28
	_row(grid, "Expected ability", "%s  (80%%: %s – %s)" % [UiTheme.stars(_stars(p.rating)), UiTheme.stars(_stars(lo)), UiTheme.stars(_stars(hi))], UiTheme.ACC)
	_row(grid, "Prediction accuracy", "%d %%  (more raced offspring → more accurate)" % roundi(p.acc * 100.0))
	_row(grid, "Speed gene (MSTN)", "C:C %d %% · C:T %d %% · T:T %d %%" % [roundi(p.mstn.CC * 100.0), roundi(p.mstn.CT * 100.0), roundi(p.mstn.TT * 100.0)])
	_row(grid, "Likely best distance", "about %d m" % (int(p.dist / 100.0) * 100))
	_row(grid, "Surface", "dirt %d / 100 (0 = pure turf type)" % roundi(p.dirt))
	var coats: PackedStringArray = []
	var ck: Array = p.coat.keys()
	ck.sort_custom(func(a, b): return p.coat[a] > p.coat[b])
	for k in ck: coats.append("%s %d%%" % [k, roundi(p.coat[k] * 100.0)])
	_row(grid, "Coat colour", " · ".join(coats))
	_row(grid, "Inbreeding (F)", "%.2f %%%s" % [p.F * 100.0, "" if p.F < 0.001 else " → ~%d %% less chance of racing, weaker legs" % roundi(p.F * 70.0)], UiTheme.BAD if p.F >= 0.0625 else UiTheme.TEXT)
	var dl: PackedStringArray = []
	for d in p.dups: dl.append("%s %s (%.2f%%)" % [d.name, d.label, d.pct])
	_row(grid, "Duplicated ancestors", ", ".join(dl) if not dl.is_empty() else "none in 5 generations")
	var cr: Dictionary = p.cross
	var bms = Breeding.get_horse(m.sire)
	_row(grid, "This cross so far", ("%s line × %s line: %d runners, %d winners (%d%%), %d stakes winners" % [Stud.sire_line(s), Stud.sire_line(bms), cr.runners, cr.winners, roundi(100.0 * cr.winners / maxf(1.0, cr.runners)), cr.graded]) if bms != null else "-")
	_row(grid, "Chance of a live foal", "%d %% this season (mare %d yo, fertility %d %%)" % [roundi(p.p_live * 100.0), int(m.age), roundi(Stud.mare_age_factor(m) * 100.0)])
	_row(grid, "Chance the foal races", "%d %%" % roundi(p.raced * 100.0))
	var pr := Stud.progeny(s)
	_row(grid, "Stallion's offspring", "%d runners · %d winners · %d stakes · AEI %s" % [pr.runners, pr.winners, pr.graded, "%.2f" % pr.aei if pr.runners > 0 else "-"])
	var note := UiTheme.dim_label("Estimates use breeding values (what the records tell us), not the hidden genes. Nicks have no proven genetic effect — the cross record is for information.", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	right.add_child(br)
	var booked: bool = r.plan != null and int(r.plan) == sel_stallion
	var bb := Button.new()
	bb.text = "Cancel booking" if booked else "Book %s for %s ›" % [s.name, m.name]
	bb.custom_minimum_size = Vector2(0, 40)
	bb.disabled = (r.due > 0 and not Stud.in_season() and r.next == null and false)
	bb.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PURPLE, Color(0, 0, 0, 0), 4, 12))
	bb.pressed.connect(func():
		if booked:
			Stud.cancel(mare_id); shell.toast("Booking cancelled")
		else:
			var res := Stud.book(mare_id, sel_stallion)
			shell.toast("Booked: %s will be covered at her next heat" % m.name if res == "ok" else "Cannot book: " + res)
		shell.open("breeding", ["planner", mare_id, sel_stallion], false))
	br.add_child(bb)
	var ob := Button.new()
	ob.text = "Open stallion"
	ob.pressed.connect(func(): shell.open_horse(sel_stallion))
	br.add_child(ob)

func _stars(r: float) -> float:
	return clampf(snappedf((r - 45.0) / 8.0, 0.5), 0.5, 5.0)

func _row(g: GridContainer, k: String, v: String, color := UiTheme.TEXT) -> void:
	var a := UiTheme.dim_label(k, 12)
	a.custom_minimum_size.x = 150
	g.add_child(a)
	var b := UiTheme.label(v, 13, color)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 330
	g.add_child(b)

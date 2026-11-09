class_name PersonPage
extends ScrollContainer
## Profile of an owner, trainer or jockey: who they are, their attributes, season records and horses.

var shell

func setup(s, kind: String, id: int) -> PersonPage:
	shell = s
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p: Dictionary
	match kind:
		"owners": p = Owners.owner(id)
		"trainers": p = People.trainer(id)
		_: p = People.jockey(id)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	if p.is_empty():
		v.add_child(UiTheme.dim_label("Not found.", 14)); return self
	var word: String = { "owners": "Owner", "trainers": "Trainer", "jockeys": "Jockey" }[kind]
	shell._set_title(String(p.name), word)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	# ---- who ----
	var a: VBoxContainer = shell._card("", top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	a.add_child(hb)
	if kind == "owners":
		var tr := TextureRect.new()
		tr.texture = Silks.preview(p.silks, 150, 125, "")
		tr.custom_minimum_size = Vector2(120, 100)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 2)
	hb.add_child(who)
	who.add_child(UiTheme.label(String(p.name), 24, UiTheme.STRONG))
	var yr := int(Career.W.year)
	match kind:
		"owners":
			who.add_child(UiTheme.label({ "club": "Racing club (一口馬主クラブ)", "company": "Company owner", "breeder": "Owner-breeder (farm)", "individual": "Individual owner" }.get(String(p.kind), ""), 14))
			who.add_child(UiTheme.label("Horses in training: %d" % Owners.horses_of(int(p.id)).size(), 14))
			who.add_child(UiTheme.dim_label("Buying budget about %s a year" % Game.money(float(p.budget)), 13))
		"trainers":
			who.add_child(UiTheme.label("%s Training Centre%s · age %d" % ["Miho" if p.centre == "miho" else "Ritto", " (centre estimated)" if p.get("centreGuess", false) else "", yr - int(p.born)], 14))
			who.add_child(UiTheme.label("Horses in the stable: %d" % _trained(int(p.id)).size(), 14))
			if not p.get("active", true): who.add_child(UiTheme.label("Retired", 14, UiTheme.BAD))
		_:
			var cl := People.claim(p, yr)
			who.add_child(UiTheme.label("Age %d · %s · licensed %d%s" % [yr - int(p.born), "female" if p.get("sex", "M") == "F" else "male", int(p.get("debut", yr)), ("  · apprentice %s%d kg" % [People.claim_mark(cl), cl]) if cl > 0 else ""], 14))
			who.add_child(UiTheme.label("Career wins: %d" % int(p.get("careerWins", 0)), 14))
			if not p.get("active", true): who.add_child(UiTheme.label("Retired", 14, UiTheme.BAD))
	if p.has("rec"):
		var r: Array = p.rec
		a.add_child(UiTheme.section("Real JRA record (your data file)"))
		a.add_child(UiTheme.label("%d wins · %d 2nds · %d 3rds · win rate %.1f %% · prize money ¥%.0fM" % [int(r[0]), int(r[1]), int(r[2]), float(r[4]), float(r[3])], 13))
	# ---- attributes ----
	if kind != "owners":
		var b: VBoxContainer = shell._card("Attributes", top)
		b.get_parent().custom_minimum_size.x = 430
		_bar(b, "Overall", float(p.skill), true)
		var at: Dictionary = People.tattr(p) if kind == "trainers" else People.jattr(p)
		for x in (People.TATTR if kind == "trainers" else People.JATTR):
			_bar(b, x[1], float(at[x[0]]))
		b.add_child(UiTheme.dim_label(_explain(kind), 11))
	else:
		var b2: VBoxContainer = shell._card("Connections", top)
		b2.get_parent().custom_minimum_size.x = 430
		b2.add_child(UiTheme.label("Favourite stables", 13, UiTheme.ACC))
		for tid in p.favT: _link(b2, "trainers", People.trainer(tid))
		b2.add_child(UiTheme.label("Favourite jockeys", 13, UiTheme.ACC))
		for jid in p.favJ: _link(b2, "jockeys", People.jockey(jid))
	# ---- seasons ----
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var sc: VBoxContainer = shell._card("Season by season", row)
	var t := Tree.new()
	t.hide_root = true; t.column_titles_visible = true
	var cols := ["Season", "Runs" if kind != "jockeys" else "Rides", "Wins", "2nd", "3rd", "Win %", "Prize ¥M"]
	t.columns = cols.size()
	for i in cols.size(): t.set_column_title(i, cols[i]); t.set_column_expand(i, true)
	t.custom_minimum_size.y = 220
	var root := t.create_item()
	var ys: Array = p.get("y", {}).keys()
	ys.sort(); ys.reverse()
	for y in ys:
		var st: Array = p.y[y]
		var it := t.create_item(root)
		it.set_text(0, str(y)); it.set_text(1, str(st[0])); it.set_text(2, str(st[1])); it.set_text(3, str(st[2])); it.set_text(4, str(st[3]))
		it.set_text(5, "%.1f" % (100.0 * float(st[1]) / maxf(1.0, float(st[0])))); it.set_text(6, "%.1f" % float(st[4]))
	if ys.is_empty():
		var it2 := t.create_item(root); it2.set_text(0, "No runs yet")
	sc.add_child(t)
	if kind == "owners":
		var g: VBoxContainer = shell._card("G1 wins", row)
		var g1: Array = p.get("g1", [])
		for k in range(g1.size() - 1, maxi(-1, g1.size() - 13), -1):
			g.add_child(UiTheme.label("%d  %s — %s" % [int(g1[k].y), g1[k].race, g1[k].horse], 13))
		if g1.is_empty(): g.add_child(UiTheme.dim_label("None yet in this world.", 13))
	# ---- horses ----
	if kind != "jockeys":
		var hc: VBoxContainer = shell._card("Horses", v)
		var ht := HorseTable.new(["name", "age", "sex", "style", "tier", "ab", "form", "status"])
		ht.custom_minimum_size.y = 360
		ht.horse_opened.connect(shell.open_horse)
		ht.set_horses(Owners.horses_of(int(p.id)) if kind == "owners" else _trained(int(p.id)))
		hc.add_child(ht)
	return self

func _trained(tid: int) -> Array:
	return Career.active().filter(func(h): return int(h.get("c", {}).get("trainer", -1)) == tid)

func _bar(parent: Control, label: String, val: float, strong := false) -> void:
	var r := HBoxContainer.new()
	var l := UiTheme.label(label, 13, UiTheme.STRONG if strong else UiTheme.TEXT)
	l.custom_minimum_size.x = 130
	r.add_child(l)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL2, Color(0, 0, 0, 0), 3, 0))
	bg.custom_minimum_size = Vector2(220, 14)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = UiTheme.stat_color(val)
	fill.custom_minimum_size = Vector2(220.0 * clampf(val / 100.0, 0.0, 1.0), 14)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_child(fill)
	r.add_child(bg)
	r.add_child(UiTheme.label(str(roundi(val)), 13, UiTheme.stat_color(val)))
	parent.add_child(r)

func _link(parent: Control, kind: String, p: Dictionary) -> void:
	if p.is_empty(): return
	var b := Button.new()
	b.flat = true
	b.text = "%s  (skill %d)" % [p.name, roundi(float(p.skill))]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", UiTheme.TEXT)
	b.add_theme_color_override("font_hover_color", UiTheme.ACC)
	var pid := int(p.id)
	b.pressed.connect(func(): shell.open("person", [kind, pid]))
	parent.add_child(b)

func _explain(kind: String) -> String:
	if kind == "trainers":
		return "Conditioning: fitness gained from each week of work. Horse care: lower injury risk. Young horses: development of 2- and 3-year-olds. Race planning: horses peak for race day. Estimates around the overall skill from the real record."
	return "Gate start: quicker break. Pace judgement: saves energy, rates the horse well. Finishing drive: stronger late kick. Positioning: finds gaps, avoids traffic. Big-race nerve: better or worse in G1/G2. Turf/Dirt: surface strength. Estimates around the overall skill from the real record."

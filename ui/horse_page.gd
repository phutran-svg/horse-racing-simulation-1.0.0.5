class_name HorsePage
extends VBoxContainer
## Horse profile in the style of FM's player screen: tabs Overview · Race entries · History · Pedigree.

var shell
var h: Dictionary
var tab := "overview"
var body: Control
var hv: Dictionary      # what we believe (scouting estimates)

func setup(game_shell, horse: Dictionary, start_tab := "overview") -> HorsePage:
	shell = game_shell
	h = horse
	hv = Game.view(horse)
	tab = start_tab
	shell._set_title(h.name, "%s · %s" % [Game.summary(h), Game.status_text(h)])
	add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 22)
	var tl: Array = [["overview", "Overview"], ["training", "Training"], ["entries", "Race entries"], ["history", "History"], ["pedigree", "Pedigree"]]
	var st: String = h.get("c", {}).get("status", "")
	if st == "stud" or st == "broodmare" or Stud.progeny(h).foals > 0: tl.append(["stud", "Stud record"])
	for t in tl:
		var b := Button.new()
		b.text = t[1]
		b.flat = true
		b.add_theme_color_override("font_color", UiTheme.ACC if t[0] == tab else UiTheme.DIM)
		b.add_theme_color_override("font_hover_color", UiTheme.STRONG)
		b.pressed.connect(func(): shell.open_horse(int(h.id), t[0]))
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
	v.add_child(_header())
	match tab:
		"overview": _overview(v)
		"entries": _entries(v)
		"training": _training(v)
		"history": _history(v)
		"pedigree": _pedigree(v)
		"stud": _stud(v)
	return self


# ---------------- helpers ----------------
func _card(title: String, parent: Control, expand := true) -> VBoxContainer:
	var pc := PanelContainer.new()
	if expand: pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	if title != "": v.add_child(UiTheme.section(title))
	return v

func _kv(parent: Control, k: String, val: String, color := UiTheme.TEXT) -> void:
	var l := UiTheme.dim_label(k.to_upper(), 11)
	parent.add_child(l)
	var x := UiTheme.label(val, 14, color)
	x.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(x)

func _link(text: String, id) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", UiTheme.MINE)
	b.add_theme_color_override("font_hover_color", UiTheme.STRONG)
	if id != null: b.pressed.connect(func(): shell.open_horse(int(id)))
	return b


# ---------------- header strip ----------------
func _header() -> Control:
	var pc := PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	pc.add_child(hb)
	hb.add_child(HorsePortrait.new().setup(h))          # live 3D portrait: coat, markings, grey shade by age
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", 1)
	a.add_child(UiTheme.label(h.name, 22, UiTheme.STRONG))
	var fw := int(h.get("foaled", 0))
	a.add_child(UiTheme.label("%d years old  (foaled %s)" % [int(h.get("age", 0)), Game.date_text(int(h.get("c", {}).get("born", Career.W.year - int(h.get("age", 0)))), fw).substr(4) if fw > 0 else str(int(h.get("c", {}).get("born", Career.W.year - int(h.get("age", 0)))))], 14))
	a.add_child(UiTheme.dim_label("%s %s · %s" % [Markings.coat_text(h).substr(0, 1).to_upper() + Markings.coat_text(h).substr(1), Game.sex_word(h), RaceEngine.GENES[h.gene].label], 12))
	a.add_child(UiTheme.dim_label(Markings.describe(h), 12))
	hb.add_child(a)
	var sep := VSeparator.new()
	hb.add_child(sep)
	var b := VBoxContainer.new()
	b.custom_minimum_size.x = 260
	b.add_theme_constant_override("separation", 2)
	var own_txt := Owners.name_of(h)
	if Game.is_mine(h):
		var ow := String(h.get("c", {}).get("owner", ""))
		own_txt = ("%s · trained by you" % ow) if ow != "" else Career.W.get("stable_name", "your stable")
	if not Game.is_mine(h) and not Owners.of(h).is_empty():
		var ob := Button.new()
		ob.flat = true
		ob.text = "Owned by %s ›" % own_txt
		ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ob.add_theme_font_size_override("font_size", 12)
		ob.add_theme_color_override("font_color", UiTheme.ACC)
		var oid := int(Owners.of(h).id)
		ob.pressed.connect(func(): shell.open("person", ["owners", oid]))
		b.add_child(ob)
	else:
		b.add_child(UiTheme.dim_label("Owned by %s" % own_txt, 12))
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL2, Color(0, 0, 0, 0), 12, 10))
	pill.add_child(UiTheme.label(Game.money(Game.value(h)), 16, UiTheme.STRONG))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_child(pill)
	b.add_child(UiTheme.dim_label("Estimated value · %s" % Career.tier_of(h), 12))
	_trade_buttons(b, h)
	hb.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 2)
	c.add_child(UiTheme.dim_label("Trainer's assessment", 12))
	var ab := Game.ability_stars(h)
	c.add_child(UiTheme.label("%s  %s" % [UiTheme.stars(ab), _verdict(ab)], 15, UiTheme.ACC))
	c.add_child(UiTheme.dim_label("POTENTIAL", 10))
	c.add_child(UiTheme.label(UiTheme.stars(Game.potential_stars(h)), 15, UiTheme.ACC))
	var kn := Stud.know(h)
	c.add_child(UiTheme.dim_label("Scouting knowledge %d%%%s" % [roundi(kn * 100.0), "" if kn >= 0.9 else " · stats are estimates (±%d)" % Stud.est_range(h)], 11))
	if h.get("real", false) and not h.get("anon", false):
		c.add_child(UiTheme.dim_label("Real horse%s: name and pedigree are real, stats are game estimates" % (" · standing in %s" % h.abroad if h.has("abroad") else ""), 11))
	if Game.is_mine(h) and Finance.owns(h):
		var cs: String = h.get("c", {}).get("status", "")
		if (cs == "active" and int(h.get("age", 0)) >= 3) or cs == "retired":
			var rb := Button.new()
			rb.text = "Retire to stud ›" if h.sex == "M" else "Retire to breeding ›"
			rb.tooltip_text = "End the racing career. Colts stand at stud (other breeders pay you fees); fillies become broodmares."
			rb.pressed.connect(func():
				var dlg := ConfirmationDialog.new()
				dlg.dialog_text = "Retire %s from racing and send %s to the %s?" % [h.name, "him" if h.sex == "M" else "her", "stud farm" if h.sex == "M" else "breeding shed"]
				dlg.confirmed.connect(func():
					Stud.to_stud(h)
					shell.open_horse(int(h.id), "stud"))
				add_child(dlg)
				dlg.popup_centered())
			c.add_child(rb)
	hb.add_child(c)
	return pc

func _verdict(ab: float) -> String:
	var age := int(h.get("age", 3))
	var t := "G1 class" if ab >= 4.5 else ("Graded class" if ab >= 3.5 else ("Open class" if ab >= 2.5 else ("Winners' class" if ab >= 1.5 else "Maiden class")))
	return t + (" · in his prime" if age >= 4 and age <= 5 and h.sex == "M" else (" · in her prime" if age >= 4 and age <= 5 else (" · still developing" if age <= 3 else "")))


# ---------------- overview ----------------
func _overview(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	# left: distance & surface, running style
	var left := _card("Distance & surface", row, false)
	left.get_parent().custom_minimum_size.x = 330
	var chart := AptitudeChart.new()
	chart.h = hv
	chart.custom_minimum_size = Vector2(300, 150)
	left.add_child(chart)
	left.add_child(UiTheme.dim_label("Best distance about %d m · %s" % [int(Career.best_dist(hv) / 50.0) * 50, Game.surface_label(h)], 12))
	left.add_child(UiTheme.section("Running style"))
	for st in ["front", "stalker", "mid", "closer"]:
		var r := HBoxContainer.new()
		var s := UiTheme.label(UiTheme.stars(Game.style_fit(h, st)), 14, UiTheme.ACC)
		s.custom_minimum_size.x = 96
		r.add_child(s)
		r.add_child(UiTheme.label(RaceEngine.STYLES[st].label + ("   (natural)" if h.style == st else ""), 13, UiTheme.STRONG if h.style == st else UiTheme.DIM))
		left.add_child(r)
	# middle: attributes
	var mid := _card("", row)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	mid.add_child(cols)
	var key := _key_stats()
	for grp in [["PHYSICAL", ["speed", "accel", "stamina", "strength", "burst"]], ["MENTAL", ["guts", "temper", "agility"]], ["HEALTH", ["sound", "wind"]]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		col.add_child(UiTheme.label(grp[0], 12, UiTheme.STRONG))
		for k in grp[1]: col.add_child(_attr_row(RaceEngine.STAT_LABEL[k], int(hv.stats[k]), key.has(k), RaceEngine.STAT_INFO[k], Stud.est_range(h)))
		if grp[0] == "HEALTH":
			col.add_child(UiTheme.label("GENETICS", 12, UiTheme.STRONG))
			col.add_child(_attr_row("Dirt aptitude", int(hv.get("dirt", 50)), false, "0 = pure turf type, 100 = pure dirt type", Stud.est_range(h)))
			col.add_child(_text_row("Growth type", "%s (%d)" % [Game.growth_label(h), int(hv.get("grow", 50))], "When the horse reaches its best: early types are ready at 2, late developers improve at 4–5 (inherited)"))
			col.add_child(_text_row("Soft ground", "%s (%d)" % [Game.going_pref_label(h), int(hv.get("going", 50))], "How much a yielding/soft turf or muddy track costs this horse (inherited)"))
			col.add_child(_text_row("MSTN gene", h.gene, "C:C sprinter · C:T middle · T:T stayer (speed gene)"))
			col.add_child(_text_row("Inbreeding", "%.1f %%" % (float(h.get("F", 0.0)) * 100.0), "Wright's inbreeding coefficient"))
			col.add_child(_text_row("Body weight", "%d kg" % Game.weight_now(h), "Body weight now (birth weight %s)" % (str(h.birthW) + " kg" if h.has("birthW") else "unknown")))
			col.add_child(_text_row("Sire line", Stud.sire_line(h), "Male line: the founder stallion at the top of the sire line"))
			col.add_child(_text_row("Family", Stud.family(h), "Female family: the founder mare at the bottom of the dam line"))
		cols.add_child(col)
	# right: info + biography
	var right := _card("", row, false)
	right.get_parent().custom_minimum_size.x = 300
	_kv(right, "Reputation", Career.tier_of(h))
	var c0 = h.get("c")
	if c0 != null and (c0.get("mark") != null or c0.get("rtPrev") != null):
		var y := int(Career.W.year)
		_kv(right, "Official rating", "%s (%d) · last year %s" % [RatingsPage.rt_text(Ratings.year_best(h, y)), y, RatingsPage.rt_text(Ratings.year_best(h, y - 1))])
		if c0.get("mark") != null: _kv(right, "Handicap mark", "%d lb · career best %d" % [int(c0.mark), int(Ratings.career_best(h))])
	_kv(right, "Preferred surface", Game.surface_label(h))
	_kv(right, "Growth type", Game.growth_label(h))
	_kv(right, "Ground", Game.going_pref_label(h))
	_kv(right, "Personality", Game.personality(h))
	_kv(right, "Media description", "%s %s" % [Game.distance_label(h), "with a strong finishing burst" if int(hv.stats.burst) >= 75 else ("who likes to lead" if h.style == "front" else "")])
	right.add_child(UiTheme.section("Biography"))
	var bio := UiTheme.label(_biography(), 13)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size.x = 270
	right.add_child(bio)
	# bottom cards
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	var c: Dictionary = h.get("c", {})
	var fit := _card("Fitness", g)
	_kv(fit, "Condition", "%d %%" % roundi(100.0 * float(c.get("fit", 0.7))) if c.has("fit") else "-")
	_kv(fit, "Fatigue", ("Fresh" if float(c.get("fat", 0.0)) < 0.3 else ("Tired" if float(c.get("fat", 0.0)) > 0.8 else "Some fatigue")) if c.has("fat") else "-")
	_kv(fit, "Injury", Career.injury_text(h) if c.has("out") else "Fit", _inj_col(h))
	var form := _card("Form", g)
	var hist: Array = c.get("history", [])
	if hist.is_empty(): form.add_child(UiTheme.dim_label("No races yet", 13))
	for x in hist.slice(0, 5):
		form.add_child(UiTheme.label("%s  %s/%s  %s" % [str(x.pos), "", str(x.get("of", "")), x.race], 12, UiTheme.ACC if str(x.pos) == "1" else UiTheme.TEXT))
	var plans := _card("Next race", g)
	var entry = c.get("entry")
	var er = null
	for r in Career.W.get("races", []):
		if entry != null and r.id == entry: er = r
	if er != null: _kv(plans, "Entered", "%s · %s %d m" % [er.name, RaceEngine.COURSES[er.course].short, er.dist], UiTheme.GOOD)
	else: plans.add_child(UiTheme.dim_label(("Not entered this week" if int(h.get("age", 0)) >= 2 else "Too young to race (newcomer races from June at 2)") if c.get("status", "") == "active" else "-", 13))
	if Game.is_mine(h) and c.get("status", "") == "active" and int(h.get("age", 0)) >= 2:
		var eb := Button.new()
		eb.text = "Choose a race ›"
		eb.pressed.connect(func(): shell.open_horse(int(h.id), "entries"))
		plans.add_child(eb)
	var wins := _card("Big wins", g)
	var bw: Array = c.get("bigWins", [])
	if bw.is_empty(): wins.add_child(UiTheme.dim_label("None yet", 13))
	for x in bw.slice(0, 6): wins.add_child(UiTheme.label("🏆 " + x, 12, UiTheme.ACC))
	var tr := _card("Training", g)
	var lw: Array = c.get("lastWork", [])
	_kv(tr, "Last week", ("%s · %s" % [Training.WORKS[lw[0]][0], Training.INTENSITY[lw[1]][0]]) if lw.size() == 2 else "-")
	_kv(tr, "Mood", Training.mood_text(float(c.get("mood", 60.0))))
	_kv(tr, "Trainer", _trainer_name(h))
	if Game.is_mine(h):
		var tb := Button.new()
		tb.text = "Training plan ›"
		tb.pressed.connect(func(): shell.open_horse(int(h.id), "training"))
		tr.add_child(tb)
	var own := _card("Ownership", g)
	var ow := String(c.get("owner", ""))
	_kv(own, "Owner", (ow if ow != "" and ow != "ai" else Career.W.get("stable_name", "You")) if Game.is_mine(h) else Owners.name_of(h))
	_kv(own, "Earnings", Game.money(float(c.get("earn", 0.0))))
	_kv(own, "Class money", "%.1f M" % float(c.get("cm", 0.0)))
	var st := _card("Status", g)
	_kv(st, "Status", Game.status_text(h))
	_kv(st, "Class", Career.class_of(c) if c.has("wins") else "-")
	var ss := _card("Career stats", g)
	if h.get("real", false) and not h.get("anon", false):
		_kv(ss, "Runs / wins", ("%d / %d (real record)" % [int(h.rec[0]), int(h.rec[1])]) if h.has("rec") else "—")
	else:
		_kv(ss, "Runs / wins / places", "%d / %d / %d" % [int(c.get("starts", 0)), int(c.get("wins", 0)), int(c.get("places", 0))])
	_kv(ss, "Graded wins", "%d (G1: %d)" % [int(c.get("graded", 0)) + int(c.get("g1", 0)), int(c.get("g1", 0))])

func _key_stats() -> Array:
	var bd := Career.best_dist(hv)
	if bd < 1400: return ["speed", "accel", "burst"]
	if bd < 2000: return ["speed", "burst", "stamina"]
	return ["stamina", "guts", "speed"]

func _attr_row(name: String, val: int, key: bool, tip: String, rng := 0) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(Color(0.25, 0.5, 0.85, 0.16) if key else UiTheme.TINT, Color(0, 0, 0, 0), 2, 8))
	pc.tooltip_text = tip
	var r := HBoxContainer.new()
	pc.add_child(r)
	var n := UiTheme.label(name, 14)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(n)
	if rng > 3:
		r.add_child(UiTheme.label("%d–%d" % [maxi(1, val - rng), mini(100, val + rng)], 14, UiTheme.stat_color(val)))
	else: r.add_child(UiTheme.label(str(val), 14, UiTheme.stat_color(val)))
	return pc

func _text_row(name: String, val: String, tip: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.TINT, Color(0, 0, 0, 0), 2, 8))
	pc.tooltip_text = tip
	var r := HBoxContainer.new()
	pc.add_child(r)
	var n := UiTheme.label(name, 14)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(n)
	r.add_child(UiTheme.label(val, 14, UiTheme.STRONG))
	return pc

func _biography() -> String:
	var c: Dictionary = h.get("c", {})
	var t := "%s is a %s %s %s. " % [h.name, Markings.coat_text(h), Game.sex_word(h), Breeding.byline(h)]
	var mk := Markings.describe(h)
	if mk != "No white markings": t += "Markings: %s. " % mk.to_lower()
	if h.get("real", false) and not h.get("anon", false):
		if h.has("rec"): t += "Real race record: %d starts, %d wins%s." % [int(h.rec[0]), int(h.rec[1]), (", %d G1" % int(h.rec[2])) if int(h.rec[2]) > 0 else ""]
		else: t += "A real horse; race record not included in the game."
		return t
	if int(c.get("starts", 0)) == 0: t += "Unraced so far."
	else:
		t += "From %d starts %s has won %d race%s and earned %s." % [int(c.starts), "she" if h.sex == "F" else "he", int(c.wins), "" if int(c.wins) == 1 else "s", Game.money(float(c.get("earn", 0.0)))]
		var bw: Array = c.get("bigWins", [])
		if not bw.is_empty(): t += " Biggest wins: %s." % ", ".join(bw.slice(0, 3))
	return t


# ---------------- race entries ----------------
func _entries(v: VBoxContainer) -> void:
	_this_week(v)
	if Game.is_mine(h) and String(h.get("c", {}).get("status", "")) == "active" and int(h.get("age", 0)) >= 1: _plan(v)

## race plan: targets in the coming weeks (graded races by name, or a condition race with surface and distance)
func _plan(v: VBoxContainer) -> void:
	var card := _card("Race plan", v)
	var pl: Array = Career.plan_of(h)
	if pl.is_empty(): card.add_child(UiTheme.dim_label("No targets yet. Plan this horse's next races: it is entered automatically when that week's fields are declared.", 13))
	for i in pl.size():
		var t: Dictionary = pl[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UiTheme.label("%s  ·  %s" % [Game.date_text(int(t.y), int(t.w)), Career.plan_text(t)], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var warn := Career.plan_warnings(h, t)
		if not warn.is_empty(): row.add_child(UiTheme.label("⚠ " + ", ".join(warn), 12, UiTheme.BAD))
		var rb := Button.new(); rb.text = "Remove"
		rb.pressed.connect(func(): Career.plan_remove(h, i); shell.open_horse(int(h.id), "entries"))
		row.add_child(rb)
		card.add_child(row)
	# add a target
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 8)
	card.add_child(add)
	var wk_opt := OptionButton.new()
	var weeks: Array = []
	for k in range(1, 27):       # the next half year
		var w := int(Career.W.week) + k
		var y := int(Career.W.year)
		if w > 52: w -= 52; y += 1
		weeks.append([y, w])
		var gn: Array = []
		for g in Career.GRADED:
			if int(g[2]) == w: gn.append("%s %s" % [g[1], g[0]])
		wk_opt.add_item("%s%s" % [Game.date_text(y, w), ("  — " + ", ".join(gn)) if not gn.is_empty() else ""])
	add.add_child(wk_opt)
	var race_opt := OptionButton.new()
	race_opt.custom_minimum_size.x = 260
	add.add_child(race_opt)
	var surf_opt := OptionButton.new()
	for x in ["Any surface", "Turf", "Dirt"]: surf_opt.add_item(x)
	add.add_child(surf_opt)
	var dist_opt := OptionButton.new()
	var bands := [[0, 0, "Any distance"], [1000, 1400, "Sprint 1000–1400 m"], [1500, 1800, "Mile 1500–1800 m"], [1900, 2200, "Middle 1900–2200 m"], [2300, 2600, "Classic 2300–2600 m"], [2700, 3600, "Long 2700 m+"]]
	for b in bands: dist_opt.add_item(b[2])
	var bd := Career.best_dist(h)
	for k in range(1, bands.size()):
		if bd >= bands[k][0] - 50 and bd <= bands[k][1] + 50: dist_opt.select(k); break
	if int(h.dirt) >= 55: surf_opt.select(2)
	elif int(h.dirt) <= 45: surf_opt.select(1)
	add.add_child(dist_opt)
	var fill_races := func() -> void:
		race_opt.clear()
		race_opt.add_item("Condition race")
		race_opt.set_item_metadata(0, "")
		var yw: Array = weeks[wk_opt.selected]
		for g in Career.GRADED:
			if int(g[2]) == int(yw[1]):
				race_opt.add_item("%s %s (%s %d m)" % [g[1], g[0], RaceEngine.COURSES[g[3]].short, int(g[4])])
				race_opt.set_item_metadata(race_opt.item_count - 1, g[0])
		if race_opt.item_count > 1: race_opt.select(1)
		surf_opt.disabled = race_opt.selected > 0
		dist_opt.disabled = race_opt.selected > 0
	fill_races.call()
	wk_opt.item_selected.connect(func(_i): fill_races.call())
	race_opt.item_selected.connect(func(i):
		surf_opt.disabled = i > 0
		dist_opt.disabled = i > 0)
	var ab := Button.new(); ab.text = "+ Add target"
	ab.pressed.connect(func():
		var yw: Array = weeks[wk_opt.selected]
		var t := { "y": int(yw[0]), "w": int(yw[1]), "race": String(race_opt.get_item_metadata(race_opt.selected)) }
		if t.race == "":
			t["surf"] = ["any", "turf", "dirt"][surf_opt.selected]
			t["dmin"] = int(bands[dist_opt.selected][0]); t["dmax"] = int(bands[dist_opt.selected][1])
		var res := Career.plan_add(h, t)
		if res != "ok": shell.toast(res)
		else:
			var warn := Career.plan_warnings(h, t)
			if not warn.is_empty(): shell.toast("Planned — note: " + ", ".join(warn))
		shell.open_horse(int(h.id), "entries"))
	add.add_child(ab)
	card.add_child(UiTheme.dim_label("Trainers usually give a horse 3–6 weeks between races (more after a big race or a long trip). If a target can't be met when the week comes (injury, not qualified, no matching race), you'll see it in the news.", 11))

func _this_week(v: VBoxContainer) -> void:
	var card := _card("Races this week (%s)" % Game.now_text(), v)
	var c: Dictionary = h.get("c", {})
	if not Game.is_mine(h):
		card.add_child(UiTheme.dim_label("Only your own horses can be entered.", 13)); return
	if c.get("status", "") != "active" or int(h.get("age", 0)) < 2:
		card.add_child(UiTheme.dim_label("This horse cannot race.", 13)); return
	if int(c.get("out", 0)) > 0:
		card.add_child(UiTheme.dim_label("Injured: out for %d more weeks." % int(c.out), 13)); return
	if int(c.get("sore", 0)) > 0:
		card.add_child(UiTheme.label("Caution: sore for %d more weeks: the horse can run, but its risk of breaking down in a race is ×%.1f." % [int(c.sore), Career.CAUTION_RISK], 13, UiTheme.BAD))
	var since := Career.since(h)
	if since < 2:
		card.add_child(UiTheme.dim_label("Raced last week: needs at least 2 weeks between races.", 13))
	var any := false
	for r in Career.W.races:
		if not Career.eligible(h, r): continue
		any = true
		var row := HBoxContainer.new()
		var s := Game.suit(h, r.dist, RaceEngine.COURSES[r.course].surface == "dirt")
		var name := UiTheme.label("%s  ·  %s %d m (%s)  ·  %s" % [r.name, RaceEngine.COURSES[r.course].short, r.dist, "dirt" if RaceEngine.COURSES[r.course].surface == "dirt" else "turf", r.cls], 14)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(UiTheme.label("Suits: " + UiTheme.stars(clampf(snappedf(s * 5.0, 0.5), 0.5, 5.0)), 13, UiTheme.ACC))
		var b := Button.new()
		var entered: bool = c.get("entry") == r.id
		b.text = "✓ Entered" if entered else "Enter"
		b.disabled = since < 2 and not entered
		b.pressed.connect(func():
			if entered: c.entry = null
			else:
				var res := Career.enter(int(h.id), int(r.id))
				if res != "ok": shell.toast(res)
			shell.open_horse(int(h.id), "entries"))
		row.add_child(b)
		card.add_child(row)
	if not any: card.add_child(UiTheme.dim_label("No suitable races this week. Press Continue to move to the next week.", 13))


# ---------------- history ----------------
func _history(v: VBoxContainer) -> void:
	var card := _card("Race record", v)
	var t := Tree.new()
	t.hide_root = true
	t.columns = 7
	t.column_titles_visible = true
	t.custom_minimum_size.y = 420
	for i in 7: t.set_column_title(i, ["Date", "Race", "Course", "Class", "Pos", "Time", "Rating"][i])
	t.set_column_expand(1, true)
	var root := t.create_item()
	for x in h.get("c", {}).get("history", []):
		var it := t.create_item(root)
		it.set_text(0, Game.date_text(int(x.y), int(x.w)))
		it.set_text(1, x.race)
		it.set_text(2, "%s %d m" % [RaceEngine.COURSES[x.course].short, int(x.dist)])
		it.set_text(3, x.cls)
		it.set_text(4, "%s/%s" % [str(x.pos), str(x.get("of", ""))])
		it.set_text(5, RaceEngine.fmt_time(float(x.time)) if x.time != null else "-")
		it.set_text(6, str(int(x.rt)) if x.get("rt") != null else "-")
		if str(x.pos) == "1":
			for k in 7: it.set_custom_color(k, UiTheme.ACC)
	card.add_child(t)
	card.add_child(UiTheme.dim_label("The last 12 runs are kept. Rating = the handicapper's performance rating for the run (lb).", 11))


# ---------------- pedigree ----------------
func _pedigree(v: VBoxContainer) -> void:
	var card := _card("Pedigree · 5 generations (血統表)", v)
	var s = Breeding.get_horse(h.sire)
	var d = Breeding.get_horse(h.dam)
	# duplicated ancestors (JRA style "Sunday Silence 3×4"), from the parents' pedigrees
	var dups: Array = Stud.duplicates(s, d, 5) if s != null and d != null else []
	var dup_ids := {}
	for x in dups: dup_ids[int(x.id)] = x.label
	# columns: generation 1 (2 cells) … generation 5 (32 cells), each cell spans 2^(5-g) rows
	var ROW := 22.0
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	card.add_child(hb)
	var gen: Array = [[s, d]]
	for gi in 4:
		var nxt: Array = []
		for x in gen[gi]:
			nxt.append(Breeding.get_horse(x.sire) if x != null else null)
			nxt.append(Breeding.get_horse(x.dam) if x != null else null)
		gen.append(nxt)
	var known := 0
	for gi in 5:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		var cells: Array = gen[gi]
		var span := 32 / cells.size()
		for ci in cells.size():
			var x = cells[ci]
			var male := ci % 2 == 0
			var dup: bool = x != null and dup_ids.has(int(x.id))
			if x != null: known += 1
			var pc := PanelContainer.new()
			pc.custom_minimum_size = Vector2(0, ROW * span - 1.0)
			pc.add_theme_stylebox_override("panel", UiTheme.box(Color("dde8f7") if male else Color("f7e1e8"), UiTheme.GOLD if dup else UiTheme.LINE, 3, 4, 2 if dup else 1))
			var vb := VBoxContainer.new()
			vb.alignment = BoxContainer.ALIGNMENT_CENTER
			vb.add_theme_constant_override("separation", 0)
			pc.add_child(vb)
			if x == null:
				vb.add_child(UiTheme.label("(not recorded)", 10, UiTheme.DIM))
			else:
				var lk := _link(x.name, x.id)
				lk.add_theme_font_size_override("font_size", 12 if gi < 4 else 11)
				vb.add_child(lk)
				if span >= 2:
					var yr := int(x.get("born", 0))
					vb.add_child(UiTheme.dim_label("%s%s" % ["%d · " % yr if yr > 0 else "", x.get("coat", "")], 10))
			col.add_child(pc)
	card.add_child(UiTheme.dim_label("%d of 62 ancestors recorded. Real names, years and parents come from the open-horse-data set (credits: Sheep Meadow Road Games / Horse Racing Manager) plus well-documented famous pedigrees; 'not recorded' means the data doesn't name that horse." % known, 11))
	var dl: PackedStringArray = []
	for x in dups: dl.append("%s %s" % [x.name, x.label])
	card.add_child(UiTheme.label("Inbreeding: %s" % (", ".join(dl) if not dl.is_empty() else "no duplicated ancestors in 5 generations"), 13, UiTheme.ACC if not dl.is_empty() else UiTheme.TEXT))
	card.add_child(UiTheme.dim_label("Inbreeding coefficient F = %.2f %% · MSTN %s (from %s × %s) · sire line: %s · family: %s" % [float(h.get("F", 0.0)) * 100.0, h.mstn, s.mstn if s != null else "?", d.mstn if d != null else "?", Stud.sire_line(h), Stud.family(h)], 12))


## distance (x) × surface (rows) aptitude, like FM's position pitch
class AptitudeChart extends Control:
	var h: Dictionary
	func _draw() -> void:
		var font := get_theme_default_font()
		var dists := [1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 3000, 3200, 3600]
		var W := size.x
		var x0 := 48.0
		var cw := (W - x0 - 6.0) / dists.size()
		draw_rect(Rect2(Vector2(x0 - 4, 0), Vector2(W - x0 + 4, 104)), Color("2f6d3a"), true)
		for row in 2:
			var dirt := row == 1
			var y := 28.0 + row * 48.0
			draw_string(font, Vector2(0, y + 5), "Dirt" if dirt else "Turf", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.DIM)
			for k in dists.size():
				var s := Game.suit(h, dists[k], dirt)
				var c := Color("3ee07a") if s > 0.85 else (Color("b7e04a") if s > 0.7 else (Color("e8c45a") if s > 0.5 else Color(1, 1, 1, 0.18)))
				draw_circle(Vector2(x0 + cw * (k + 0.5), y), 8.0, c)
		for k in dists.size():
			if k % 2 == 0:
				draw_string(font, Vector2(x0 + cw * k - 6, 124), str(dists[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.DIM)
		draw_string(font, Vector2(x0, 142), "● ideal   ● good   ● fair", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.DIM)


# ---------------- stud record ----------------
func _stud(v: VBoxContainer) -> void:
	var c: Dictionary = h.get("c", {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var a := _card("At stud" if h.sex == "M" else "Broodmare", row)
	if h.sex == "M" and c.get("status", "") == "stud":
		var sd := Stud.stud(h)
		_kv(a, "Stud fee (on a live foal)", Game.money(float(sd.fee)), UiTheme.ACC)
		_kv(a, "This season's book", "%d of %d mares" % [int(sd.book), int(sd.cap)])
		_kv(a, "At stud since", str(int(sd.get("since", Career.W.year))))
		_kv(a, "Sire line", Stud.sire_line(h))
		if Game.is_mine(h):
			a.add_child(UiTheme.dim_label("Your stallion: other breeders pay you his fee for each live foal.", 12))
			var fr := HBoxContainer.new()
			var sp := SpinBox.new()
			sp.min_value = 0.3; sp.max_value = 30.0; sp.step = 0.1; sp.value = float(sd.fee); sp.suffix = "¥M"
			fr.add_child(sp)
			var fb := Button.new()
			fb.text = "Set fee"
			fb.pressed.connect(func(): Stud.set_fee(h, sp.value); shell.toast("Fee set to %s — a higher fee means fewer mares" % Game.money(sp.value)); shell.open_horse(int(h.id), "stud"))
			fr.add_child(fb)
			a.add_child(fr)
	elif h.sex == "F" and c.get("status", "") == "broodmare":
		var r := Stud.repro(h)
		_kv(a, "Status", Stud.mare_status(h), UiTheme.ACC)
		_kv(a, "Foals so far", str(int(r.parity)))
		_kv(a, "Fertility for her age", "%d %% of normal" % roundi(100.0 * Stud.mare_age_factor(h)))
		_kv(a, "Family", Stud.family(h))
		if Game.is_mine(h):
			var bb := Button.new()
			bb.text = "Plan a mating ›"
			bb.pressed.connect(func(): shell.open("breeding", ["planner", int(h.id)]))
			a.add_child(bb)
	else:
		a.add_child(UiTheme.dim_label("Not at stud.", 13))
	var pr := Stud.progeny(h)
	var b := _card("Offspring record", row)
	_kv(b, "Foals / runners", "%d / %d" % [pr.foals, pr.runners])
	_kv(b, "Winners", "%d (%d %% of runners)" % [pr.winners, roundi(100.0 * pr.winners / maxf(1.0, pr.runners))])
	_kv(b, "Stakes winners", "%d (G1 %d)" % [pr.graded, pr.g1])
	_kv(b, "Average earnings index (AEI)", "%.2f" % pr.aei if pr.runners > 0 else "-", UiTheme.GOOD if pr.aei >= 1.0 else UiTheme.TEXT)
	if pr.runners > 0:
		_kv(b, "Typical offspring", "best at about %d m · %s" % [int(pr.dist / 100.0) * 100, "dirt" if pr.dirt >= 60 else ("turf" if pr.dirt <= 40 else "turf & dirt")])
	if h.has("gv"):
		# what the horse tends to pass on (estimated breeding values; a foal gets half from each parent)
		var eg := Stud.ebv(h, "grow")
		var eo := Stud.ebv(h, "going")
		_kv(b, "Passes on", "%s maturity · %s on soft ground" % ["early" if eg >= 56 else ("late" if eg <= 44 else "normal"),
			"better" if eo >= 56 else ("worse" if eo <= 44 else "average")])
	var acc := Stud.accuracy(h, "speed")
	b.add_child(UiTheme.dim_label("Breeding-value accuracy: %d %% (grows as more offspring race)" % roundi(acc * 100.0), 12))
	var kids: Array = Breeding.book.values().filter(func(x): return x.get("sire") == h.id or x.get("dam") == h.id)
	kids.sort_custom(func(x, y): return int(x.get("age", 0)) < int(y.get("age", 0)))
	var k := _card("Offspring (%d)" % kids.size(), v)
	var t := HorseTable.new(["name", "age", "sex", "tier", "ab", "starts", "wins", "earn", "sire" if h.sex == "F" else "owner"])
	t.custom_minimum_size.y = 40 + 32 * mini(12, kids.size())
	t.horse_opened.connect(func(id): shell.open_horse(id))
	t.set_horses(kids)
	k.add_child(t)


## Step 4A — private sales: sell your own horse, or buy one that is on the market
func _trade_buttons(parent: Control, h: Dictionary) -> void:
	if Career.W.get("player", {}).is_empty(): return
	if Game.is_mine(h) and Finance.owns(h):
		var sales := Auction.eligible_sales(h)
		var cons := String(h.get("c", {}).get("consign", ""))
		if cons != "":
			var cb := Button.new()
			cb.text = "Entered: %s — withdraw" % Auction.sale(cons).name
			cb.pressed.connect(func(): h.c.erase("consign"); shell.open_horse(int(h.id)))
			parent.add_child(cb)
		elif not sales.is_empty():
			var ob := OptionButton.new()
			ob.add_item("Consign to a sale…", -1)
			for i in sales.size(): ob.add_item("%s (week %d) · estimate %s" % [sales[i].name, int(sales[i].week), Game.money(Auction.sale_estimate(h, sales[i].key))], i)
			ob.item_selected.connect(func(i):
				var k := ob.get_item_id(i)
				if k < 0: return
				h.c["consign"] = sales[k].key
				h.c["reserve"] = snappedf(Auction.sale_estimate(h, sales[k].key) * 0.5, 0.1)
				shell.toast("%s entered in the %s (reserve %s)" % [h.name, sales[k].name, Game.money(float(h.c.reserve))])
				shell.open_horse(int(h.id)))
			parent.add_child(ob)
		var price := Finance.offer_price(h)
		var sb := Button.new()
		sb.text = "Sell — offer %s ›" % Game.money(price)
		sb.tooltip_text = "A private buyer's offer this week (offers change weekly). Auctions arrive in step 4C."
		sb.pressed.connect(func():
			var dlg := ConfirmationDialog.new()
			dlg.dialog_text = "Sell %s for %s?" % [h.name, Game.money(price)]
			dlg.confirmed.connect(func():
				Finance.sell(h, price)
				shell.toast("%s sold for %s" % [h.name, Game.money(price)])
				shell.open("stable"))
			add_child(dlg)
			dlg.popup_centered())
		parent.add_child(sb)
	elif not Game.is_mine(h) and Finance.market().has(h):
		var ask := Finance.ask_price(h)
		var bb := Button.new()
		bb.text = "Buy — asking %s ›" % Game.money(ask)
		bb.disabled = not Profile.can_own() or Finance.money() < ask
		bb.tooltip_text = "Needs an owner licence and enough cash." if bb.disabled else "Buy privately from the current owner."
		bb.pressed.connect(func():
			var dlg := ConfirmationDialog.new()
			dlg.dialog_text = "Buy %s for %s?\nMonthly costs: %s." % [h.name, Game.money(ask), Game.money(float(Finance.keep_cost(h)[0]))]
			dlg.confirmed.connect(func():
				if Finance.buy(h, ask): shell.toast("You bought %s" % h.name)
				shell.open_horse(int(h.id)))
			add_child(dlg)
			dlg.popup_centered())
		parent.add_child(bb)


# ---------------- training (Step 4B) ----------------
func _trainer_name(x: Dictionary) -> String:
	var c: Dictionary = x.get("c", {})
	if Game.is_mine(x) and Profile.licensed_trainer(): return "You (%s)" % Profile.center_name()
	var t := People.trainer(c.get("trainer"))
	if t.is_empty(): return "-"
	return "%s (%s)" % [t.name, "Miho" if t.centre == "miho" else "Ritto"]

func _training(v: VBoxContainer) -> void:
	var c: Dictionary = h.get("c", {})
	var mine := Game.is_mine(h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	# ---- condition
	var cond := _card("Condition", row)
	cond.get_parent().custom_minimum_size.x = 300
	_kv(cond, "Fitness", "%d %%" % roundi(float(c.get("fit", 0.7)) * 100.0), UiTheme.stat_color(float(c.get("fit", 0.7)) * 100.0))
	var fat := float(c.get("fat", 0.0))
	_kv(cond, "Fatigue", "Fresh" if fat < 0.3 else ("Some fatigue" if fat < 0.6 else ("Tired" if fat < 0.9 else "Exhausted")), UiTheme.GOOD if fat < 0.3 else (UiTheme.ACC if fat < 0.6 else UiTheme.BAD))
	_kv(cond, "Mood", "%s (%d)" % [Training.mood_text(float(c.get("mood", 60.0))), roundi(float(c.get("mood", 60.0)))])
	_kv(cond, "Body weight", "%d kg (racing weight %d kg)" % [int(c.get("bwNow", h.get("bw", 480))), int(c.get("bw0", h.get("bw", 480)))])
	_kv(cond, "Gate manners", "%d / 100" % int(c.get("gate", 50)))
	_kv(cond, "Injury", Career.injury_text(h) if c.has("out") else "Fit", _inj_col(h))
	cond.add_child(UiTheme.dim_label("Good mood = up to +1% on race day; sour = −1%.", 11))
	# ---- weekly plan
	var pl := _card("This week's plan", row)
	if not mine:
		pl.add_child(UiTheme.dim_label("Trained by %s." % _trainer_name(h), 13))
	elif c.get("status", "") != "active":
		pl.add_child(UiTheme.dim_label("Not in training.", 13))
	else:
		var p := Training.plan(h)
		var who := "you" if Profile.licensed_trainer() else "the trainer"
		var mode := OptionButton.new()
		mode.add_item("Leave it to %s" % who if who != "you" else "Automatic (your usual routine)")
		mode.add_item("My plan")
		mode.select(1 if p.mode == "manual" else 0)
		pl.add_child(mode)
		var auto := Training.auto(h)
		pl.add_child(UiTheme.dim_label("Routine this week: %s · %s" % [Training.WORKS[auto[0]][0], Training.INTENSITY[auto[1]][0]], 12))
		var grid := GridContainer.new()
		grid.columns = 2
		pl.add_child(grid)
		grid.add_child(UiTheme.label("Work", 13))
		var wk := OptionButton.new()
		for i in Training.ORDER.size():
			var k: String = Training.ORDER[i]
			wk.add_item("%s  %s" % [Training.WORKS[k][0], Training.WORKS[k][1]], i)
			if k == p.work: wk.select(i)
		grid.add_child(wk)
		grid.add_child(UiTheme.label("Intensity", 13))
		var it := OptionButton.new()
		var iks := Training.INTENSITY.keys()
		for i in iks.size():
			it.add_item("%s  %s" % [Training.INTENSITY[iks[i]][0], Training.INTENSITY[iks[i]][1]], i)
			if iks[i] == p.int: it.select(i)
		grid.add_child(it)
		wk.disabled = p.mode != "manual"
		it.disabled = p.mode != "manual"
		var apply := func():
			Training.set_plan(h, "manual" if mode.selected == 1 else "auto", Training.ORDER[wk.selected], iks[it.selected])
			shell.open_horse(int(h.id), "training")
		mode.item_selected.connect(func(_i): apply.call())
		wk.item_selected.connect(func(_i): apply.call())
		it.item_selected.connect(func(_i): apply.call())
		var w: Array = Training.WORKS[p.work]
		pl.add_child(UiTheme.dim_label("Load %.2f · injury risk ×%.1f · mood %+.1f a week · weight %+.1f kg a week" % [float(w[2]) * float(Training.INTENSITY[p.int][2]), float(w[3]) * float(Training.INTENSITY[p.int][3]), float(w[4]) + float(Training.INTENSITY[p.int][4]), float(w[5])], 11))
		pl.add_child(UiTheme.dim_label("Uphill (坂路) builds fitness fastest; the pool keeps fitness with little strain on the legs; all-out work (一杯) sharpens a horse before a race but tires it and raises the injury risk; gate practice helps young horses start.", 11))
	# ---- connections
	var con := _card("Connections", row)
	con.get_parent().custom_minimum_size.x = 380
	_kv(con, "Trainer", _trainer_name(h))
	var t := People.trainer(c.get("trainer"))
	if not t.is_empty(): con.add_child(UiTheme.dim_label("Trainer skill %d%s" % [roundi(float(t.skill)), " · centre guessed" if t.get("centreGuess", false) else ""], 11))
	if mine and Finance.owns(h) and c.get("status", "") == "active":
		var tb := OptionButton.new()
		var ts: Array = People.active_trainers().duplicate()
		ts.sort_custom(func(a, b): return float(a.skill) > float(b.skill))
		tb.add_item("Change trainer…", -1)
		for x in ts: tb.add_item("%s · %s · skill %d" % [x.name, "Miho" if x.centre == "miho" else "Ritto", roundi(float(x.skill))], int(x.id))
		tb.item_selected.connect(func(i):
			var tid := tb.get_item_id(i)
			if tid < 0: return
			c["trainer"] = tid
			c.fit = float(c.get("fit", 0.7)) * 0.95          # a move costs a little condition
			Career.log_msg("%s moves to the %s stable." % [h.name, People.trainer(tid).name], h)
			shell.open_horse(int(h.id), "training"))
		con.add_child(tb)
	# jockey for the next race
	var entry = c.get("entry")
	var er = null
	for r in Career.W.get("races", []):
		if entry != null and r.id == entry: er = r
	if mine and er != null:
		con.add_child(UiTheme.section("Jockey for %s" % er.name))
		var bk := People.jockey(c.get("book")) if int(c.get("bookRace", -1)) == int(er.id) else {}
		con.add_child(UiTheme.label(("Booked: %s" % bk.name) if not bk.is_empty() else "No booking — the stable will find a rider", 13, UiTheme.GOOD if not bk.is_empty() else UiTheme.DIM))
		var jb := OptionButton.new()
		jb.add_item("Book a jockey…", -1)
		var js: Array = People.active_jockeys().duplicate()
		js.sort_custom(func(a, b): return float(a.skill) > float(b.skill))
		for j in js:
			var cl := People.claim(j, int(Career.W.year)) if People.claim_ok(er) else 0
			jb.add_item("%s%s · skill %d%s" % [People.claim_mark(cl), j.name, roundi(float(j.skill)), (" · −%d kg" % cl) if cl > 0 else ""], int(j.id))
		jb.item_selected.connect(func(i):
			var jid := jb.get_item_id(i)
			if jid < 0: return
			var j := People.jockey(jid)
			if People.accepts(j, h, er):
				c["book"] = jid; c["bookRace"] = int(er.id)
				shell.toast("%s will ride %s" % [j.name, h.name])
			else:
				shell.toast("%s's agent says no — already committed to a better ride" % j.name)
			shell.open_horse(int(h.id), "training"))
		con.add_child(jb)
		con.add_child(UiTheme.dim_label("Top jockeys may turn down horses they don't rate. Apprentices (▲△☆★) claim 1–4 kg in condition races.", 11))
	elif mine:
		con.add_child(UiTheme.dim_label("Enter a race to book a jockey.", 12))
	# ---- recent rides and workouts
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	var wr := _card("Workout reports", row2)
	var works: Array = c.get("works", [])
	if works.is_empty(): wr.add_child(UiTheme.dim_label("No timed work yet.", 13))
	for x in works: wr.add_child(UiTheme.label("%s  %s" % [Game.date_text(int(x.y), int(x.w)).substr(4), x.txt], 13))
	var rr := _card("Recent rides", row2)
	var any := false
	for x in c.get("history", []).slice(0, 8):
		var j := People.jockey(x.get("j"))
		if j.is_empty(): continue
		any = true
		rr.add_child(UiTheme.label("%s  %s/%s  %s — %s (%.0f kg)" % [Game.date_text(int(x.y), int(x.w)).substr(4), str(x.pos), str(x.of), x.race, j.name, float(x.get("kg", 0))], 12))
	if not any: rr.add_child(UiTheme.dim_label("No rides recorded yet.", 13))


func _inj_col(h: Dictionary) -> Color:
	match Career.injury_level(h):
		"severe", "injured": return UiTheme.BAD
		"caution": return UiTheme.ACC
	return UiTheme.GOOD

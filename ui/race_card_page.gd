class_name RaceCardPage
extends ScrollContainer
## Race card (出馬表) for one race, like the JRA/netkeiba card: Field · Odds & bets · Result, and a Paddock button.
## Fields are declared (drawn, weighted, jockeys booked, horses weighed) when a card is first opened.

var shell
var r: Dictionary
var tab := "field"
var body: VBoxContainer
var bet_type := "win"
var picks: Array = [1, 2, 3]
var stake := 1000

const TEXT_ON := ["#111111", "#ffffff", "#ffffff", "#ffffff", "#111111", "#ffffff", "#ffffff", "#111111"]

var queue: Array = []      # pre-race view before watching: the replay queue "Enter the race" starts

static func has_card(rid: int) -> bool:
	var x := RaceCardPage.new()
	var r0 := x._find(rid)
	x.free()
	return r0.has("card")

func setup(s, rid: int, start_tab := "field", replay_queue: Array = []) -> RaceCardPage:
	shell = s
	tab = start_tab
	queue = replay_queue
	if not queue.is_empty() and tab == "result": tab = "field"   # no spoilers before the race
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	r = _find(rid)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	if r.is_empty():
		shell._set_title("Race card", "")
		v.add_child(UiTheme.dim_label("This race is no longer on the card.", 14)); return self
	if not r.has("result") and not r.has("card"):
		Career.declare_week()
		r = _find(rid)
		if r.is_empty():
			shell._set_title("Race card", "")
			v.add_child(UiTheme.dim_label("Not enough runners were declared: the race is off.", 14)); return self
	var C: Dictionary = RaceEngine.COURSES[r.course]
	shell._set_title(r.name, "%s %s %d m · %s" % [Game.now_text() if not r.has("result") else "", C.short, r.dist, r.cls])
	v.add_child(_header(C))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in [["field", "📋 Field"], ["odds", "💴 Odds & bets"], ["result", "🏁 Result"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = tab == t[0]
		b.disabled = t[0] == "result" and (not r.has("result") or not queue.is_empty())
		b.custom_minimum_size = Vector2(170, 34)
		b.pressed.connect(func(): shell.open("racecard", [int(r.id), t[0], queue], false))
		tabs.add_child(b)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(sp)
	if not queue.is_empty() and r.has("card"):
		# before watching: paddock on the left, then into the race
		var pk := Button.new()
		pk.text = "🐎 Paddock"
		pk.tooltip_text = "Watch the runners walk round the paddock first (3D)"
		pk.custom_minimum_size = Vector2(150, 40)
		pk.pressed.connect(_paddock)
		tabs.add_child(pk)
		var go := Button.new()
		go.text = "▶ Enter the race" + (" (%d)" % queue.size() if queue.size() > 1 else "")
		go.tooltip_text = "Go to the course and watch the race in 3D"
		go.custom_minimum_size = Vector2(190, 40)
		go.add_theme_font_size_override("font_size", 16)
		go.pressed.connect(func(): shell.start_replays(queue))
		tabs.add_child(go)
	elif r.has("card") and not r.has("result"):
		var pb := Button.new()
		pb.text = "🐎 Paddock"
		pb.tooltip_text = "Watch the runners walk round the paddock before the race (3D)"
		pb.custom_minimum_size = Vector2(150, 34)
		pb.pressed.connect(_paddock)
		tabs.add_child(pb)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	match tab:
		"odds": _odds()
		"result": _result()
		_: _field()
	return self

func _find(rid: int) -> Dictionary:
	for x in Career.W.races:
		if int(x.id) == rid: return x
	var lw = Career.W.get("lastWeek")
	if lw != null and not lw.is_empty():
		for x in lw.races:
			if int(x.id) == rid: return x
	return {}

func _header(C: Dictionary) -> Control:
	var pc := PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pc.add_child(hb)
	var badge := Label.new()
	badge.text = r.cls
	badge.custom_minimum_size = Vector2(64, 56)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var bg: String = { "G1": "2f55d4", "G2": "d4342f", "G3": "2a9a45" }.get(r.cls, "5b6470")
	badge.add_theme_stylebox_override("normal", UiTheme.box(Color(bg), Color(0, 0, 0, 0), 6, 4))
	hb.add_child(badge)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	vb.add_child(UiTheme.title_label(String(r.name).to_upper(), 22))
	var surf := "Dirt" if C.surface == "dirt" else "Turf"
	var n: int = r.card.size() if r.has("card") else r.get("result", []).size()
	var going := RaceEngine.going_label(r.get("going", "firm"), C.surface)
	var wtxt := ""
	if r.has("weather"): wtxt = "Post %s · %s · " % [Weather.time_text(float(r.get("hour", 15.67))), Weather.LABEL.get(r.weather, "")]
	var ln := UiTheme.label(wtxt + "%s %d m (%s) · %s · %d runners · %s · %s%s" % [surf, r.dist, "L" if String(C.get("dir", "R")) == "L" else "R", C.short, n, going,
		r.age + "yo" + (" fillies & mares" if r.sex == "F" else ""), " · handicap" if r.get("handicap", false) else ""], 14, UiTheme.DIM)
	vb.add_child(ln)
	return pc

# ---------------- Field ----------------
func _field() -> void:
	if not r.has("card"):
		body.add_child(UiTheme.dim_label("No race card was kept for this race.", 13)); return
	var t := Tree.new()
	t.hide_root = true
	t.columns = 11
	t.column_titles_visible = true
	t.custom_minimum_size.y = 64 + 34 * r.card.size()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var titles := ["BK", "No", "Horse", "A&S", "Kg", "Jockey", "Trainer", "Horse wgt", "Odds", "Fav", "Last run"]
	var widths := [44, 44, 220, 54, 56, 150, 150, 100, 70, 46, 190]
	for i in 11:
		t.set_column_title(i, titles[i])
		t.set_column_custom_minimum_width(i, widths[i])
		t.set_column_expand(i, i == 2 or i == 10)
	var root := t.create_item()
	for e in r.card:
		var h = Breeding.get_horse(int(e.id))
		if h == null: continue
		var it := t.create_item(root)
		it.set_metadata(0, int(e.id))
		var bk: int = int(e.bk)
		it.set_text(0, str(bk)); it.set_custom_bg_color(0, Color(Silks.CAPS[bk - 1])); it.set_custom_color(0, Color(TEXT_ON[bk - 1]))
		it.set_text(1, str(e.num))
		it.set_text(2, h.name)
		if not r.has("result") or (r.result as Array).is_empty():
			if int(h.get("c", {}).get("sore", 0)) > 0:
				it.set_text(2, h.name + "  (caution)"); it.set_custom_color(2, UiTheme.BAD)
				it.set_tooltip_text(2, "Back from a knock and still sore: a higher risk of breaking down in this race.")
		it.set_text(3, "%d%s" % [int(h.age), _sex(h)])
		it.set_text(4, "%.1f" % float(e.kg))
		it.set_text(5, String(People.jockey(e.j).get("name", "-")) if e.j != null else "-")
		it.set_text(6, String(People.trainer(e.t).get("name", "-")) if e.t != null else "-")
		var d = e.get("bwd")
		it.set_text(7, "%d(%s)" % [int(e.bw), ("+%d" % int(d) if int(d) > 0 else str(int(d))) if d != null else ("first" if int(h.c.get("starts", 0)) == 0 else "–")])
		it.set_text(8, "%.1f" % float(e.odds))
		if int(e.fav) <= 3: it.set_custom_color(8, Color("e0383e"))
		it.set_text(9, str(e.fav))
		var hist: Array = (h.c.get("history", []) if h.has("c") else []).filter(func(x):      # runs before this race only
			return not (int(x.get("y", 0)) == int(r.get("year", -1)) and int(x.get("w", 0)) == int(r.get("week", -1))))
		if not hist.is_empty():
			var x: Dictionary = hist[0]
			it.set_text(10, "%s · %s/%s · %s %d m" % [Game.date_text(int(x.get("y", 0)), int(x.get("w", 1))).substr(4), str(x.pos), str(x.get("of", "")), RaceEngine.COURSES[x.course].short, int(x.dist)])
		else: it.set_text(10, "debut")
		if Game.is_mine(h):
			for k in range(1, 11): it.set_custom_color(k, UiTheme.MINE)
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null: shell.open_horse(int(it.get_metadata(0))))
	body.add_child(t)
	body.add_child(UiTheme.dim_label("BK = bracket (枠), No = horse number (馬番). Horse weight = race-day body weight in kg, change since the last run. Odds = win odds; favourites by the public's money. Double-click a horse to open it.", 11))

func _sex(h: Dictionary) -> String:
	if h.sex == "F": return "F" if int(h.age) <= 4 else "M"
	if h.get("gelding", false): return "G"
	return "C" if int(h.age) <= 3 else "H"

# ---------------- Odds & bets ----------------
func _odds() -> void:
	if not r.has("card"):
		body.add_child(UiTheme.dim_label("No odds were kept for this race.", 13)); return
	var n: int = r.card.size()
	var pools := Career.race_pools(r)
	var board := Odds.board(pools, int(r.get("kpl", 3)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	# win & place board
	var a: VBoxContainer = shell._card("Win · Place", row, false)
	a.get_parent().custom_minimum_size.x = 470
	var t := Tree.new()
	t.hide_root = true; t.columns = 5; t.column_titles_visible = true
	t.custom_minimum_size = Vector2(450, 64 + 30 * n)
	for i in 5: t.set_column_custom_minimum_width(i, [44, 150, 70, 110, 44][i])
	for i in 5: t.set_column_title(i, ["No", "Horse", "Win", "Place", "Fav"][i])
	t.set_column_expand(1, true)
	var rt := t.create_item()
	for e in r.card:
		var it := t.create_item(rt)
		var bk: int = int(e.bk)
		it.set_text(0, str(e.num)); it.set_custom_bg_color(0, Color(Silks.CAPS[bk - 1])); it.set_custom_color(0, Color(TEXT_ON[bk - 1]))
		it.set_text(1, Breeding.get_horse(int(e.id)).name)
		it.set_text(2, "%.1f" % float(board.win[str(e.num)]))
		if Odds.sold("place", n):
			var pl: Array = board.place[str(e.num)]
			it.set_text(3, "%.1f–%.1f" % [pl[0], pl[1]])
		it.set_text(4, str(e.fav))
	a.add_child(t)
	# bet slip
	var b: VBoxContainer = shell._card("Bet slip", row)
	if r.has("result"):
		b.add_child(UiTheme.dim_label("Betting has closed.", 13))
	else:
		var ty := OptionButton.new()
		var sold: Array = Odds.TYPES.filter(func(x): return Odds.sold(x, n))
		for x in sold: ty.add_item(Odds.NAMES[x])
		ty.select(maxi(0, sold.find(bet_type)))
		ty.item_selected.connect(func(i): bet_type = sold[i]; shell.open("racecard", [int(r.id), "odds"], false))
		b.add_child(ty)
		var need: int = Odds.PICKS[bet_type]
		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 8)
		b.add_child(ph)
		var labels := ["1st", "2nd", "3rd"] if Odds.ORDERED.has(bet_type) else ["Pick", "Pick", "Pick"]
		var maxv := 8 if bet_type == "bracket" else n
		var odds_lbl := UiTheme.label("", 18, UiTheme.ACC)
		var upd := func() -> void:
			var key := Odds.key_of(bet_type, picks.slice(0, need))
			var o = board[bet_type].get(key)
			if o == null: odds_lbl.text = "—"
			elif o is Array: odds_lbl.text = "Odds %.1f – %.1f" % [o[0], o[1]]
			else: odds_lbl.text = "Odds %.1f" % float(o)
		for k in need:
			var pl := UiTheme.dim_label(labels[k] + (" bracket" if bet_type == "bracket" else ""), 12)
			pl.autowrap_mode = TextServer.AUTOWRAP_OFF
			ph.add_child(pl)
			var sb := SpinBox.new()
			sb.custom_minimum_size.x = 90
			sb.min_value = 1; sb.max_value = maxv; sb.value = clampi(int(picks[k]), 1, maxv)
			picks[k] = int(sb.value)
			sb.value_changed.connect(func(val): picks[k] = int(val); upd.call())
			ph.add_child(sb)
		upd.call()
		b.add_child(odds_lbl)
		var sh := HBoxContainer.new()
		sh.add_theme_constant_override("separation", 8)
		b.add_child(sh)
		var sl := UiTheme.dim_label("Stake ¥", 12)
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		sh.add_child(sl)
		var st := SpinBox.new()
		st.custom_minimum_size.x = 140
		st.min_value = 100; st.max_value = 1000000; st.step = 100; st.value = stake
		st.value_changed.connect(func(val): stake = int(val))
		sh.add_child(st)
		var go := Button.new()
		go.text = "Place bet"
		go.pressed.connect(func():
			var res := Career.place_bet(r, bet_type, picks.slice(0, need), stake)
			shell.toast("Bet placed" if res == "ok" else res)
			if res == "ok": shell.open("racecard", [int(r.id), "odds"], false))
		sh.add_child(go)
		b.add_child(UiTheme.dim_label("Balance ¥%s. Payout rates: win/place 80 %%, bracket quinella/quinella/wide 77.5 %%, exacta/trio 75 %%, trifecta 72.5 %%. Odds move with the money until the race; dividends are paid at the final pool." % Career._yen(Finance.money() * 1e6), 11))
		# most-backed combinations of this type
		if bet_type != "win" and bet_type != "place":
			b.add_child(UiTheme.section("Most backed · %s" % Odds.NAMES[bet_type]))
			var lst: Array = board[bet_type].keys()
			lst.sort_custom(func(x, y): return _first(board[bet_type][x]) < _first(board[bet_type][y]))
			var g := GridContainer.new(); g.columns = 4
			g.add_theme_constant_override("h_separation", 22)
			for key in lst.slice(0, 16):
				var o = board[bet_type][key]
				g.add_child(UiTheme.label("%s   %s" % [key, ("%.1f–%.1f" % [o[0], o[1]]) if o is Array else "%.1f" % float(o)], 13))
			b.add_child(g)
	# my bets on this race
	var mine := Career.bets_for(int(r.id))
	if not mine.is_empty():
		b.add_child(UiTheme.section("Your bets"))
		for x in mine: b.add_child(UiTheme.label("%s  %s  ¥%s" % [Odds.NAMES[x.type], x.key, Career._yen(float(x.yen))], 13))

func _first(o) -> float:
	return float(o[0]) if o is Array else float(o)

# ---------------- Result ----------------
func _result() -> void:
	if not r.has("result"):
		body.add_child(UiTheme.dim_label("The race has not been run yet.", 13)); return
	var t := Tree.new()
	t.hide_root = true; t.columns = 6; t.column_titles_visible = true
	t.custom_minimum_size.y = 64 + 30 * r.result.size()
	for i in 6:
		t.set_column_title(i, ["Pos", "No", "Horse", "Time", "Margin", "Odds (fav)"][i])
		t.set_column_expand(i, i == 2)
		t.set_column_custom_minimum_width(i, [60, 50, 260, 100, 120, 120][i])
	var rt := t.create_item()
	for x in r.result:
		var it := t.create_item(rt)
		var e := {}
		for c in r.get("card", []):
			if int(c.id) == int(x.id): e = c
		it.set_text(0, str(x.pos)); it.set_text(1, str(e.get("num", "")))
		if e.has("bk"):
			it.set_custom_bg_color(1, Color(Silks.CAPS[int(e.bk) - 1])); it.set_custom_color(1, Color(TEXT_ON[int(e.bk) - 1]))
		it.set_text(2, x.name)
		it.set_text(3, RaceEngine.fmt_time(float(x.time)) if x.time != null else "-")
		it.set_text(4, str(x.get("margin", "")) if x.get("margin") != null else "")
		it.set_text(5, "%.1f (%s)" % [float(e.odds), str(e.fav)] if e.has("odds") else "")
	body.add_child(t)
	var pay: Dictionary = Career.payouts_of(r)
	if not pay.is_empty():
		var c: VBoxContainer = shell._card("Dividends (per ¥100)", body)
		var g := GridContainer.new(); g.columns = 3
		g.add_theme_constant_override("h_separation", 30)
		for ty in Odds.TYPES:
			if not pay.has(ty): continue
			for key in pay[ty]:
				g.add_child(UiTheme.label(Odds.NAMES[ty], 13, UiTheme.DIM))
				g.add_child(UiTheme.label(key, 14))
				g.add_child(UiTheme.label("¥" + Career._yen(float(pay[ty][key])), 14, UiTheme.ACC))
		c.add_child(g)

# ---------------- Paddock ----------------
func _paddock() -> void:
	var field: Array = []
	for e in r.card:
		var h = Breeding.get_horse(int(e.id))
		if h == null: continue
		var cp: Dictionary = h.duplicate(true)
		cp.erase("c")
		cp["bwDay"] = int(e.bw); cp["bwd"] = e.get("bwd"); cp["starts"] = int(h.c.get("starts", 0))
		field.append(cp)
	Game.pending_replay = { "paddock": { "opts": { "course": r.course, "dist": r.dist, "going": r.get("going", "firm"), "seed": int(r.id), "cls": r.cls }, "field": field, "name": r.name } }
	Game.return_page = "racecard"
	Game.return_arg = [int(r.id), "field", queue]
	shell.get_tree().change_scene_to_file("res://race3d/race_3d.tscn")

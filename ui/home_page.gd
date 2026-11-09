class_name HomePage
extends ScrollContainer
## Home tab, laid out like the JRA site: graded-race replays on the left, a monthly calendar of graded
## races on the right, and categorised news underneath both.

const GRADE_COL := { "G1": Color("c99a1a"), "G2": Color("c8443b"), "G3": Color("2e8b57") }
const CATS := [["all", "All"], ["races", "Races"], ["market", "Market"], ["horses", "Horses"], ["people", "People"], ["mine", "My stable"]]
const CAT_COL := { "races": Color("2a78c2"), "market": Color("c27c0e"), "horses": Color("2e8b57"), "people": Color("8a4fc4"), "mine": Color("7b3fcf"), "other": Color("7d8a80") }
const WD := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MONTHS_LONG := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

var shell
var cal_month := 1
var cal_year := 2027
var cal_box: VBoxContainer
var day_box: VBoxContainer
var news_box: VBoxContainer
var news_cat := "all"
var news_btns := {}

func setup(s) -> HomePage:
	shell = s
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	var d := Game.week_date(Career.W.year, Career.W.week)
	cal_month = int(d.month); cal_year = int(d.year)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	_this_week(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var left := _card("Replays · graded races", row)
	left.get_parent().size_flags_stretch_ratio = 0.8
	_replays(left)
	var right := _card("Graded race calendar", row)
	right.get_parent().size_flags_stretch_ratio = 1.25
	cal_box = VBoxContainer.new()
	right.add_child(cal_box)
	day_box = VBoxContainer.new()
	right.add_child(day_box)
	_calendar()
	var nc := _card("News", v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	nc.add_child(tabs)
	for c in CATS:
		var b := Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.button_pressed = c[0] == news_cat
		b.custom_minimum_size.x = 96
		b.pressed.connect(func(): news_cat = c[0]; _news())
		tabs.add_child(b)
		news_btns[c[0]] = b
	news_box = VBoxContainer.new()
	news_box.add_theme_constant_override("separation", 2)
	nc.add_child(news_box)
	_news()
	return self

func _card(title: String, parent: Control) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SIDEBAR, Color(0, 0, 0, 0), 4, 10))
	bar.add_child(UiTheme.label(title, 15, UiTheme.ON_BAR))
	v.add_child(bar)
	return v

static func badge(text: String, col: Color, size := 11) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(col, Color(0, 0, 0, 0), 3, 5))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiTheme.label(text, size, Color.WHITE)
	pc.add_child(l)
	return pc

## the real race day: graded races are on the Saturday or Sunday of their week (GRADED[7] = 1 for Saturday)
static func race_day(y: int, w: int, name: String) -> String:
	var d := Game.week_date(y, w)
	for g in Career.GRADED:
		if g[0] == name and int(g[2]) == w:
			if int(g[7]) != 1: d = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(d) + 86400)
			break
	return "%d %s %d" % [d.day, Game.MONTHS[d.month - 1], d.year]

static func age_text(a: String) -> String:
	return a.replace("+", "yo+") if a.contains("+") else a + "yo"

static func course_tag(course: String) -> String:
	var c = RaceEngine.COURSES.get(course)
	var nm: String = c.short if c != null else course
	return nm.substr(0, 3)

## one-line reminder of your runners this week (only when there is something to say)
func _this_week(v: VBoxContainer) -> void:
	var ent: Array = shell.my_entries()
	var ready := 0
	for h in shell.my_horses():
		var c: Dictionary = h.get("c", {})
		if c.get("status", "") == "active" and int(h.age) >= 2 and int(c.get("out", 0)) == 0 and c.get("entry") == null: ready += 1
	if ent.is_empty() and ready == 0: return
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(Color("fff7e0"), Color("e9c46a"), 6, 10))
	var h := HBoxContainer.new()
	pc.add_child(h)
	h.add_child(UiTheme.label("This week:", 13, UiTheme.STRONG))
	if ent.is_empty(): h.add_child(UiTheme.label("none of your horses is entered.", 13, UiTheme.DIM))
	for e in ent:
		h.add_child(shell._horse_link(e[0], 13))
		h.add_child(UiTheme.label("→ %s (%s %d m)" % [e[1].name, RaceEngine.COURSES[e[1].course].short, e[1].dist], 13))
	if ready > 0: h.add_child(UiTheme.label("· %d horse(s) ready and not entered" % ready, 12, UiTheme.DIM))
	v.add_child(pc)


# ---------------- replays ----------------
func _replays(v: VBoxContainer) -> void:
	var n := 0
	for g in Career.W.get("gradedLog", []):
		if n >= 7: break
		var rid := int(g.get("rid", -1))
		var has := rid >= 0 and Career.replay_of(rid) != null
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := HBoxContainer.new()
		top.add_child(UiTheme.label(race_day(int(g.y), int(g.w), String(g.name)), 12, UiTheme.DIM))
		top.add_child(badge(g.cls, GRADE_COL.get(g.cls, UiTheme.DIM)))
		info.add_child(top)
		info.add_child(UiTheme.label(String(g.name), 14, UiTheme.STRONG))
		var top3: Array = g.get("top3", [])
		info.add_child(UiTheme.label("%s %d m · won by %s" % [RaceEngine.COURSES[g.course].short, int(g.dist), top3[0] if not top3.is_empty() else "?"], 12, UiTheme.DIM))
		row.add_child(info)
		var b := Button.new()
		b.text = "▶ Watch" if has else "Result"
		b.custom_minimum_size = Vector2(92, 36)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if has:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.ACC, Color(0, 0, 0, 0), 4, 10))
			b.add_theme_color_override("font_color", Color.WHITE)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			b.pressed.connect(func(): shell.watch_replays([rid]))
		else:
			b.pressed.connect(func(): shell.open("results", rid if rid >= 0 else null))
		row.add_child(b)
		v.add_child(row)
		v.add_child(HSeparator.new())
		n += 1
	if n == 0:
		v.add_child(UiTheme.dim_label("No graded races run yet this season. Every G1 can be replayed in 3D after the race; G2 and G3 races show their result.", 13))
	var all := Button.new()
	all.text = "View all results ›"
	all.flat = true
	all.alignment = HORIZONTAL_ALIGNMENT_LEFT
	all.add_theme_color_override("font_color", UiTheme.ACC)
	all.pressed.connect(func(): shell.open("results"))
	v.add_child(all)


# ---------------- calendar ----------------
## graded races falling in a month: day -> [race rows]. Races are on the week's Saturday or Sunday.
func _month_races(year: int, month: int) -> Dictionary:
	var out := {}
	if year != int(Career.W.year): return out
	for g in Career.GRADED:
		var d := Game.week_date(year, int(g[2]))
		var unix := Time.get_unix_time_from_datetime_dict(d) + (0 if int(g[7]) == 1 else 86400)
		var dd := Time.get_datetime_dict_from_unix_time(unix)
		if int(dd.month) != month: continue
		var k := int(dd.day)
		if not out.has(k): out[k] = []
		out[k].append(g)
	return out

func _calendar() -> void:
	for c in cal_box.get_children(): c.queue_free()
	var head := HBoxContainer.new()
	var prev := Button.new(); prev.text = "‹"; prev.custom_minimum_size.x = 36
	prev.pressed.connect(func(): _shift(-1))
	var next := Button.new(); next.text = "›"; next.custom_minimum_size.x = 36
	next.pressed.connect(func(): _shift(1))
	var t := UiTheme.label("%s %d" % [MONTHS_LONG[cal_month - 1], cal_year], 17, UiTheme.STRONG)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(prev); head.add_child(t); head.add_child(next)
	cal_box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	cal_box.add_child(grid)
	for k in 7:
		var l := UiTheme.label(WD[k], 12, Color("2a6fd0") if k == 5 else (Color("d0453b") if k == 6 else UiTheme.ACC))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
	var first := Time.get_unix_time_from_datetime_dict({ "year": cal_year, "month": cal_month, "day": 1, "hour": 12 })
	var wd0: int = (int(Time.get_datetime_dict_from_unix_time(first).weekday) + 6) % 7      # Monday = 0
	var nm := { "year": cal_year + (1 if cal_month == 12 else 0), "month": 1 if cal_month == 12 else cal_month + 1, "day": 1, "hour": 12 }
	var days := int(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(nm) - 86400).day)
	var races := _month_races(cal_year, cal_month)
	var today := Game.week_date(Career.W.year, Career.W.week)
	for i in wd0: grid.add_child(_cell(-1, i, [], false))
	for day in range(1, days + 1):
		var col := (wd0 + day - 1) % 7
		var now: bool = int(today.month) == cal_month and int(today.year) == cal_year and absi(int(today.day) - day) <= 1 and col >= 5
		grid.add_child(_cell(day, col, races.get(day, []), now))
	var tail := (7 - (wd0 + days) % 7) % 7
	for i in tail: grid.add_child(_cell(-1, (wd0 + days + i) % 7, [], false))
	var key := HBoxContainer.new()
	for g in ["G1", "G2", "G3"]:
		key.add_child(badge(g, GRADE_COL[g], 10))
	key.add_child(UiTheme.label("Click a day to see its races. Course codes: Tok = Tokyo, Nak = Nakayama, Kyo = Kyoto, Han = Hanshin …", 11, UiTheme.DIM))
	cal_box.add_child(key)
	for c in day_box.get_children(): c.queue_free()

func _shift(dm: int) -> void:
	cal_month += dm
	if cal_month < 1: cal_month = 12; cal_year -= 1
	if cal_month > 12: cal_month = 1; cal_year += 1
	_calendar()

func _cell(day: int, col: int, races: Array, now: bool) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(0, 62)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color("ffffff") if col < 5 else (Color("eaf2ff") if col == 5 else Color("fff0f0"))
	if day < 0: bg = Color(bg, 0.45)
	pc.add_theme_stylebox_override("panel", UiTheme.box(bg, Color("e3a72f") if now else UiTheme.LINE, 2, 4, 2 if now else 1))
	if day < 0: return pc
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	v.add_child(UiTheme.label(str(day), 14, Color("2a6fd0") if col == 5 else (Color("d0453b") if col == 6 else UiTheme.STRONG)))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 2)
	f.add_theme_constant_override("v_separation", 2)
	v.add_child(f)
	for g in races: f.add_child(badge(course_tag(String(g[3])), GRADE_COL.get(g[1], UiTheme.DIM), 10))
	if not races.is_empty():
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.tooltip_text = "\n".join(races.map(func(g): return "%s %s · %s %d m" % [g[1], g[0], RaceEngine.COURSES[g[3]].short, g[4]]))
		pc.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _show_day(day, races))
	return pc

## the races on one day: grade, name, course, conditions, and the result or your runner
func _show_day(day: int, races: Array) -> void:
	for c in day_box.get_children(): c.queue_free()
	day_box.add_child(UiTheme.section("%d %s %d" % [day, Game.MONTHS[cal_month - 1], cal_year]))
	for g in races:
		var row := HBoxContainer.new()
		row.add_child(badge(g[1], GRADE_COL.get(g[1], UiTheme.DIM)))
		row.add_child(UiTheme.label(String(g[0]), 14, UiTheme.STRONG))
		row.add_child(UiTheme.label("%s %d m · %s%s" % [RaceEngine.COURSES[g[3]].short, int(g[4]), age_text(String(g[5])), " · fillies & mares" if String(g[6]) == "F" else ""], 12, UiTheme.DIM))
		var res = null
		for x in Career.W.get("gradedLog", []):
			if x.name == g[0] and int(x.y) == cal_year and int(x.w) == int(g[2]): res = x; break
		if res != null:
			var t3: Array = res.get("top3", [])
			row.add_child(UiTheme.label("1st %s" % (t3[0] if not t3.is_empty() else "?"), 12, UiTheme.GOOD))
			var rid := int(res.get("rid", -1))
			if rid >= 0 and Career.replay_of(rid) != null:
				var b := Button.new(); b.text = "▶"; b.tooltip_text = "Watch the replay"
				b.pressed.connect(func(): shell.watch_replays([rid]))
				row.add_child(b)
		else:
			for e in shell.my_entries():
				if e[1].name == g[0]: row.add_child(UiTheme.label("your runner: %s" % e[0].name, 12, UiTheme.MINE))
		day_box.add_child(row)


# ---------------- news ----------------
static func category(x: Dictionary) -> String:
	var m: String = x.msg
	if x.get("cat", "") != "": return x.cat
	if m.contains("🔨") or m.contains(" sold ") or m.contains("bought") or m.contains("Catalogue") or m.contains("average"): return "market"
	if m.begins_with("Jockey ") or m.begins_with("Trainer ") or m.contains("exam") or m.contains("licence") or m.contains("assistant trainer"): return "people"
	if m.contains("finished") or m.contains("Grading review") or m.contains(" wins "): return "races"
	if m.contains("injured") or m.contains("retire") or m.contains("stud") or m.contains("foaled") or m.contains("exported") or m.contains("in foal") \
		or m.contains("covered") or m.contains("barren") or m.contains("yearling") or m.contains("weaned") or m.contains("broken in") or m.contains("training centre"): return "horses"
	return "other"

## news = the career log plus a headline for every graded result, newest first
func _items() -> Array:
	var items: Array = []
	for x in Career.W.log:
		var it: Dictionary = x.duplicate()
		it["cat"] = category(x)
		items.append(it)
	for g in Career.W.get("gradedLog", []):
		var t3: Array = g.get("top3", [])
		if t3.is_empty(): continue
		var msg := "%s: %s wins%s (%s %d m, %s)" % [g.name, t3[0], (", from %s and %s" % [t3[1], t3[2]]) if t3.size() >= 3 else "",
			RaceEngine.COURSES[g.course].short, int(g.dist), RaceEngine.fmt_time(float(g.time))]
		items.append({ "y": g.y, "w": g.w, "msg": msg, "cat": "races", "rid": g.get("rid", -1), "mine": false, "grade": g.cls, "day": race_day(int(g.y), int(g.w), String(g.name)) })
	items.sort_custom(func(a, b): return int(a.y) * 100 + int(a.w) > int(b.y) * 100 + int(b.w))
	return items

func _news() -> void:
	for k in news_btns: news_btns[k].button_pressed = k == news_cat
	for c in news_box.get_children(): c.queue_free()
	var n := 0
	for it in _items():
		if n >= 30: break
		var cat: String = it.cat
		if news_cat == "mine" and not it.get("mine", false): continue
		if news_cat not in ["all", "mine"] and cat != news_cat: continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var d := UiTheme.label(String(it.get("day", Game.date_text(int(it.y), int(it.w)).substr(4))), 12, UiTheme.DIM)
		d.custom_minimum_size.x = 92
		row.add_child(d)
		var tag := badge(("★ " if it.get("mine", false) else "") + (cat.capitalize() if cat != "other" else "News"), CAT_COL.get("mine" if it.get("mine", false) else cat, UiTheme.DIM), 10)
		tag.custom_minimum_size.x = 84
		row.add_child(tag)
		if it.has("grade"): row.add_child(badge(it.grade, GRADE_COL.get(it.grade, UiTheme.DIM), 10))
		var msg := UiTheme.label(String(it.msg), 13, UiTheme.MINE if it.get("mine", false) else UiTheme.TEXT)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(msg)
		if it.get("id") != null and Breeding.get_horse(it.id) != null:
			var b := Button.new(); b.text = "Open"; b.flat = true
			b.add_theme_color_override("font_color", UiTheme.ACC)
			var hid := int(it.id)
			b.pressed.connect(func(): shell.open_horse(hid))
			row.add_child(b)
		elif int(it.get("rid", -1)) >= 0 and Career.replay_of(int(it.rid)) != null:
			var b2 := Button.new(); b2.text = "▶ Replay"; b2.flat = true
			b2.add_theme_color_override("font_color", UiTheme.ACC)
			var rid := int(it.rid)
			b2.pressed.connect(func(): shell.watch_replays([rid]))
			row.add_child(b2)
		news_box.add_child(row)
		n += 1
	if n == 0: news_box.add_child(UiTheme.dim_label("Nothing here yet.", 13))

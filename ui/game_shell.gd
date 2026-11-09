class_name GameShell
extends Control
## Career screen in the style of Football Manager 2024: menu column on the left, top bar with back/forward,
## page title, search, date and the purple Continue button; pages in the middle.

signal to_main_menu

const MENU := [
	["home", "⌂", "Home"], ["inbox", "✉", "Inbox"], ["career", "👤", "Career"], ["stable", "♞", "My Stable"], ["horses", "⌕", "Horses"],
	["breeding", "♥", "Breeding"], ["training", "⚑", "Training"], ["market", "⇄", "Market"], ["auctions", "🔨", "Auctions"], ["schedule", "▦", "Schedule"],
	["people", "👥", "Racing World"],
	["results", "🏁", "Results"], ["ratings", "★", "Ratings"], ["finances", "¥", "Finances"], ["info", "ⓘ", "Stable Info"],
]

## which menu items each career uses (a youngster has no stable of their own yet)
func menu_items() -> Array:
	var rl := Profile.role()
	var out: Array = []
	for it in MENU:
		var k: String = it[0]
		if rl == "trainer" and k in ["market", "auctions"]: continue
		if Profile.is_young_trainer() and k in ["stable", "training", "breeding"]: continue
		if rl == "trainer" and k == "breeding": continue
		var lab: String = it[2]
		if k == "stable": lab = { "trainer": "My Yard", "owner": "My Horses", "breeder": "My Farm" }.get(rl, lab)
		out.append([k, it[1], lab])
	return out

var page_host: Control
var title_lbl: Label
var sub_lbl: Label
var date_lbl: Label
var money_lbl: Label
var next_lbl: Label
var continue_btn: Button
var search: LineEdit
var menu_btns := {}
var history: Array = []
var hpos := -1
var overlay: Control
var toast_lbl: Label
var silk_badge: TextureRect

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.background())
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_sidebar())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	root.add_child(right)
	right.add_child(_topbar())
	var m := MarginContainer.new()
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + s, 14)
	right.add_child(m)
	page_host = Control.new()
	m.add_child(page_host)
	_build_overlay()
	refresh_bar()


# ---------------- frame ----------------
func _sidebar() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SIDEBAR, Color(0, 0, 0, 0), 0, 0))
	pc.custom_minimum_size.x = 190
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pc.add_child(v)
	var head := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: head.add_theme_constant_override("margin_" + s, 12)
	var hv := HBoxContainer.new()
	silk_badge = TextureRect.new()
	silk_badge.texture = Silks.preview(Silks.of(Career.W), 48, 40)
	silk_badge.custom_minimum_size = Vector2(30, 25)
	silk_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	silk_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hv.add_child(silk_badge)
	var nm := UiTheme.label(Career.W.get("stable_name", "My Stable"), 14, Color.WHITE)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(nm)
	head.add_child(hv)
	v.add_child(head)
	for it in menu_items():
		var b := Button.new()
		b.text = "  %s   %s" % [it[1], it[2]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.custom_minimum_size.y = 40
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", UiTheme.ON_BAR)
		b.add_theme_color_override("font_hover_color", UiTheme.ON_BAR)
		b.add_theme_stylebox_override("hover", UiTheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 10))
		b.pressed.connect(open.bind(it[0]))
		v.add_child(b)
		menu_btns[it[0]] = b
		if it[0] in ["career", "market", "finances"]:
			var sep := HSeparator.new()
			sep.add_theme_stylebox_override("separator", UiTheme.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 0))
			v.add_child(sep)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	for x in [["⚙  Settings", func(): Settings.open_dialog(self)], ["💾  Save game", _save], ["☰  Main menu", func(): Saves.autosave(); to_main_menu.emit()]]:
		var b := Button.new()
		b.text = "  " + x[0]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 36
		b.add_theme_color_override("font_color", UiTheme.ON_BAR_DIM)
		b.add_theme_color_override("font_hover_color", UiTheme.ON_BAR)
		b.pressed.connect(x[1])
		v.add_child(b)
	return pc

func _topbar() -> Control:
	var pc := PanelContainer.new()
	var sb := UiTheme.box(UiTheme.TOPBAR, Color(0, 0, 0, 0), 0, 12)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.y = 64
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	for x in [["‹", go_back], ["›", go_forward]]:
		var b := Button.new()
		b.text = x[0]
		b.flat = true
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", UiTheme.ON_BAR)
		b.add_theme_color_override("font_hover_color", UiTheme.ON_BAR_DIM)
		b.custom_minimum_size.x = 30
		b.pressed.connect(x[1])
		h.add_child(b)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_lbl = UiTheme.label("", 18, Color.WHITE)
	sub_lbl = UiTheme.label("", 12, UiTheme.ON_BAR_DIM)
	tv.add_child(title_lbl)
	tv.add_child(sub_lbl)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	search = LineEdit.new()
	search.placeholder_text = "⌕  Search horses"
	search.custom_minimum_size = Vector2(220, 0)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.text_submitted.connect(func(t): open("horses", t))
	h.add_child(search)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 0)
	dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_lbl = UiTheme.label("", 16, Color.WHITE)
	money_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	money_lbl.tooltip_text = "Cash — open Finances for details"
	h.add_child(money_lbl)
	date_lbl = UiTheme.label("", 16, Color("ffe08a"))
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_lbl = UiTheme.label("", 11, UiTheme.ON_BAR_DIM)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(date_lbl)
	dv.add_child(next_lbl)
	h.add_child(dv)
	continue_btn = Button.new()
	continue_btn.text = "CONTINUE  ››"
	continue_btn.custom_minimum_size = Vector2(170, 44)
	continue_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)
	continue_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	continue_btn.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PURPLE, Color(0, 0, 0, 0), 4, 14))
	continue_btn.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PURPLE.lightened(0.12), Color(0, 0, 0, 0), 4, 14))
	continue_btn.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PURPLE.darkened(0.2), Color(0, 0, 0, 0), 4, 14))
	continue_btn.pressed.connect(on_continue)
	# skip ahead several weeks: stops by itself for a race of yours, a sale day or news about your horses
	var skip := MenuButton.new()
	skip.text = "⏩"
	skip.tooltip_text = "Skip ahead"
	skip.flat = false
	skip.custom_minimum_size = Vector2(52, 44)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_theme_font_size_override("font_size", 18)
	var pm := skip.get_popup()
	for it in SKIP_MODES: pm.add_item(it[1])
	pm.id_pressed.connect(func(i): skip_ahead(String(SKIP_MODES[i][0])))
	h.add_child(skip)
	h.add_child(continue_btn)
	return pc

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	toast_lbl = UiTheme.label("", 14, Color.WHITE)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_lbl.position.y -= 60
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast_lbl)

func toast(t: String) -> void:
	toast_lbl.text = t
	var tw := create_tween()
	toast_lbl.modulate.a = 1.0
	tw.tween_interval(2.5)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.6)

func refresh_bar() -> void:
	date_lbl.text = Game.now_text()
	var cash := Finance.money()
	money_lbl.text = Game.money(cash)
	money_lbl.add_theme_color_override("font_color", Color("ffb4b4") if cash < 0.0 else UiTheme.ON_BAR)
	var mine := my_entries()
	if not mine.is_empty():
		next_lbl.text = "Race day: %d of your horses run" % mine.size()
	else:
		var gr := ""
		for g in Career.GRADED:
			if g[2] >= Career.W.week and g[1] == "G1":
				gr = "%s (week %d)" % [g[0], g[2]]; break
		next_lbl.text = "Week %d · next G1: %s" % [Career.W.week, gr if gr != "" else "next year"]
	continue_btn.text = "NEXT RACE  ››" if not mine.is_empty() else "CONTINUE  ››"


# ---------------- navigation ----------------
func open(kind: String, arg = null, push := true) -> void:
	if push:
		history = history.slice(0, hpos + 1)
		history.append([kind, arg])
		hpos = history.size() - 1
	for c in page_host.get_children(): c.queue_free()
	for k in menu_btns:
		menu_btns[k].add_theme_color_override("font_color", Color("ffe08a") if k == kind else UiTheme.ON_BAR)
		menu_btns[k].add_theme_stylebox_override("normal", UiTheme.box(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 0, 10) if k == kind else StyleBoxEmpty.new())
	var p: Control
	match kind:
		"home": p = _page_home()
		"inbox": p = _page_inbox()
		"stable": p = _page_stable()
		"horses": p = _page_horses(arg if arg != null else "")
		"horse": p = HorsePage.new().setup(self, Game.horse(arg[0]), arg[1])
		"schedule": p = _page_schedule()
		"results": p = _page_results(arg)
		"racecard": p = RaceCardPage.new().setup(self, int(arg[0]), String(arg[1]) if arg.size() > 1 else "field", arg[2] if arg.size() > 2 else [])
		"info": p = _page_info()
		"ratings": p = RatingsPage.new().setup(self, arg)
		"breeding": p = BreedingPage.new().setup(self, arg)
		"career": p = CareerPage.new().setup(self)
		"market": p = MarketPage.new().setup(self, arg)
		"training": p = TrainingPage.new().setup(self)
		"people": p = PeoplePage.new().setup(self, arg)
		"person": p = PersonPage.new().setup(self, arg[0], arg[1])
		"auctions": p = AuctionPage.new().setup(self, arg)
		"finances": p = FinancePage.new().setup(self, arg)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_host.add_child(p)
	refresh_bar()

func open_horse(id: int, tab := "overview") -> void:
	open("horse", [id, tab])

func go_back() -> void:
	if hpos > 0:
		hpos -= 1; open(history[hpos][0], history[hpos][1], false)

func go_forward() -> void:
	if hpos < history.size() - 1:
		hpos += 1; open(history[hpos][0], history[hpos][1], false)

func _set_title(t: String, s := "") -> void:
	title_lbl.text = t
	sub_lbl.text = s

func _scroll(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	return sc

func _card(title: String, parent: Control, expand := true) -> VBoxContainer:
	var pc := PanelContainer.new()
	if expand: pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	if title != "": v.add_child(UiTheme.section(title))
	return v

func _horse_link(h: Dictionary, size := 14) -> Button:
	var b := Button.new()
	b.text = h.name
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", UiTheme.MINE if Game.is_mine(h) else UiTheme.TEXT)
	b.add_theme_color_override("font_hover_color", UiTheme.STRONG)
	b.tooltip_text = "Double-click to open"
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT: open_horse(int(h.id)))
	return b


# ---------------- data ----------------
func my_horses() -> Array:
	var out: Array = []
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h != null: out.append(h)
	return out

func my_entries() -> Array:
	var out: Array = []
	for h in my_horses():
		var e = h.get("c", {}).get("entry")
		if e == null: continue
		for r in Career.W.races:
			if r.id == e: out.append([h, r])
	return out


# ---------------- pages ----------------
func _page_home() -> Control:
	_set_title("Home", "%s · %s" % [Career.W.get("stable_name", ""), Game.now_text()])
	return HomePage.new().setup(self)

func _page_inbox() -> Control:
	_set_title("Inbox", "News about your horses and the racing world")
	var c := _card("Messages", VBoxContainer.new())
	for x in Career.W.log.slice(0, 200):
		c.add_child(UiTheme.label("%s   %s" % [Game.date_text(int(x.y), int(x.w)), x.msg], 13, UiTheme.MINE if x.get("mine", false) else UiTheme.TEXT))
	if Career.W.log.is_empty(): c.add_child(UiTheme.dim_label("No messages yet.", 13))
	return _scroll(c.get_parent().get_parent())

func _page_stable() -> Control:
	var tl: String = { "trainer": "My Yard", "owner": "My Horses", "breeder": "My Farm" }.get(Profile.role(), "My Stable")
	var extra := (" · %d of %d boxes" % [my_horses().size(), int(Profile.P().get("boxes", 0))]) if Profile.licensed_trainer() else ""
	_set_title(tl, "%d horses%s · double-click a horse to open it" % [my_horses().size(), extra])
	var v := VBoxContainer.new()
	var groups := [["Racing", func(h): return h.c.status == "active" and int(h.age) >= 2], ["Yearlings & foals", func(h): return h.c.status == "active" and int(h.age) < 2],
		["Broodmares & stallions", func(h): return h.c.status in ["broodmare", "stud"]], ["Retired", func(h): return h.c.status == "retired"]]
	for g in groups:
		var list: Array = my_horses().filter(g[1])
		if list.is_empty(): continue
		var c := _card("%s (%d)" % [g[0], list.size()], v)
		var cols := ["name", "age", "sex", "gene", "style", "dist", "surf", "tier", "ab", "pot", "form", "status", "value"]
		if Profile.role() == "trainer": cols = ["name", "age", "sex", "style", "dist", "surf", "tier", "ab", "pot", "form", "status", "owner"]
		var t := HorseTable.new(cols)
		t.custom_minimum_size.y = 40 + 32 * list.size()
		t.horse_opened.connect(open_horse)
		t.set_horses(list)
		c.add_child(t)
	return _scroll(v)

func _page_horses(query: String) -> Control:
	_set_title("Horses", "Search the stud book · double-click to open")
	var v := VBoxContainer.new()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var q := LineEdit.new()
	q.text = query
	q.placeholder_text = "Name contains…"
	q.custom_minimum_size.x = 240
	bar.add_child(q)
	var kind := OptionButton.new()
	for x in ["Racing horses", "All horses", "Stallions at stud", "Broodmares", "G1 winners"]: kind.add_item(x)
	bar.add_child(kind)
	var age := OptionButton.new()
	for x in ["Any age", "2yo", "3yo", "4yo+", "Yearlings"]: age.add_item(x)
	bar.add_child(age)
	var count := UiTheme.dim_label("", 12)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(count)
	v.add_child(bar)
	var t := HorseTable.new(["name", "age", "sex", "gene", "style", "dist", "tier", "ab", "form", "wins", "earn", "sire"])
	t.horse_opened.connect(open_horse)
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.sort_col = "ab"
	t.limit = 400
	t.limited.connect(func(shown, total): count.text = "%d horses" % total if shown == total else "%d horses · showing the top %d (sort or search to narrow)" % [total, shown])
	v.add_child(t)
	var refresh := func(_x = null):
		var s := q.text.to_lower()
		var list: Array = []
		for h in Breeding.book.values():
			if not h.has("c"): continue
			if s != "" and not String(h.name).to_lower().contains(s): continue
			var st: String = h.c.status
			match kind.selected:
				0: if st != "active" or int(h.age) < 2: continue
				2: if st != "stud": continue
				3: if st != "broodmare": continue
				4: if int(h.c.get("g1", 0)) == 0: continue
			match age.selected:
				1: if int(h.age) != 2: continue
				2: if int(h.age) != 3: continue
				3: if int(h.age) < 4: continue
				4: if int(h.age) >= 2: continue
			list.append(h)
		t.set_horses(list)
	q.text_changed.connect(refresh)
	kind.item_selected.connect(refresh)
	age.item_selected.connect(refresh)
	refresh.call()
	return v

func _page_schedule() -> Control:
	_set_title("Schedule", "Graded races of %d · races this week" % Career.W.year)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var a := _card("This week · %s" % Game.now_text(), row)
	var t := Tree.new()
	t.hide_root = true
	t.columns = 5
	t.column_titles_visible = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 5: t.set_column_title(i, ["Race", "Class", "Course", "Age", "Your runner"][i])
	for i in 5:
		t.set_column_expand(i, i == 0 or i == 2)
		t.set_column_custom_minimum_width(i, [220, 50, 200, 70, 140][i])
	var root := t.create_item()
	for r in Career.W.races:
		var it := t.create_item(root)
		it.set_metadata(0, int(r.id))
		it.set_text(0, ("%s · %s" % [r.name, "%d rnrs" % r.card.size()]) if r.has("card") else r.name)
		it.set_text(1, r.cls)
		it.set_text(2, "%s %d m" % [RaceEngine.COURSES[r.course].short, r.dist])
		it.set_text(3, r.age + (" fillies" if r.sex == "F" else ""))
		for e in my_entries():
			if e[1].id == r.id: it.set_text(4, e[0].name); it.set_custom_color(4, UiTheme.MINE)
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null: open("racecard", [int(it.get_metadata(0)), "field"]))
	a.add_child(t)
	a.add_child(UiTheme.dim_label("Double-click a race for its race card: field, odds and bets, paddock." if Career.is_declared() else "Fields are declared when you open a race card (entering a horse afterwards re-draws the fields).", 11))
	var b := _card("Graded calendar", row)
	var g := Tree.new()
	g.hide_root = true
	g.columns = 4
	g.column_titles_visible = true
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 4: g.set_column_title(i, ["Date", "Grade", "Race", "Course"][i])
	g.set_column_expand(2, true)
	var gr := g.create_item()
	for x in Career.GRADED:
		var it := g.create_item(gr)
		it.set_text(0, Game.date_text(Career.W.year, x[2]).substr(4))
		it.set_text(1, x[1]); it.set_text(2, x[0]); it.set_text(3, "%s %d m %s" % [RaceEngine.COURSES[x[3]].short, x[4], x[5]])
		if x[2] < Career.W.week:
			for k in 4: it.set_custom_color(k, UiTheme.DIM.darkened(0.3))
		elif x[1] == "G1": it.set_custom_color(1, UiTheme.ACC)
	b.add_child(g)
	b.add_child(UiTheme.dim_label("Double-click a graded race to make it a target for one of your horses.", 11))
	g.item_activated.connect(func():
		var it := g.get_selected()
		if it != null: _plan_dialog(Career.GRADED[it.get_index()]))
	# the race plans of the player's horses
	var pc := _card("Your race plans", row, false)
	pc.get_parent().custom_minimum_size.x = 400
	var n := 0
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h == null: continue
		for tg in Career.plan_of(h):
			n += 1
			var warn := Career.plan_warnings(h, tg)
			var bt := Button.new()
			bt.flat = true
			bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
			bt.text = "%s  %s → %s%s" % [Game.date_text(int(tg.y), int(tg.w)).substr(4), h.name, Career.plan_text(tg), ("\n      ⚠ " + ", ".join(warn)) if not warn.is_empty() else ""]
			bt.pressed.connect(func(): open_horse(int(h.id), "entries"))
			pc.add_child(bt)
	if n == 0: pc.add_child(UiTheme.dim_label("No targets planned. Open a horse's Entries tab (or double-click a graded race) to plan its next races.", 13))
	row.custom_minimum_size.y = 790
	return row

## make a graded race a target for one of the player's horses
func _plan_dialog(g: Array) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Plan: %s" % g[0]
	var v := VBoxContainer.new()
	var y := int(Career.W.year) + (1 if int(g[2]) <= int(Career.W.week) else 0)
	v.add_child(UiTheme.label("%s %s · %s · %s %d m · %s" % [g[1], g[0], Game.date_text(y, int(g[2])), RaceEngine.COURSES[g[3]].short, int(g[4]), g[5]], 14))
	var ob := OptionButton.new()
	var ids: Array = []
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h == null or String(h.get("c", {}).get("status", "")) != "active": continue
		ids.append(int(id))
		ob.add_item("%s (%d%s)" % [h.name, int(h.age), "F" if h.sex == "F" else "M"])
	v.add_child(ob)
	dlg.add_child(v)
	dlg.ok_button_text = "Add target"
	add_child(dlg)
	dlg.confirmed.connect(func():
		if ids.is_empty(): return
		var h = Breeding.get_horse(ids[ob.selected])
		var t := { "y": y, "w": int(g[2]), "race": String(g[0]) }
		var res := Career.plan_add(h, t)
		if res != "ok": toast(res)
		else:
			var warn := Career.plan_warnings(h, t)
			toast("%s → %s%s" % [h.name, g[0], ("  (⚠ " + ", ".join(warn) + ")") if not warn.is_empty() else ""])
		open("schedule"))
	dlg.popup_centered(Vector2i(480, 0))

func _page_results(sel_id) -> Control:
	var lw = Career.W.get("lastWeek")
	if lw == null or lw.is_empty():
		_set_title("Results", "")
		return _placeholder("Results", "No races have been run yet. Press Continue.")
	_set_title("Results", "Race day %s" % Game.date_text(int(lw.y), int(lw.w)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var a := _card("Races", row, false)
	a.get_parent().custom_minimum_size.x = 380
	var races: Array = lw.races
	var cur = races[0] if not races.is_empty() else null
	for r in races:
		if sel_id != null and r.id == sel_id: cur = r
		var mine := false
		for x in r.result:
			if Career.W.stable.has(int(x.id)): mine = true
		var b := Button.new()
		b.text = "%s%s · %s %d m" % ["★ " if mine else "", r.name, RaceEngine.COURSES[r.course].short, r.dist]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = r != cur
		b.pressed.connect(func(): open("results", r.id))
		a.add_child(b)
	var c := _card("", row)
	if cur != null:
		var hd := HBoxContainer.new()
		var tl := UiTheme.label("%s  ·  %s %d m  ·  %s" % [cur.name, RaceEngine.COURSES[cur.course].short, cur.dist, RaceEngine.going_label(cur.going, RaceEngine.COURSES[cur.course].surface)], 16, UiTheme.ACC)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(tl)
		if cur.has("card"):
			var cb := Button.new()
			cb.text = "📋 Race card & dividends"
			cb.pressed.connect(func(): open("racecard", [int(cur.id), "result"]))
			hd.add_child(cb)
		if Career.replay_of(cur.id) != null:
			var wb := Button.new()
			wb.text = "🎥 Watch in 3D"
			wb.pressed.connect(func(): watch_replays([cur.id]))
			hd.add_child(wb)
		c.add_child(hd)
		var t := Tree.new()
		t.hide_root = true
		t.columns = 6
		t.column_titles_visible = true
		t.custom_minimum_size.y = 520
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for i in 6: t.set_column_title(i, ["Pos", "Horse", "Kg", "Time", "Margin", "Rating"][i])
		t.set_column_expand(1, true)
		var root := t.create_item()
		for x in cur.result:
			var it := t.create_item(root)
			it.set_metadata(0, int(x.id))
			it.set_text(0, str(x.pos)); it.set_text(1, x.name)
			it.set_text(2, "%.1f" % float(x.kg) if x.get("kg") != null else "")
			it.set_text(3, RaceEngine.fmt_time(float(x.time)) if x.time != null else "-")
			it.set_text(4, str(x.get("margin", "")) if x.get("margin") != null else "")
			it.set_text(5, str(int(x.rt)) if x.get("rt") != null else "")
			if Career.W.stable.has(int(x.id)):
				for k in 6: it.set_custom_color(k, UiTheme.MINE)
		t.item_activated.connect(func():
			var it := t.get_selected()
			if it != null: open_horse(int(it.get_metadata(0))))
		c.add_child(t)
		c.add_child(UiTheme.dim_label("Double-click a horse to open it. Rating = handicapper's performance rating for this run (lb)%s." % (", race level %.0f" % float(cur.level) if cur.get("level") != null else ""), 11))
	row.custom_minimum_size.y = 790
	return row

func _page_info() -> Control:
	_set_title("Stable Info", Career.W.get("stable_name", ""))
	var v := VBoxContainer.new()
	var c := _card("Your stable", v)
	c.add_child(UiTheme.label(Career.W.get("stable_name", ""), 22, UiTheme.STRONG))
	var st := Career.stats()
	c.add_child(UiTheme.label("Horses: %d · started %d · package: %s" % [my_horses().size(), int(Career.W.get("start_year", Career.W.year)), Career.W.get("package", "-")], 14))
	c.add_child(UiTheme.dim_label("The racing world: %d active horses, %d horses in the stud book." % [st.n, st.total], 13))
	var sc := _card("Racing silks (勝負服)", v)
	sc.add_child(UiTheme.dim_label("Your colours are worn by every jockey riding your horses, in the 3D races and on the race cards. JRA silks use up to 13 registered colours and standard patterns.", 12))
	var ed := SilkEditor.new().setup(Silks.of(Career.W))
	ed.changed.connect(func(sd):
		Career.W["silks"] = sd
		Career.W["silk"] = sd.body
		if silk_badge != null: silk_badge.texture = Silks.preview(sd, 48, 40))
	sc.add_child(ed)
	return _scroll(v)

func _placeholder(t: String, text: String) -> Control:
	_set_title(t, "")
	var pc := PanelContainer.new()
	var l := UiTheme.dim_label(text, 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


# ---------------- continue / race day ----------------
func on_continue() -> void:
	# sale day: go to the ring, or let the lots be sold without you
	if Auction.is_sale_week() and Profile.role() != "trainer" and not Auction.current().get("lots", []).all(func(l): return l.done):
		var sd := ConfirmationDialog.new()
		sd.title = "Sale day"
		var cur := Auction.current()
		sd.dialog_text = "The %s is on this week (%d lots).\n\nGo to the sale ring?" % [Auction.sale(String(cur.lots[0].sale)).name, cur.lots.size()]
		sd.ok_button_text = "🔨 Go to the sale ring"
		sd.cancel_button_text = "Skip the sale"
		add_child(sd)
		sd.confirmed.connect(func(): AuctionPage.enter_ring(self))
		sd.canceled.connect(func():
			Auction.finish(cur)
			_continue_races())
		sd.popup_centered(Vector2i(520, 0))
		return
	_continue_races()

func _continue_races() -> void:
	var mine := my_entries()
	if mine.is_empty():
		await _advance(false)
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Race day"
	var lines: PackedStringArray = []
	for e in mine: lines.append("%s  →  %s (%s %d m)" % [e[0].name, e[1].name, RaceEngine.COURSES[e[1].course].short, e[1].dist])
	dlg.dialog_text = "Your runners this week:\n\n%s\n\nHow do you want to follow the race?" % "\n".join(lines)
	dlg.ok_button_text = "🎥 Watch in 3D"
	dlg.cancel_button_text = "Quick result"
	add_child(dlg)
	dlg.confirmed.connect(func(): _advance(true))
	dlg.canceled.connect(func(): _advance(false))
	dlg.popup_centered(Vector2i(560, 0))

func _advance(watch: bool) -> void:
	var mine_ids: Array = []
	for e in my_entries(): mine_ids.append(int(e[1].id))
	var ui := _sim_panel("Racing…" if not mine_ids.is_empty() else "Moving to next week…", false)
	await _run_threaded(Career.advance_week, ui, "")
	if Settings.get_v("autosave"): Saves.autosave()
	_close_sim_panel(ui)
	if Profile.P().get("over", false):
		_game_over()
		return
	if watch and not mine_ids.is_empty():
		watch_replays(mine_ids)
	else:
		open("results" if not mine_ids.is_empty() else "home", mine_ids[0] if not mine_ids.is_empty() else null)

# ---------------- the week runs on a worker thread (the screen stays live) ----------------
const SKIP_MODES := [["race", "To my next race"], ["sale", "To the next sale day"], ["month", "To the end of the month"], ["w4", "4 weeks"], ["w12", "12 weeks"]]
var _skip_cancel := false

## the progress panel over the page: title, what the simulation is doing, a bar (and a Stop button when skipping)
func _sim_panel(title: String, can_stop: bool) -> Dictionary:
	overlay.visible = true
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.09, 0.16, 0.95), Color(1, 1, 1, 0.1), 10, 20))
	pc.custom_minimum_size = Vector2(460, 0)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	overlay.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	var t := UiTheme.label(title, 20, Color.WHITE)
	v.add_child(t)
	var st := UiTheme.label("", 13, Color(1, 1, 1, 0.75))
	st.clip_text = true
	st.custom_minimum_size.x = 420
	v.add_child(st)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(420, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 6, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(Color("f5c542"), Color(0, 0, 0, 0), 6, 0))
	v.add_child(bar)
	var ui := { "panel": pc, "title": t, "stage": st, "bar": bar }
	if can_stop:
		var b := Button.new()
		b.text = "Stop after this week"
		b.pressed.connect(func():
			_skip_cancel = true
			b.disabled = true
			b.text = "Stopping…")
		v.add_child(b)
	pc.reset_size()
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	return ui

func _close_sim_panel(ui: Dictionary) -> void:
	(ui.panel as Control).queue_free()
	overlay.visible = false

## run c() on a worker thread; the panel follows Career.PROGRESS until it finishes
func _run_threaded(c: Callable, ui: Dictionary, prefix: String) -> Variant:
	Career._stage("Starting…", 0.0)
	var th := Thread.new()
	th.start(c)
	while th.is_alive():
		(ui.stage as Label).text = prefix + String(Career.PROGRESS.stage)
		(ui.bar as ProgressBar).value = float(Career.PROGRESS.f) * 100.0
		await get_tree().process_frame
	(ui.bar as ProgressBar).value = 100.0
	return th.wait_to_finish()

## skip ahead: week after week until the target, or until something needs the player
func skip_ahead(mode: String) -> void:
	_skip_cancel = false
	var label := ""
	for m in SKIP_MODES:
		if m[0] == mode: label = m[1]
	var ui := _sim_panel("Skipping ahead: %s" % label.to_lower(), true)
	var month0 := Career.month_of_week(int(Career.W.week))
	var weeks := 0
	var why := ""
	while true:
		# the week's fields first: a race plan or an entry of yours stops the skip on race day
		await _run_threaded(Career.declare_week, ui, "%s · " % Game.now_text())
		if not my_entries().is_empty():
			why = "Race day: your horses run this week."
			break
		if Auction.is_sale_week() and Profile.role() != "trainer" and not Auction.current().get("lots", []).all(func(l): return l.done):
			why = "Sale day: the %s is on this week." % Auction.sale(String(Auction.current().lots[0].sale)).name
			break
		if mode == "month" and weeks > 0 and Career.month_of_week(int(Career.W.week)) != month0:
			why = "A new month has begun."
			break
		if (mode == "w4" and weeks >= 4) or (mode == "w12" and weeks >= 12) or weeks >= 52:
			why = "%d weeks done." % weeks
			break
		if _skip_cancel:
			why = "Stopped."
			break
		var top = Career.W.log[0] if not Career.W.log.is_empty() else null
		(ui.title as Label).text = "Skipping ahead: %s  (week %d)" % [label.to_lower(), weeks + 1]
		await _run_threaded(Career.advance_week, ui, "%s · " % Game.now_text())
		if Settings.get_v("autosave"): Saves.autosave()
		weeks += 1
		if Profile.P().get("over", false):
			_close_sim_panel(ui)
			_game_over()
			return
		# news about the player's horses that needs a decision
		var news := ""
		for e in Career.W.log:
			if is_same(e, top): break
			if not e.get("mine", false) or not Settings.get_v("skip_news"): continue
			var msg := String(e.msg).to_lower()
			if msg.contains("injur") or msg.contains("offer") or msg.contains("caution") or msg.contains("retire") or msg.contains("could not run"):
				news = String(e.msg)
		if news != "":
			why = "News: " + news
			break
		if mode == "race" and weeks >= 52: break
	_close_sim_panel(ui)
	toast(why)
	open("home")

## play stored career races in the 3D view (same seed + horses = the same race)
func watch_replays(ids: Array) -> void:
	var queue: Array = []
	for id in ids:
		if Career.replay_of(id) != null: queue.append(id)
	if queue.is_empty(): return
	# show the race card first (field, paddock, then "Enter the race"), when one was kept for this race
	if RaceCardPage.has_card(int(queue[0])):
		open("racecard", [int(queue[0]), "field", queue])
		return
	start_replays(queue)

## straight into the 3D race (from the race card's "Enter the race")
func start_replays(queue: Array) -> void:
	Game.pending_replay = { "queue": queue }
	Game.return_page = "results"
	get_tree().change_scene_to_file("res://race3d/race_3d.tscn")

## save dialog: pick one of the save slots (the current one is preselected)
func _save() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Save game"
	dlg.ok_button_text = "Save"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiTheme.label("Choose a slot", 14, UiTheme.ACC))
	var ob := OptionButton.new()
	var metas := {}
	for s in Saves.list():
		if s.kind == "slot": metas[int(s.slot)] = s.meta
	var cur := int(Career.W.get("slot", 0))
	if cur <= 0: cur = Saves.first_free()
	for i in range(1, Saves.SLOTS + 1):
		var m: Dictionary = metas.get(i, {})
		ob.add_item("Slot %d — %s" % [i, ("%s · %s" % [m.get("stable", ""), Game.date_text(int(m.year), int(m.week))]) if not m.is_empty() else "empty"], i)
	ob.select(cur - 1)
	v.add_child(ob)
	var lbl := LineEdit.new()
	lbl.placeholder_text = "Note (optional), e.g. 'before the Derby'"
	v.add_child(lbl)
	v.add_child(UiTheme.dim_label("The game also autosaves every week (last three weeks kept).", 11))
	dlg.add_child(v)
	dlg.confirmed.connect(func():
		var i := ob.get_selected_id()
		var err := Saves.save_slot(i, lbl.text.strip_edges())
		toast("Saved to slot %d" % i if err == OK else "Could not save (error %d)" % err))
	add_child(dlg)
	dlg.popup_centered(Vector2i(460, 0))

func _game_over() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Career over"
	var p := Profile.P()
	dlg.dialog_text = ("You retired from training at %d.\n\nThank you for playing! Load an earlier save or start a new career." % Profile.age()) if p.get("retiredOut", false) else "Bankrupt — you can no longer pay your bills and your licence has been withdrawn.\n\nLoad an earlier save (autosaves keep the last three weeks) or start a new career."
	dlg.ok_button_text = "Main menu"
	dlg.confirmed.connect(func(): to_main_menu.emit())
	add_child(dlg)
	dlg.popup_centered(Vector2i(480, 0))

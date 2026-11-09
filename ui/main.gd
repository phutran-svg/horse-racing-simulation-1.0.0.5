extends Control
## App controller: main menu → New Career (wizard) / Load Career (save slots) → game screen (FM style), or Quick Race → 3D.

const PACKAGES := [
	["Racing stable", "Two 2-year-olds and one 3-year-old, ready to race this season."],
	["Owner-breeder", "One yearling and two broodmares to start your own bloodline (mares boarded at a farm)."],
	["Balanced", "One 2-year-old, one 3-year-old and one broodmare."],
]
const SILK_COLS := ["#6d4df2", "#e5484d", "#3b82f6", "#22c55e", "#facc15", "#f97316", "#ec4899", "#14b8a6", "#111111", "#ffffff"]

var screen: Control
var wiz := {}          # new-career choices
var wiz_step := 0

func _ready() -> void:
	Settings.apply()
	UiTheme.set_dark(false)
	get_tree().root.content_scale_size = Vector2i(1600, 900)   # FM-style density (project stretch mode scales it to the window)
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Game.mode == "career" and not Career.W.is_empty():
		_show_shell(Game.return_page if Game.return_page != "" else "home", Game.return_arg)
		Game.return_page = ""; Game.return_arg = null
	elif Game.mode == "quick":
		_show(QuickRaceScreen.new())
	else:
		show_menu()

func _show(c: Control) -> void:
	if screen != null: screen.queue_free()
	screen = c
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)

func _show_shell(page: String, arg = null) -> void:
	var s := GameShell.new()
	_show(s)
	s.to_main_menu.connect(show_menu)
	s.open(page, arg)

func _bg() -> Control:
	var root := Control.new()
	root.add_child(UiTheme.background())
	return root

func _big_button(text: String, cb: Callable, enabled := true, accent := false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 18)
	btn.disabled = not enabled
	if accent:
		btn.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PURPLE, Color(0, 0, 0, 0), 4, 16))
		btn.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PURPLE.lightened(0.12), Color(0, 0, 0, 0), 4, 16))
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.pressed.connect(cb)
	return btn


# ---------------- main menu ----------------
func show_menu() -> void:
	Game.mode = ""
	var root := _bg()
	var stripe := ColorRect.new()
	stripe.color = UiTheme.TOPBAR
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 440          # width via the offset: setting size on a stretched control warns
	root.add_child(stripe)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 90)
	v.custom_minimum_size.x = 320
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	v.add_child(UiTheme.label("🏇", 54))
	v.add_child(UiTheme.label("HORSE RACING", 34, Color.WHITE))
	v.add_child(UiTheme.label("SIMULATION", 34, Color("ffe08a")))
	v.add_child(UiTheme.label("JRA physics engine v0.9 · careers", 13, UiTheme.ON_BAR_DIM))
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	v.add_child(gap)
	var saves := Saves.list()
	v.add_child(_big_button("New Career", func(): wiz = {}; wiz_step = 0; _wizard(), true, true))
	if not saves.is_empty():
		v.add_child(_big_button("Continue", func(): _load(saves[0].path)))
	v.add_child(_big_button("Load Career", _load_screen, not saves.is_empty()))
	v.add_child(_big_button("Quick Race", func(): Game.mode = "quick"; _show(QuickRaceScreen.new())))
	v.add_child(_big_button("Settings", func(): Settings.open_dialog(self)))
	v.add_child(_big_button("Exit", func(): get_tree().quit()))
	if not saves.is_empty():
		v.add_child(UiTheme.label("Latest: %s" % _save_line(saves[0]), 12, UiTheme.ON_BAR_DIM))
	_show(root)

func _save_line(s: Dictionary) -> String:
	var m: Dictionary = s.meta
	if s.kind == "old" or m.is_empty(): return "Save from before Step 4"
	var who := "%s — %s" % [m.get("stable", ""), String(m.get("role", "")).capitalize()]
	return "%s · %s · %s" % [who, Game.date_text(int(m.year), int(m.week)), Game.money(float(m.get("money", 0.0)))]

func _load(path: String) -> void:
	if Saves.load_path(path):
		Game.mode = "career"
		_show_shell("home")
		if Saves.last_note != "":
			var sh := find_children("*", "GameShell", true, false)
			if not sh.is_empty(): (sh[0] as GameShell).toast(Saves.last_note)
	else:
		var dlg := AcceptDialog.new()
		dlg.title = "Could not load"
		dlg.dialog_text = Saves.last_note if Saves.last_note != "" else "This save could not be loaded."
		add_child(dlg)
		dlg.popup_centered(Vector2i(480, 0))


# ---------------- load screen ----------------
func _load_screen() -> void:
	var root := _bg()
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(820, 0)
	pc.position = Vector2(-410, -330)
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(UiTheme.title_label("LOAD CAREER", 22))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 480
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for s in Saves.list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var kind: String = { "slot": "Slot %d" % int(s.slot), "auto": "Autosave %d" % int(s.slot), "old": "Old save" }[s.kind]
		var k := UiTheme.label(kind, 14, UiTheme.ACC)
		k.custom_minimum_size.x = 110
		row.add_child(k)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(_save_line(s), 14))
		var m: Dictionary = s.meta
		if m.has("saved"):
			info.add_child(UiTheme.dim_label("Saved %s%s" % [Time.get_datetime_string_from_unix_time(int(m.saved) + _tz(), true), ("  · " + String(m.label)) if String(m.get("label", "")) != "" else ""], 11))
		row.add_child(info)
		var lb := Button.new()
		lb.text = "Load"
		lb.custom_minimum_size.x = 90
		lb.pressed.connect(_load.bind(s.path))
		row.add_child(lb)
		if s.kind == "slot":
			var db := Button.new()
			db.text = "Delete"
			db.pressed.connect(func():
				var dlg := ConfirmationDialog.new()
				dlg.dialog_text = "Delete %s? This can't be undone." % kind
				dlg.confirmed.connect(func(): Saves.delete(s.path); _load_screen())
				add_child(dlg)
				dlg.popup_centered())
			row.add_child(db)
		list.add_child(row)
		list.add_child(HSeparator.new())
	var back := Button.new()
	back.text = "‹ Back"
	back.pressed.connect(show_menu)
	v.add_child(back)
	_show(root)

func _tz() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# ---------------- new career wizard ----------------
## steps: 0 country · 1 role · 2 path and difficulty · 3 details
func _wizard() -> void:
	var root := _bg()
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(760, 560)
	pc.position = Vector2(-380, -300)
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	var steps := ["Country", "Career", "Path", "Details"]
	var crumbs := HBoxContainer.new()
	crumbs.add_theme_constant_override("separation", 18)
	for i in steps.size():
		crumbs.add_child(UiTheme.label("%d  %s" % [i + 1, steps[i]], 13, UiTheme.ACC if i == wiz_step else (UiTheme.TEXT if i < wiz_step else UiTheme.DIM)))
	v.add_child(UiTheme.title_label("NEW CAREER", 22))
	v.add_child(crumbs)
	v.add_child(HSeparator.new())
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	var next_ok := true
	match wiz_step:
		0: _wiz_country(body)
		1: _wiz_role(body)
		2: _wiz_path(body)
		3: next_ok = _wiz_details(body)
	var hb := HBoxContainer.new()
	var back := Button.new()
	back.text = "‹ Back"
	back.pressed.connect(func():
		if wiz_step == 0: show_menu()
		else: wiz_step -= 1; _wizard())
	hb.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var busy := UiTheme.label("", 14, UiTheme.ACC)
	hb.add_child(busy)
	var nx := Button.new()
	nx.custom_minimum_size = Vector2(200, 44)
	nx.text = "START CAREER  ››" if wiz_step == 3 else "Next  ›"
	nx.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PURPLE, Color(0, 0, 0, 0), 4, 14))
	nx.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PURPLE.lightened(0.12), Color(0, 0, 0, 0), 4, 14))
	nx.disabled = not next_ok
	nx.pressed.connect(func():
		if wiz_step < 3:
			wiz_step += 1; _wizard(); return
		nx.disabled = true
		busy.text = "Creating the racing world (about 5,000 horses)…"
		await get_tree().process_frame
		await get_tree().process_frame
		create_career(wiz)
		_show_shell("career" if wiz.get("role", "") == "trainer" else "home"))
	hb.add_child(nx)
	v.add_child(hb)
	_show(root)

func _choice_card(parent: Control, title: String, text: String, selected: bool, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = selected
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 92)
	b.text = ""
	b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL2, Color(0, 0, 0, 0), 6, 10))
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL2, UiTheme.ACC, 6, 10, 2))
	b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL2.lightened(0.06), UiTheme.LINE, 6, 10))
	b.add_theme_stylebox_override("disabled", UiTheme.box(UiTheme.PANEL, Color(0, 0, 0, 0), 6, 10))
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + s, 10)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vv := VBoxContainer.new()
	vv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UiTheme.label(title, 16, UiTheme.ACC if selected else (UiTheme.STRONG if enabled else UiTheme.DIM))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vv.add_child(t)
	var d := UiTheme.dim_label(text, 12)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vv.add_child(d)
	m.add_child(vv)
	b.add_child(m)
	b.pressed.connect(cb)
	parent.add_child(b)

func _wiz_country(body: Control) -> void:
	body.add_child(UiTheme.section("Where do you start your career?"))
	if not wiz.has("country"): wiz["country"] = "JPN"
	for c in Profile.COUNTRIES:
		var txt := "JRA (Tokyo, Kyoto, Nakayama…). Training centres at Miho and Ritto." if c[0] == "JPN" else "Coming later — licensing rules researched (see the Step 4 plan)."
		_choice_card(body, c[1], txt, wiz.country == c[0], c[2], func(): wiz.country = c[0]; _wizard())

func _wiz_role(body: Control) -> void:
	body.add_child(UiTheme.section("Choose your career"))
	if not wiz.has("role"): wiz["role"] = "owner"
	for k in ["trainer", "owner", "breeder"]:
		var r: Array = Profile.ROLES[k]
		_choice_card(body, r[0], r[1], wiz.role == k, true, func(): wiz.role = k; _wizard())

func _wiz_path(body: Control) -> void:
	if not wiz.has("diff"): wiz["diff"] = "normal"
	if wiz.role == "trainer":
		if not wiz.has("bg"): wiz["bg"] = "young"
		body.add_child(UiTheme.section("Your path"))
		_choice_card(body, "Youngster — no licence yet", "Start at about 20 at the JRA Horse Racing School, work as a groom (厩務員) and assistant trainer (調教助手), then sit the JRA trainer licence exam from age 28. Few pass each year; many need several tries.", wiz.bg == "young", true, func(): wiz.bg = "young"; _wizard())
		_choice_card(body, "Experienced — licensed trainer", "You are about 40 and already hold a JRA licence. Open your stable at Miho or Ritto with a small number of boxes.", wiz.bg == "pro", true, func(): wiz.bg = "pro"; _wizard())
		_choice_card(body, "Local trainer (NAR)", "Coming later: local racing (Oi, Funabashi, Sonoda…) isn't in the race world yet.", false, false, func(): pass)
	body.add_child(UiTheme.section("Difficulty"))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	body.add_child(hb)
	for d in ["easy", "normal", "hard"]:
		var cfg: Dictionary = Profile.DIFF[d]
		var txt := ""
		match wiz.role:
			"owner": txt = "Start with %s; business income %s a year." % [Game.money(cfg.owner[0]), Game.money(cfg.owner[1])]
			"breeder": txt = "%s, a farm and %d broodmares." % [Game.money(cfg.breeder[0]), cfg.breeder[1]]
			"trainer": txt = ("Savings %s." % Game.money(cfg.young)) if wiz.get("bg", "") == "young" else ("%d boxes, %s working capital." % [cfg.trainer[1], Game.money(cfg.trainer[0])])
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		_choice_card(col, cfg.label, txt, wiz.diff == d, true, func(): wiz.diff = d; _wizard())

func _wiz_details(body: Control) -> bool:
	var rl: String = wiz.role
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var add_row := func(lbl: String, ctrl: Control) -> void:
		var l := UiTheme.label(lbl, 14)
		l.custom_minimum_size.x = 180
		grid.add_child(l)
		ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(ctrl)
	var nm := LineEdit.new()
	nm.text = wiz.get("name", "Trinh")
	nm.text_changed.connect(func(t): wiz.name = t)
	wiz["name"] = nm.text
	add_row.call("Your name", nm)
	var sn := LineEdit.new()
	var def_sn: String = { "trainer": "%s Stable", "owner": "%s Racing", "breeder": "%s Farm" }[rl] % String(wiz.name).split(" ")[0]
	sn.text = wiz.get("stable_name", def_sn)
	sn.text_changed.connect(func(t): wiz.stable_name = t)
	wiz["stable_name"] = sn.text
	add_row.call({ "trainer": "Stable name", "owner": "Owner name (colours)", "breeder": "Farm name" }[rl], sn)
	if rl == "trainer":
		var ce := OptionButton.new()
		ce.add_item("Miho (east, Ibaraki)")
		ce.add_item("Ritto (west, Shiga)")
		ce.selected = 1 if wiz.get("center", "miho") == "ritto" else 0
		wiz["center"] = "ritto" if ce.selected == 1 else "miho"
		ce.item_selected.connect(func(i): wiz.center = "ritto" if i == 1 else "miho")
		add_row.call("Training centre", ce)
		if wiz.get("bg", "") == "young":
			var ag := SpinBox.new()
			ag.min_value = 16; ag.max_value = 27; ag.value = wiz.get("age", 20)
			wiz["age"] = int(ag.value)
			ag.value_changed.connect(func(x): wiz.age = int(x))
			add_row.call("Age", ag)
	if rl == "owner":
		var pk := OptionButton.new()
		for p in PACKAGES: pk.add_item(p[0])
		pk.selected = int(wiz.get("package", 0))
		wiz["package"] = pk.selected
		var desc := UiTheme.dim_label(PACKAGES[pk.selected][1], 12)
		pk.item_selected.connect(func(i): wiz.package = i; desc.text = PACKAGES[i][1])
		add_row.call("Starting horses", pk)
		grid.add_child(Control.new())
		grid.add_child(desc)
	if not wiz.has("silks"): wiz["silks"] = Silks.default_for(Silks.COLORS[3][2])
	wiz["silk"] = wiz.silks.body
	var silks := SilkEditor.new().setup(wiz.silks, true)
	silks.changed.connect(func(sd): wiz.silks = sd; wiz.silk = sd.body)
	add_row.call("Racing silks", silks)
	var summary := ""
	var cfg: Dictionary = Profile.DIFF[wiz.diff]
	match rl:
		"owner": summary = "JRA-licensed owner · %s · %s" % [Game.money(cfg.owner[0]), cfg.label]
		"breeder": summary = "Breeder in Hidaka · %d mares · %s · %s" % [cfg.breeder[1], Game.money(cfg.breeder[0]), cfg.label]
		"trainer": summary = ("Youngster · Racing School → groom → assistant → exam at 28 · %s" % cfg.label) if wiz.get("bg", "") == "young" else ("Licensed JRA trainer · %d boxes · %s" % [cfg.trainer[1], cfg.label])
	body.add_child(HSeparator.new())
	body.add_child(UiTheme.label("Japan · " + summary, 14, UiTheme.ACC))
	return true

## world + your career
static func create_career(o: Dictionary) -> void:
	var seed_value := int(Time.get_unix_time_from_system()) % 100000 + 1
	Career.init(seed_value)
	var W := Career.W
	var rl: String = o.get("role", "owner")
	W["stable_name"] = String(o.get("stable_name", "My Stable")).strip_edges()
	if W.stable_name == "": W.stable_name = "My Stable"
	W["silk"] = o.get("silk", SILK_COLS[0])
	W["silks"] = o.get("silks", Silks.default_for(String(W.silk)))
	W["start_year"] = W.year
	Profile.create(o)
	var rng := SimRng.new(seed_value * 31)
	var pick := func(filter: Callable, lo_f := 0.3, hi_f := 0.6) -> Variant:
		var list: Array = Career.active().filter(filter).filter(func(h): return not W.stable.has(h.id))
		list.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
		if list.is_empty(): return null
		var lo := int(list.size() * lo_f)
		var hi := int(list.size() * hi_f)
		return list[lo + int(floor(rng.next() * maxi(1, hi - lo)))]
	match rl:
		"owner":
			var package := int(o.get("package", 0))
			W["package"] = PACKAGES[package][0]
			var want: Array = [[2, 2, 3], [1], [2, 3]][package]
			for age in want:
				var h = pick.call(func(x): return int(x.age) == age and x.c.get("out", 0) == 0)
				if h != null: Career.add_to_stable(h.id)
			var mares: int = [0, 2, 1][package]
			var ms := Breeding.mares()
			for i in mares:
				var m = ms[int(floor(rng.next() * ms.size()))]
				if not W.stable.has(m.id): Career.add_to_stable(m.id)
		"breeder":
			var n: int = Profile.DIFF[o.get("diff", "normal")].breeder[1]
			var ms: Array = Breeding.mares().filter(func(m): return int(m.age) <= 14)
			ms.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
			var lo := int(ms.size() * 0.35)
			var hi := int(ms.size() * 0.85)
			var tries := 0
			while W.stable.size() < n and tries < 200:
				tries += 1
				var m = ms[lo + int(floor(rng.next() * maxi(1, hi - lo)))]
				if not W.stable.has(m.id): Career.add_to_stable(m.id)
		"trainer":
			if Profile.licensed_trainer(): Profile.fill_new_yard(rng)
	var welcome := {
		"owner": "Welcome, %s! Your horses have arrived — they are with your trainers at Miho and Ritto." % W.stable_name,
		"breeder": "Welcome to %s in Hidaka! Plan the matings for your mares in Breeding › Mating planner." % W.stable_name,
		"trainer": "Welcome! Your stable at %s is open — owners have sent you their first horses." % Profile.center_name() if Profile.licensed_trainer() else "Welcome! You start the six-month stable-staff course at the JRA Horse Racing School. Set your weekly focus in Career.",
	}
	for id in W.stable:
		var hh = Breeding.get_horse(id)
		if hh != null and hh.c.status == "active" and int(hh.age) >= 1 and rl != "trainer": People.ensure_trainer(hh)
	Career.log_msg(welcome[rl], null)
	Game.mode = "career"
	if Career.W.races.is_empty(): Career.build_week()
	Saves.save_slot(Saves.first_free(), "New career")

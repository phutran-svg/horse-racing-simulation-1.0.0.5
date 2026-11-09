class_name RaceScreen
extends HBoxContainer
## Race tab: settings + field (left), live view + elevation + commentary (centre), standings + horse (right).

const SPEEDS := [0.5, 1.0, 2.0, 4.0, 8.0, 16.0]
const STEP_BUDGET_MS := 10.0       # simulation time allowed per frame (keeps the window responsive)
const TURBO_BUDGET_MS := 28.0

var race: RaceEngine.Race
var comm := RaceCommentary.new()
var running := false
var turbo := false
var speed := 1.0
var acc := 0.0
var sel := 0
var _board_t := 0.0
var _finished_shown := false

# widgets
var course_opt: OptionButton
var dist_opt: OptionButton
var going_opt: OptionButton
var runners_spin: SpinBox
var seed_spin: SpinBox
var inj_chk: CheckBox
var eiph_chk: CheckBox
var course_info: Label
var field_list: RichTextLabel
var play_btn: Button
var cam_btn: Button
var speed_opt: OptionButton
var view: RaceView
var elev: ElevView
var board: StandingsBoard
var hpanel: HorsePanel
var comm_now: Label
var comm_log: RichTextLabel
var clock_lbl: Label
var results_panel: PanelContainer
var results_tree: Tree
var results_head: Label
var laps_lbl: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_left()
	_build_center()
	_build_right()
	comm.line.connect(_on_comm_line)
	if AppState.field.is_empty(): AppState.build_field("rand")
	_fill_courses()
	new_race()


# ---------------- layout ----------------
func _panel(min_w: float) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = min_w
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

func _row(parent: Control, label: String, ctrl: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 74
	l.add_theme_color_override("font_color", UiTheme.DIM)
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	parent.add_child(h)

func _btn(text: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b

func _build_left() -> void:
	var v := _panel(236)
	v.add_child(UiTheme.title_label("Race setup"))
	course_opt = OptionButton.new()
	course_opt.item_selected.connect(func(_i): _on_course())
	_row(v, "Course", course_opt)
	dist_opt = OptionButton.new()
	dist_opt.item_selected.connect(func(i): AppState.dist = dist_opt.get_item_id(i); new_race())
	_row(v, "Distance", dist_opt)
	going_opt = OptionButton.new()
	for k in RaceEngine.GOING: going_opt.add_item(RaceEngine.going_label(k))
	going_opt.item_selected.connect(func(i): AppState.going = RaceEngine.GOING.keys()[i]; new_race())
	_row(v, "Going", going_opt)
	runners_spin = SpinBox.new()
	runners_spin.min_value = 2; runners_spin.max_value = 18; runners_spin.value = AppState.runners
	runners_spin.value_changed.connect(func(x): AppState.build_field("rand", int(x)); new_race())
	_row(v, "Runners", runners_spin)
	var sh := HBoxContainer.new()
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1; seed_spin.max_value = 999999; seed_spin.value = AppState.seed
	seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_spin.value_changed.connect(func(x): AppState.seed = int(x); new_race())
	sh.add_child(seed_spin)
	sh.add_child(_btn("🎲", func(): seed_spin.value = 1 + randi() % 99999, "Random seed: same seed + same horses = same race"))
	_row(v, "Seed", sh)
	inj_chk = CheckBox.new(); inj_chk.text = "Injuries"; inj_chk.button_pressed = AppState.injuries
	inj_chk.toggled.connect(func(b): AppState.injuries = b; new_race())
	eiph_chk = CheckBox.new(); eiph_chk.text = "Lung bleeding (EIPH)"; eiph_chk.button_pressed = AppState.eiph
	eiph_chk.toggled.connect(func(b): AppState.eiph = b; new_race())
	v.add_child(inj_chk)
	v.add_child(eiph_chk)
	course_info = UiTheme.dim_label("")
	v.add_child(course_info)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.title_label("Field", 15))
	v.add_child(_btn("New field (bred from stud book)", func(): AppState.build_field("rand"); new_race()))
	v.add_child(_btn("All equal (stats 70)", func(): AppState.build_field("equal"); new_race(), "Same stats: shows the effect of running style, draw and luck"))
	v.add_child(_btn("Gene test (75, CC/CT/TT)", func(): AppState.build_field("genes"); new_race(), "Sprinter, miler and stayer genes with equal stats"))
	field_list = RichTextLabel.new()
	field_list.bbcode_enabled = true
	field_list.fit_content = true
	field_list.scroll_active = false
	field_list.add_theme_font_size_override("normal_font_size", 12)
	v.add_child(field_list)

func _build_center() -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 3.0
	add_child(v)
	var tb := HFlowContainer.new()
	tb.add_theme_constant_override("h_separation", 6)
	tb.add_theme_constant_override("v_separation", 6)
	play_btn = _btn("▶ Start", _on_play)
	play_btn.custom_minimum_size.x = 104
	tb.add_child(play_btn)
	tb.add_child(_btn("↺ Reset", func(): new_race()))
	tb.add_child(_btn("⏭ Next race", _on_next, "Next seed, start straight away"))
	tb.add_child(_btn("⏩ Finish now", _on_finish_now, "Run the rest of the race as fast as possible"))
	speed_opt = OptionButton.new()
	for s in SPEEDS: speed_opt.add_item("%s×" % ("½" if s == 0.5 else str(int(s))))
	speed_opt.select(SPEEDS.find(speed))
	speed_opt.item_selected.connect(func(i): speed = SPEEDS[i])
	speed_opt.tooltip_text = "Playback speed"
	tb.add_child(speed_opt)
	tb.add_child(_btn("🎥 Watch in 3D", func(): get_tree().change_scene_to_file("res://race3d/race_3d.tscn"), "Same course, field and seed in 3D"))
	cam_btn = _btn("📷 Follow selected", _on_cam)
	tb.add_child(cam_btn)
	tb.add_child(_btn("−", func(): view.zoom_by(1.0 / 1.4), "Zoom out (mouse wheel)"))
	tb.add_child(_btn("+", func(): view.zoom_by(1.4), "Zoom in (mouse wheel)"))
	v.add_child(tb)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size.y = 260
	v.add_child(stack)
	view = RaceView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.horse_selected.connect(_select)
	stack.add_child(view)
	_build_results(stack)
	elev = ElevView.new()
	v.add_child(elev)
	var cp := PanelContainer.new()
	var cv := VBoxContainer.new()
	cp.add_child(cv)
	comm_now = Label.new()
	comm_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comm_now.add_theme_font_size_override("font_size", 15)
	comm_now.custom_minimum_size.y = 40
	cv.add_child(comm_now)
	comm_log = RichTextLabel.new()
	comm_log.bbcode_enabled = true
	comm_log.custom_minimum_size.y = 84
	comm_log.add_theme_font_size_override("normal_font_size", 12)
	comm_log.add_theme_font_size_override("bold_font_size", 12)
	cv.add_child(comm_log)
	v.add_child(cp)

func _build_results(stack: Control) -> void:
	results_panel = PanelContainer.new()
	results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_panel.offset_left = 30; results_panel.offset_right = -30; results_panel.offset_top = 24; results_panel.offset_bottom = -24
	results_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PANEL, 0.96); sb.border_color = UiTheme.ACC.darkened(0.3)
	sb.set_border_width_all(1); sb.set_corner_radius_all(10)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	results_panel.add_theme_stylebox_override("panel", sb)
	stack.add_child(results_panel)
	var v := VBoxContainer.new()
	results_panel.add_child(v)
	var hh := HBoxContainer.new()
	results_head = UiTheme.title_label("Result", 16)
	results_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hh.add_child(results_head)
	hh.add_child(_btn("Watch the field", func(): results_panel.visible = false))
	hh.add_child(_btn("⏭ Next race", _on_next))
	v.add_child(hh)
	results_tree = Tree.new()
	results_tree.columns = 7
	results_tree.hide_root = true
	results_tree.column_titles_visible = true
	results_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles := ["Pos", "", "Horse", "Time", "Margin", "Last 3F", "Notes"]
	var widths := [44, 34, 220, 70, 80, 64, 200]
	for i in 7:
		results_tree.set_column_title(i, titles[i])
		results_tree.set_column_custom_minimum_width(i, widths[i])
		results_tree.set_column_expand(i, i == 6 or i == 2)
	results_tree.item_selected.connect(func():
		var it := results_tree.get_selected()
		if it != null: _select(int(it.get_metadata(0))))
	v.add_child(results_tree)
	laps_lbl = Label.new()
	laps_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	laps_lbl.add_theme_font_size_override("font_size", 12)
	v.add_child(laps_lbl)

func _build_right() -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = 350
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(UiTheme.title_label("Running order", 15))
	clock_lbl = Label.new()
	clock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_lbl.add_theme_color_override("font_color", UiTheme.DIM)
	clock_lbl.add_theme_font_size_override("font_size", 12)
	top.add_child(clock_lbl)
	v.add_child(top)
	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)
	var s1 := ScrollContainer.new()
	s1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s1.size_flags_stretch_ratio = 1.1
	split.add_child(s1)
	board = StandingsBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.horse_selected.connect(_select)
	s1.add_child(board)
	var s2 := ScrollContainer.new()
	s2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(s2)
	hpanel = HorsePanel.new()
	hpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s2.add_child(hpanel)


# ---------------- settings ----------------
func _fill_courses() -> void:
	course_opt.clear()
	var last_venue := ""
	for id in RaceEngine.COURSES:
		var c: Dictionary = RaceEngine.COURSES[id]
		var venue: String = id.split("_")[0].capitalize()
		if venue != last_venue:
			course_opt.add_separator(venue)
			last_venue = venue
		course_opt.add_item("%s %s (%s)" % ["▪" if c.surface == "dirt" else "▫", c.short, c.dir], course_opt.item_count)
		course_opt.set_item_metadata(course_opt.item_count - 1, id)
		if id == AppState.course: course_opt.select(course_opt.item_count - 1)
	going_opt.select(RaceEngine.GOING.keys().find(AppState.going))
	_fill_distances()

func _fill_distances() -> void:
	var T: Dictionary = RaceEngine.COURSES[AppState.course]
	dist_opt.clear()
	if not T.distances.has(AppState.dist): AppState.dist = T.def
	for d in T.distances:
		dist_opt.add_item("%d m" % d, d)
		if d == AppState.dist: dist_opt.select(dist_opt.item_count - 1)
	var kind := "straight course" if T.straight else ("left-handed" if T.dir == "L" else "right-handed")
	course_info.text = "%s\n%s%s · loop %s m · home straight %s m · height difference %s m · %s" % [T.name, "DIRT: slower, wet = faster, kickback · " if T.surface == "dirt" else "", kind, str(T.C), str(T.finish), str(T.hdiff), T.slopeNote]

func _on_course() -> void:
	AppState.course = course_opt.get_item_metadata(course_opt.selected)
	_fill_distances()
	new_race()

func _refresh_field_list() -> void:
	var t := ""
	for i in AppState.field.size():
		var h: Dictionary = AppState.field[i]
		var avg := 0.0
		for k in RaceEngine.STATS: avg += float(h.stats[k])
		t += "[color=%s]■[/color] %d. %s %s [color=#9db0a2]%s · %s · avg %d[/color]\n" % [h.color, i + 1, h.name, AppState.sex_sign(h), RaceEngine.STYLES[h.style].label, h.gene, roundi(avg / 10.0)]
	field_list.text = t


# ---------------- race control ----------------
func new_race() -> void:
	race = RaceEngine.create_race(AppState.field, AppState.race_opts())
	comm.reset(race)
	running = false; turbo = false; acc = 0.0; _finished_shown = false
	sel = clampi(sel, 0, race.runners.size() - 1)
	play_btn.text = "▶ Start"
	for x in [view, elev]: x.set_race(race)
	board.race = race; hpanel.race = race
	view.banner = ""
	_select(sel)
	comm_now.text = "🎙 " + comm.intro()
	comm_log.clear()
	results_panel.visible = false
	_refresh_field_list()
	view.update_camera(0.0)
	_refresh_panels()

func _on_play() -> void:
	if race.done: new_race()
	running = not running
	turbo = false
	play_btn.text = "⏸ Pause" if running else "▶ Resume"

func _on_next() -> void:
	seed_spin.set_value_no_signal(seed_spin.value + 1)
	AppState.seed = int(seed_spin.value)
	new_race()
	_on_play()

func _on_finish_now() -> void:
	if race.done: return
	running = true; turbo = true
	play_btn.text = "⏸ Pause"

func _on_cam() -> void:
	view.cam_mode = ((view.cam_mode + 1) % 3) as RaceView.Cam
	cam_btn.text = ["📷 Follow selected", "📷 Follow leader", "📷 Full course"][view.cam_mode]

func _select(i: int) -> void:
	sel = i
	for x in [view, elev, board, hpanel]: x.sel = i
	_refresh_panels()

func _on_comm_line(clock: String, text: String, important: bool) -> void:
	comm_now.text = "🎙 " + text
	comm_log.text = "[b][color=#f2c14e]%s[/color][/b] %s%s\n%s" % [clock, "[b]" if important else "", text + ("[/b]" if important else ""), comm_log.text]

func _refresh_panels() -> void:
	board.refresh()
	hpanel.refresh()
	elev.queue_redraw()
	var lap := ""
	var lm: Array = race.marks.filter(func(m): return race.lead.has(m))
	if not lm.is_empty():
		var a: float = race.lead[lm[-1]]
		var b: float = race.lead[lm[-2]] if lm.size() > 1 else 0.0
		lap = " · last 200 m lap %.1f s" % (a - b)
	clock_lbl.text = RaceEngine.fmt_time(RaceEngine.race_clock(race)) + lap


# ---------------- loop ----------------
func _process(delta: float) -> void:
	if race == null: return
	if running and not race.done:
		var t0 := Time.get_ticks_usec()
		var budget := (TURBO_BUDGET_MS if turbo else STEP_BUDGET_MS) * 1000.0
		if not turbo: acc += delta * speed
		var n := 0
		while not race.done and (turbo or acc >= RaceEngine.DT):
			RaceEngine.step(race)
			acc -= RaceEngine.DT
			n += 1
			if n % 4 == 0: comm.update()
			if Time.get_ticks_usec() - t0 > budget:
				acc = minf(acc, RaceEngine.DT * 2.0)    # can't keep up: slow down instead of freezing
				break
		comm.update()
		if race.done:
			comm.update()
			running = false; turbo = false
			play_btn.text = "▶ Start"
	_board_t += delta
	if _board_t > 0.2 or (race.done and not _finished_shown):
		_board_t = 0.0
		_refresh_panels()
	if comm.banner != "" and view.banner != comm.banner:
		view.banner = comm.banner; view.banner_alpha = 1.0
	view.update_camera(delta)
	if race.done and not _finished_shown:
		_finished_shown = true
		_show_results()

func _show_results() -> void:
	var res := RaceEngine.results(race)
	var o := race.opts
	results_tree.clear()
	var root := results_tree.create_item()
	for x in res.rows:
		var r = x.r
		var it := results_tree.create_item(root)
		it.set_metadata(0, r.i)
		it.set_text(0, "DNF" if x.pos < 0 else str(x.pos))
		var c := Color(r.h.color)
		it.set_text(1, str(r.i + 1)); it.set_custom_bg_color(1, c); it.set_custom_color(1, UiTheme.on_silk(c))
		it.set_text_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)
		it.set_text(2, "%s  (%s, %s)" % [x.name, RaceEngine.STYLES[r.h.style].label, r.h.gene])
		it.set_text(3, RaceEngine.fmt_time(x.time))
		it.set_text(4, x.margin)
		it.set_text(5, "%.1f" % x.last3f if x.last3f > 0 else "-")
		it.set_text(6, x.notes)
		if x.pos == 1:
			for k in [0, 2, 3]: it.set_custom_color(k, UiTheme.ACC)
	var w = res.rows[0] if not res.rows.is_empty() else null
	results_head.text = "%s %d m · %s · seed %d — winner %s %s" % [race.course.short, o.dist, RaceEngine.going_label(o.going, race.course.surface), o.seed, w.name if w != null else "-", RaceEngine.fmt_time(w.time) if w != null else ""]
	var laps: PackedStringArray = []
	for x in res.laps: laps.append("%.1f" % x)
	laps_lbl.text = "Laps (leader, 200 m): %s\nFirst 1000 m: %s   ·   Race last 3F: %s   (JRA timing: clock starts when the first horse crosses the line 5 m in front of the gates)" % [
		" - ".join(laps), "%.1f s" % res.first1000 if res.first1000 > 0 else "-", "%.1f s" % res.raceL3F if res.raceL3F > 0 else "-"]
	results_panel.visible = true

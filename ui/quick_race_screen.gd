class_name QuickRaceScreen
extends Control
## Quick Race (from the main menu): pick course, distance, going and a field, then watch it in 3D.

var course_opt: OptionButton
var dist_opt: OptionButton
var going_opt: OptionButton
var field_tree: Tree
var info: Label

func _ready() -> void:
	add_child(UiTheme.background())
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + s, 24)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	var top := HBoxContainer.new()
	var back := Button.new()
	back.text = "‹ Main menu"
	back.pressed.connect(func(): Game.mode = ""; get_tree().change_scene_to_file("res://ui/main.tscn"))
	top.add_child(back)
	var t := UiTheme.title_label("QUICK RACE", 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var go := Button.new()
	go.text = "🎥  START RACE (3D)  ››"
	go.custom_minimum_size = Vector2(240, 46)
	go.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PURPLE, Color(0, 0, 0, 0), 4, 14))
	go.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PURPLE.lightened(0.12), Color(0, 0, 0, 0), 4, 14))
	go.pressed.connect(func():
		Game.mode = "quick"
		Game.pending_replay = {}
		get_tree().change_scene_to_file("res://race3d/race_3d.tscn"))
	top.add_child(go)
	v.add_child(top)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 340
	row.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(UiTheme.section("Race"))
	course_opt = OptionButton.new()
	var last := ""
	for id in RaceEngine.COURSES:
		var c: Dictionary = RaceEngine.COURSES[id]
		var venue: String = id.split("_")[0].capitalize()
		if venue != last:
			course_opt.add_separator(venue); last = venue
		course_opt.add_item("%s (%s, %s)" % [c.short, c.surface, c.dir])
		course_opt.set_item_metadata(course_opt.item_count - 1, id)
		if id == AppState.course: course_opt.select(course_opt.item_count - 1)
	course_opt.item_selected.connect(func(i): AppState.course = course_opt.get_item_metadata(i); _fill_dist(); _fill_going())
	lv.add_child(course_opt)
	dist_opt = OptionButton.new()
	dist_opt.item_selected.connect(func(i): AppState.dist = dist_opt.get_item_id(i))
	lv.add_child(dist_opt)
	going_opt = OptionButton.new()
	for k in RaceEngine.GOING: going_opt.add_item("")
	going_opt.select(RaceEngine.GOING.keys().find(AppState.going))
	_fill_going()
	going_opt.item_selected.connect(func(i): AppState.going = RaceEngine.GOING.keys()[i])
	lv.add_child(going_opt)
	var seed := SpinBox.new()
	seed.prefix = "Seed"
	seed.min_value = 1; seed.max_value = 999999; seed.value = AppState.seed
	seed.value_changed.connect(func(x): AppState.seed = int(x))
	lv.add_child(seed)
	info = UiTheme.dim_label("", 12)
	lv.add_child(info)
	lv.add_child(UiTheme.section("Field"))
	var n := SpinBox.new()
	n.prefix = "Runners"
	n.min_value = 2; n.max_value = 18; n.value = AppState.runners
	lv.add_child(n)
	for b in [["New field (bred from stud book)", "rand"], ["All equal (stats 70)", "equal"], ["Gene test (75, CC/CT/TT)", "genes"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(func(): AppState.build_field(b[1], int(n.value)); _fill_field())
		lv.add_child(btn)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	rv.add_child(UiTheme.section("Runners"))
	field_tree = Tree.new()
	field_tree.hide_root = true
	field_tree.columns = 7
	field_tree.column_titles_visible = true
	field_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 7: field_tree.set_column_title(i, ["No", "Horse", "Style", "Gene", "Avg", "Best", "Jockey"][i])
	for i in 7:
		field_tree.set_column_expand(i, i == 1)
		field_tree.set_column_custom_minimum_width(i, [56, 240, 130, 70, 70, 90, 80][i])
	rv.add_child(field_tree)
	if AppState.field.is_empty(): AppState.build_field("rand")
	_fill_dist()
	_fill_field()

func _fill_dist() -> void:
	var T: Dictionary = RaceEngine.COURSES[AppState.course]
	dist_opt.clear()
	if not T.distances.has(AppState.dist): AppState.dist = T.def
	for d in T.distances:
		dist_opt.add_item("%d m" % d, d)
		if d == AppState.dist: dist_opt.select(dist_opt.item_count - 1)
	info.text = "%s · %s · loop %s m · straight %s m · height difference %s m\n%s" % [T.name, "straight course" if T.straight else ("left-handed" if T.dir == "L" else "right-handed"), str(T.C), str(T.finish), str(T.hdiff), T.slopeNote]

func _fill_field() -> void:
	field_tree.clear()
	var root := field_tree.create_item()
	for i in AppState.field.size():
		var h: Dictionary = AppState.field[i]
		var it := field_tree.create_item(root)
		var avg := 0.0
		for k in RaceEngine.STATS: avg += float(h.stats[k])
		it.set_text(0, str(i + 1))
		it.set_custom_bg_color(0, Color(h.color)); it.set_custom_color(0, UiTheme.on_silk(Color(h.color)))
		it.set_text(1, "%s %s" % [h.name, AppState.sex_sign(h)])
		it.set_text(2, RaceEngine.STYLES[h.style].label)
		it.set_text(3, h.gene)
		it.set_text(4, str(roundi(avg / 10.0)))
		it.set_text(5, "%d m" % (int(Career.best_dist(h) / 100.0) * 100))
		it.set_text(6, str(int(h.get("jockey", 75))))

func _fill_going() -> void:
	var surf: String = RaceEngine.COURSES[AppState.course].surface
	var keys: Array = RaceEngine.GOING.keys()
	for i in keys.size(): going_opt.set_item_text(i, RaceEngine.going_label(keys[i], surf))

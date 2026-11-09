class_name SilkEditor
extends HBoxContainer
## Racing silks designer: live jacket preview + body / pattern / sleeve choices (JRA colours and patterns).

signal changed(silks: Dictionary)

var silks: Dictionary
var preview: TextureRect
var _rows := {}

func setup(start: Dictionary, compact := false) -> SilkEditor:
	silks = start.duplicate()
	add_theme_constant_override("separation", 18)
	var pv := VBoxContainer.new()
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(150, 125) if compact else Vector2(220, 184)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pv.add_child(preview)
	if not compact:
		pv.add_child(UiTheme.dim_label("In JRA races the cap colour follows the gate bracket (white, black, red, blue, yellow, green, orange, pink), so only the jacket is yours.", 11))
		pv.custom_minimum_size.x = 230
	add_child(pv)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(g)
	_colour_row(g, "Body colour", "body")
	_pattern_row(g, "Body pattern", "pattern", Silks.BODY)
	_colour_row(g, "Pattern colour", "pcol")
	_colour_row(g, "Sleeve colour", "sleeve")
	_pattern_row(g, "Sleeve pattern", "spattern", Silks.SLEEVE)
	_colour_row(g, "Sleeve pattern colour", "scol")
	_refresh()
	return self

func _colour_row(g: GridContainer, label: String, key: String) -> void:
	g.add_child(UiTheme.label(label, 13, UiTheme.TEXT))
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 3)
	h.add_theme_constant_override("v_separation", 3)
	var btns: Array = []
	for c in Silks.COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.tooltip_text = "%s (%s)" % [c[0], c[1]]
		b.toggle_mode = true
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(c[2]), UiTheme.LINE, 4, 2))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color(c[2]), UiTheme.ACC, 4, 2, 2))
		b.add_theme_stylebox_override("pressed", UiTheme.box(Color(c[2]), Color("e39a16"), 4, 2, 3))
		var hex: String = c[2]
		b.pressed.connect(func(): silks[key] = hex; _refresh())
		btns.append([b, hex])
		h.add_child(b)
	_rows[key] = btns
	g.add_child(h)

func _pattern_row(g: GridContainer, label: String, key: String, list: Array) -> void:
	g.add_child(UiTheme.label(label, 13, UiTheme.TEXT))
	var ob := OptionButton.new()
	for p in list: ob.add_item("%s  %s" % [p[1], p[2]])
	for i in list.size():
		if list[i][0] == silks[key]: ob.select(i)
	ob.item_selected.connect(func(i): silks[key] = list[i][0]; _refresh())
	ob.custom_minimum_size.x = 220
	ob.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	g.add_child(ob)

func _refresh() -> void:
	for key in _rows:
		for x in _rows[key]: x[0].button_pressed = String(silks[key]).to_lower() == String(x[1]).to_lower()
	preview.texture = Silks.preview(silks, 180, 150, "")
	changed.emit(silks.duplicate())

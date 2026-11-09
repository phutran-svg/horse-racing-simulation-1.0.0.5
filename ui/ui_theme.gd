class_name UiTheme
extends RefCounted
## Colours and theme. Light JRA-style look for the game screens (white cards, green gradient, green bars);
## the dark palette is kept for the 3D race overlay. Built in code, no .tres needed.

# Palette. Light (default): white cards on a white-to-green gradient, JRA green bars and headings.
# Dark: used by the 3D race overlay, where text sits on top of the race picture.
static var dark := false
static var BG := Color("f3f8f2")
static var PANEL := Color("ffffff")
static var PANEL2 := Color("eaf3e8")
static var SIDEBAR := Color("0b6b3a")
static var TOPBAR := Color("0e7c44")
static var LINE := Color("cfe0cb")
static var TEXT := Color("1c2a21")
static var DIM := Color("5e6f63")
static var ACC := Color("0a7a3e")      # section titles / highlights
static var PURPLE := Color("e39a16")   # Continue / main action button (gold on the green bar)
static var GOOD := Color("1f9d4a")
static var BAD := Color("d63a3f")
static var BLUE := Color("2a78c2")
static var GOLD := Color("b8860b")     # G1
static var STRONG := Color("0f1a13")   # strongest text (names, big numbers)
static var MINE := Color("7b3fcf")     # the player's own horses and results
static var TINT := Color(0, 0, 0, 0.035)
static var SEL := Color("d5ecd8")
const ON_BAR := Color("ffffff")        # text on the green bars
const ON_BAR_DIM := Color("cfe6d6")

static func set_dark(on: bool) -> void:
	dark = on
	if on:
		BG = Color("1e1b33"); PANEL = Color("27243f"); PANEL2 = Color("312d4d"); SIDEBAR = Color("1a1630"); TOPBAR = Color("2a2150")
		LINE = Color("3c3760"); TEXT = Color("ecebf5"); DIM = Color("a5a2c0"); ACC = Color("f5a524"); PURPLE = Color("6d4df2")
		GOOD = Color("4cd964"); BAD = Color("e5484d"); BLUE = Color("4a9fe0"); GOLD = Color("f2c14e"); STRONG = Color.WHITE
		MINE = Color("b7a6ff"); TINT = Color(1, 1, 1, 0.04); SEL = Color("3f2f86")
	else:
		BG = Color("f3f8f2"); PANEL = Color("ffffff"); PANEL2 = Color("eaf3e8"); SIDEBAR = Color("0b6b3a"); TOPBAR = Color("0e7c44")
		LINE = Color("cfe0cb"); TEXT = Color("1c2a21"); DIM = Color("5e6f63"); ACC = Color("0a7a3e"); PURPLE = Color("e39a16")
		GOOD = Color("1f9d4a"); BAD = Color("d63a3f"); BLUE = Color("2a78c2"); GOLD = Color("b8860b"); STRONG = Color("0f1a13")
		MINE = Color("7b3fcf"); TINT = Color(0, 0, 0, 0.035); SEL = Color("d5ecd8")

## page background: soft white-to-green gradient (flat colour in dark mode)
static func background() -> Control:
	if dark:
		var cr := ColorRect.new()
		cr.color = BG
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return cr
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color("ffffff"), Color("eef6ec"), Color("d6ead2")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64; gt.height = 64
	gt.fill_from = Vector2(0.2, 0.0); gt.fill_to = Vector2(0.8, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

const SILKS := ["#ffffff", "#111111", "#e5484d", "#3b82f6", "#facc15", "#22c55e", "#f97316", "#ec4899", "#a855f7", "#14b8a6", "#84cc16", "#f43f5e", "#0ea5e9", "#eab308", "#8b5cf6", "#10b981", "#fb923c", "#94a3b8"]

static func silk(i: int) -> Color:
	return Color(SILKS[i % SILKS.size()])

## text colour that reads on top of a silk colour
static func on_silk(c: Color) -> Color:
	return Color.BLACK if c.get_luminance() > 0.55 else Color.WHITE

## attribute colour (stats 1-100), like FM's 1-20 colouring
static func stat_color(v: float) -> Color:
	if dark:
		if v >= 85: return Color("3ee07a")
		if v >= 72: return Color("9be35a")
		if v >= 60: return Color("e8e46a")
		if v >= 48: return Color("ecebf5")
		return Color("8f8ba8")
	if v >= 85: return Color("0f8a3c")
	if v >= 72: return Color("4d8f12")
	if v >= 60: return Color("a87800")
	if v >= 48: return TEXT
	return Color("8a958d")

static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 6, pad := 8, bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	return s

static func _box(bg: Color, border := Color(0, 0, 0, 0), radius := 6, pad := 8, bw := 1) -> StyleBoxFlat:
	return box(bg, border, radius, pad, bw)

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE if not dark else Color(0, 0, 0, 0), 6 if not dark else 4, 12))
	t.set_stylebox("panel", "Panel", box(PANEL, Color(0, 0, 0, 0), 4, 12))
	var press := ACC if not dark else PURPLE.darkened(0.2)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, box(PANEL2, LINE if not dark else Color(0, 0, 0, 0), 4, 10))
		t.set_stylebox("hover", cls, box(PANEL2.darkened(0.04) if not dark else PANEL2.lightened(0.1), ACC if not dark else Color(0, 0, 0, 0), 4, 10))
		t.set_stylebox("pressed", cls, box(press, Color(0, 0, 0, 0), 4, 10))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_stylebox("disabled", cls, box(PANEL, Color(0, 0, 0, 0), 4, 10))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, STRONG)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, DIM.darkened(0.3))
	t.set_stylebox("normal", "LineEdit", box(BG, LINE, 4, 8))
	t.set_stylebox("focus", "LineEdit", box(BG, ACC if not dark else PURPLE, 4, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", DIM.darkened(0.2))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", STRONG)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "Tree", box(PANEL, Color(0, 0, 0, 0), 4, 2))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", STRONG)
	t.set_color("title_button_color", "Tree", DIM)
	t.set_stylebox("title_button_normal", "Tree", box(PANEL, Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("title_button_hover", "Tree", box(PANEL2, Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("title_button_pressed", "Tree", box(PANEL2, Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("selected", "Tree", box(SEL, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("selected_focus", "Tree", box(SEL, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("hovered", "Tree", box(TINT, Color(0, 0, 0, 0), 0, 2))
	t.set_color("guide_color", "Tree", TINT)
	t.set_constant("v_separation", "Tree", 6)
	t.set_constant("draw_guides", "Tree", 1)
	t.set_stylebox("panel", "PopupMenu", box(PANEL2, LINE, 4, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", STRONG)
	t.set_color("font_separator_color", "PopupMenu", ACC)
	t.set_stylebox("hover", "PopupMenu", box(SEL, Color(0, 0, 0, 0), 2, 4))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL2, LINE, 4, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, LINE, 6, 14))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.06 if not dark else 0.15), Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(DIM.darkened(0.3), Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("scroll", "HScrollBar", box(Color(0, 0, 0, 0.15), Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("grabber", "HScrollBar", box(LINE, Color(0, 0, 0, 0), 4, 2))
	t.set_stylebox("slider", "HSlider", box(LINE, Color(0, 0, 0, 0), 3, 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACC if not dark else PURPLE, Color(0, 0, 0, 0), 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box((ACC if not dark else PURPLE).lightened(0.2), Color(0, 0, 0, 0), 3, 2))
	t.set_stylebox("tab_selected", "TabBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10))
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	return t

static func title_label(text: String, size := 16, color := ACC) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## orange FM-style section heading ("FITNESS ›")
static func section(text: String) -> Label:
	var l := title_label(text.to_upper() + "  ›", 13, ACC)
	return l

static func dim_label(text: String, size := 12) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func label(text: String, size := 14, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func stars(v: float) -> String:
	## v = 0..5 in halves
	var full := int(floor(v))
	var half := v - full >= 0.5
	return "★".repeat(full) + ("½" if half else "") + "☆".repeat(5 - full - (1 if half else 0))

class_name StandingsBoard
extends Control
## Live running order: position, horse, gap (lengths), speed, energy reserve, heart rate, flags. Click to select.

signal horse_selected(i: int)

const ROW := 24.0
const HEAD := 22.0
var race: RaceEngine.Race
var sel := 0
var _rows: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click a horse to follow it.\nGap = lengths behind the leader · Energy = anaerobic + guts reserve left\n✚ injured · ● lung bleeding (EIPH) · ▣ boxed in · ≋ drafting"
	clip_contents = true

func refresh() -> void:
	if race == null: return
	_rows = RaceCommentary.standings(race)
	custom_minimum_size.y = HEAD + ROW * _rows.size() + 4
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var k := int((e.position.y - HEAD) / ROW)
		if k >= 0 and k < _rows.size():
			sel = _rows[k].i
			horse_selected.emit(sel)
			queue_redraw()
		accept_event()

func _draw() -> void:
	if race == null or _rows.is_empty(): return
	var font := get_theme_default_font()
	var W := size.x
	# columns: pos | silk | name | flags | gap | km/h | energy   (right-hand columns fixed)
	var x_en := W - 46.0
	var x_kmh := W - 92.0
	var x_gap := W - 134.0
	var x_flag := W - 166.0
	var x_name := 60.0
	var cols := [4.0, 30.0, x_gap, x_kmh, x_en]
	for c in [["#", 0], ["Horse", 1], ["Gap", 2], ["km/h", 3], ["Energy", 4]]:
		draw_string(font, Vector2(cols[c[1]], 15), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.DIM)
	draw_line(Vector2(0, HEAD - 2), Vector2(W, HEAD - 2), UiTheme.LINE)
	var lead = _rows[0]
	for k in _rows.size():
		var r = _rows[k]
		var y := HEAD + k * ROW
		if r.i == sel: draw_rect(Rect2(0, y, W, ROW), Color(UiTheme.ACC, 0.14))
		elif k % 2 == 1: draw_rect(Rect2(0, y, W, ROW), Color(1, 1, 1, 0.025))
		var ty := y + 16.0
		var dim: bool = r.state == &"dnf" or r.state == &"pulling"
		var tc := UiTheme.DIM if dim else UiTheme.TEXT
		draw_string(font, Vector2(cols[0], ty), "DNF" if r.state == &"dnf" else str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
		var c := Color(r.h.get("color", "#ffffff"))
		draw_rect(Rect2(cols[1], y + 4, 24, 16), c)
		draw_string(font, Vector2(cols[1], ty - 1), str(r.i + 1), HORIZONTAL_ALIGNMENT_CENTER, 24, 11, UiTheme.on_silk(c))
		draw_string(font, Vector2(x_name, ty), r.h.name, HORIZONTAL_ALIGNMENT_LEFT, x_flag - x_name - 2.0, 13, tc)
		var fx := x_flag
		if not r.injury.is_empty():
			draw_string(font, Vector2(fx, ty), "✚", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.BAD); fx += 11
		if r.eiph > 0:
			draw_circle(Vector2(fx + 4, ty - 4), 3.5, Color("d0103a")); fx += 11
		if r.blocked > 0.5:
			draw_string(font, Vector2(fx, ty), "▣", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.BLUE); fx += 11
		elif r.draft and r.state == &"run":
			draw_string(font, Vector2(fx, ty), "≋", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.BLUE)
		var gap := 0.0
		if r.state == &"fin" and lead.state == &"fin": gap = (r.finishT - lead.finishT) * 17.0 / 2.4
		else: gap = (lead.dist - r.dist) / 2.4
		draw_string(font, Vector2(cols[2], ty), "-" if (k == 0 or r.state == &"dnf" or gap > 99.0) else "%.1f" % gap, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
		draw_string(font, Vector2(cols[3], ty), "%.1f" % (r.v * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
		var res: float = clampf((maxf(0.0, r.D) + r.G) / (r.p.d0 + r.p.gutsRes), 0.0, 1.0)
		draw_rect(Rect2(cols[4], y + 8, 42, 8), UiTheme.BG)
		draw_rect(Rect2(cols[4], y + 8, 42 * res, 8), UiTheme.BAD if res < 0.15 else UiTheme.ACC)

class_name ElevView
extends Control
## Elevation profile of the race distance with the field on it (shaded = bends).

var race: RaceEngine.Race
var sel := 0
var _prof := PackedVector2Array()     # (d, h)
var _bends: Array = []                # [d0, d1]
var _hmin := 0.0
var _hmax := 1.0
var _key := ""

func _ready() -> void:
	custom_minimum_size = Vector2(0, 110)

func set_race(r: RaceEngine.Race) -> void:
	race = r
	_key = ""
	queue_redraw()

func _prepare() -> void:
	var key := "%s-%d" % [race.course.id, race.opts.dist]
	if key == _key: return
	_key = key
	RaceEngine.use_course(race.course.id)
	var D: int = race.opts.dist
	_prof = PackedVector2Array()
	_bends = []
	var in_bend := false
	var d := 0
	while d <= D:
		_prof.append(Vector2(d, RaceEngine.race_elev(race, d)))
		var c := RaceEngine.race_curve(race, d)
		if c and not in_bend: _bends.append([float(d), float(D)])
		if not c and in_bend: _bends[-1][1] = float(d)
		in_bend = c
		d += 5
	var hs: Array = race.course.elev.map(func(e): return float(e[1]))
	_hmin = hs.min() - 0.3
	_hmax = hs.max() + 0.4

func _draw() -> void:
	if race == null: return
	_prepare()
	RaceEngine.use_course(race.course.id)
	var font := get_theme_default_font()
	var W := size.x
	var H := size.y
	var D := float(race.opts.dist)
	var pad := 26.0
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	var X := func(d: float) -> float: return pad + (W - pad - 8.0) * d / D
	var Y := func(h: float) -> float: return H - 18.0 - (H - 34.0) * (h - _hmin) / (_hmax - _hmin)
	for b in _bends:
		draw_rect(Rect2(X.call(b[0]), 18, X.call(b[1]) - X.call(b[0]), H - 36), UiTheme.TINT)
	var pts := PackedVector2Array()
	for p in _prof: pts.append(Vector2(X.call(p.x), Y.call(p.y)))
	var fill := pts.duplicate()
	fill.append(Vector2(X.call(D), H - 18.0)); fill.append(Vector2(X.call(0.0), H - 18.0))
	draw_colored_polygon(fill, Color(0.62, 0.69, 0.64, 0.12))
	draw_polyline(pts, UiTheme.DIM, 2.0, true)
	draw_string(font, Vector2(pad, 13), "Elevation (m) · shaded = bends · %s" % race.course.slopeNote, HORIZONTAL_ALIGNMENT_LEFT, W - pad, 11, UiTheme.DIM)
	var stp := 2.0 if _hmax - _hmin > 4.0 else 1.0
	var h := ceilf(_hmin)
	while h <= _hmax:
		draw_string(font, Vector2(4, Y.call(h) + 4), str(int(h)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.DIM)
		h += stp
	var k := 0
	while k * 400 <= D:
		var d := D - k * 400.0
		draw_string(font, Vector2(X.call(d) - 20, H - 4), "GOAL" if k == 0 else str(k * 400), HORIZONTAL_ALIGNMENT_CENTER, 40, 10, UiTheme.DIM)
		k += 1
	for r in race.runners:
		var c := Color(r.h.get("color", "#ffffff"))
		var p := Vector2(X.call(clampf(r.dist, 0.0, D)), Y.call(RaceEngine.race_elev(race, r.dist)))
		draw_circle(p, 5.0 if r.i == sel else 3.5, c)
		draw_arc(p, 5.0 if r.i == sel else 3.5, 0, TAU, 12, UiTheme.ACC if r.i == sel else Color.BLACK, 1.0, true)

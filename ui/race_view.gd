class_name RaceView
extends Control
## Top-down live race view: course, rails, poles, grandstand, slope tint and the runners.
## World units are metres (x along the straights, y across; y up). Camera follows a horse, the leader or shows
## the whole course. Click a horse to select it; mouse wheel zooms.

signal horse_selected(i: int)

enum Cam { FOLLOW, LEADER, FULL }

var race: RaceEngine.Race
var sel := 0
var mini := false                  # small TV-graphic map: no labels, HUD or input
var cam_mode := Cam.FOLLOW
var zoom := 7.0
var banner := ""
var banner_alpha := 0.0
var _cam := Vector3.ZERO          # x, y, scale
var _cam_ok := false
var _cache_key := ""
var _loops := {}                   # offset -> PackedVector2Array (world)
var _tint: Array = []              # [PackedVector2Array, Color]
var _stripes: Array = []
var _circle := PackedVector2Array()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for k in 20: _circle.append(Vector2(cos(TAU * k / 20.0), sin(TAU * k / 20.0)))

func set_race(r: RaceEngine.Race) -> void:
	race = r
	_cam_ok = false
	_build_cache()
	queue_redraw()


# ---------------- geometry cache (per course) ----------------
func _loop_end() -> float:
	return race.course.S if race.course.straight else race.course.C

func _path(off: float, a: float, b: float, step := 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := a
	while s < b:
		pts.append(RaceEngine.xy(s, off)); s += step
	pts.append(RaceEngine.xy(minf(b, s) if race.course.straight else b, off))
	return pts

func _build_cache() -> void:
	var T: Dictionary = race.course
	var key := "%s" % T.id
	if key == _cache_key: return
	_cache_key = key
	RaceEngine.use_course(T.id)
	_loops = {}
	var end := _loop_end()
	for off in [0.0, T.width / 2.0, T.width, -16.0, T.width + 12.0]:
		_loops[off] = _path(off, 0.0, end, 2.0)
	_tint = []
	var s := 0.0
	while s < end - 6.0:
		var g := RaceEngine.grade(s + 3.0)
		if absf(g) >= 0.002:
			var c := Color(0.88, 0.47, 0.23, minf(0.5, g * 40.0)) if g > 0.0 else Color(0.29, 0.62, 0.88, minf(0.5, -g * 40.0))
			_tint.append([_path(T.width / 2.0, s, s + 6.5, 2.0), c])
		s += 6.0
	_stripes = []
	s = 0.0
	while s < end - 10.0:
		_stripes.append(_path(T.width / 2.0, s, s + 10.0, 2.0))
		s += 20.0


# ---------------- camera ----------------
func full_scale() -> float:
	var T: Dictionary = race.course
	var W := size.x
	var H := size.y
	if T.straight: return minf(W / (T.S + 60.0), H / 160.0)
	return minf(W / (T.S + 2.0 * (T.r + T.width + 45.0)), H / (2.0 * (T.r + T.width + 45.0)))

func _cam_target() -> Vector3:
	var T: Dictionary = race.course
	var fs := full_scale()
	if cam_mode == Cam.FULL: return Vector3(0, -T.r - 10.0, fs) if T.straight else Vector3(0, 0, fs)
	var r = race.runners[sel] if sel < race.runners.size() else race.runners[0]
	if cam_mode == Cam.LEADER or r.state == &"dnf":
		r = null
		for x in race.runners:
			if x.state != &"dnf" and (r == null or x.dist > r.dist): r = x
		if r == null: r = race.runners[0]
	var p := RaceEngine.race_xy(race, r.dist, r.lane + 4.0)
	return Vector3(p.x, p.y, maxf(fs, zoom))

func update_camera(dt: float) -> void:
	if race == null: return
	RaceEngine.use_course(race.course.id)
	var tgt := _cam_target()
	if not _cam_ok or dt <= 0.0 or cam_mode == Cam.FULL:
		_cam = tgt; _cam_ok = true
	else:
		var k := 1.0 - exp(-dt * 5.0)
		_cam += (tgt - _cam) * k
	banner_alpha = maxf(0.0, banner_alpha - dt * 0.12) if banner != "" else 0.0
	queue_redraw()

func P(w: Vector2) -> Vector2:
	return Vector2(size.x / 2.0 + (w.x - _cam.x) * _cam.z, size.y / 2.0 - (w.y - _cam.y) * _cam.z)

func _world_xform() -> void:
	var sc := _cam.z
	draw_set_transform(Vector2(size.x / 2.0 - _cam.x * sc, size.y / 2.0 + _cam.y * sc), 0.0, Vector2(sc, -sc))


# ---------------- input ----------------
func _gui_input(e: InputEvent) -> void:
	if race == null or mini: return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_by(1.25)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_by(1.0 / 1.25)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			RaceEngine.use_course(race.course.id)
			var best := -1
			var bd := 30.0
			for r in race.runners:
				var d: float = P(RaceEngine.race_xy(race, r.dist, r.lane)).distance_to(e.position)
				if d < bd:
					bd = d; best = r.i
			if best >= 0:
				sel = best
				if cam_mode == Cam.LEADER: cam_mode = Cam.FOLLOW
				horse_selected.emit(best)
		accept_event()

func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 1.2, 16.0)
	if cam_mode == Cam.FULL and f > 1.0: cam_mode = Cam.FOLLOW
	queue_redraw()


# ---------------- drawing ----------------
func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in _circle: p.append(c + Vector2(v.x * rx, v.y * ry))
	return p

func _line_w(px: float) -> float:
	return px / _cam.z          # constant screen width under the world transform

func _draw() -> void:
	if race == null or not _cam_ok: return
	var T: Dictionary = race.course
	RaceEngine.use_course(T.id)
	var W := size.x
	var H := size.y
	var sc := _cam.z
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("2f5a35"))
	var dirtC: bool = T.surface == "dirt"
	_world_xform()
	# infield: outer turf course around a dirt course, or the inner dirt/sand ring, and the infield lake
	if dirtC: draw_polyline(_loops[T.width + 12.0], Color("3a7a43"), 18.0)
	elif not T.straight:
		draw_polyline(_loops[-16.0], Color("8a6a46"), 16.0)
		draw_polyline(_loops[-16.0], Color("9b7a52"), 13.0)
	if not T.straight: draw_colored_polygon(_ellipse(Vector2.ZERO, T.S * 0.28, T.r * 0.28), Color("3b6fa0"))
	# grandstand outside the home straight
	var go := 26.0 if dirtC else 0.0
	var ga := RaceEngine.xy(T.finish - 300.0, T.width + 14.0 + go)
	var gb := RaceEngine.xy(T.finish + 40.0, T.width + 42.0 + go)
	var grect := Rect2(Vector2(minf(ga.x, gb.x), minf(ga.y, gb.y)), (gb - ga).abs())
	draw_rect(grect, Color("5f646b"))
	draw_rect(Rect2(grect.position + Vector2(0, grect.size.y * 0.65) if ga.y < 0 else grect.position, Vector2(grect.size.x, grect.size.y * 0.35)), Color("7d838b"))
	# racing surface, mowing stripes / harrow lines
	var surf := Color("a07c52") if dirtC else Color("3f8a49")
	var full_line: PackedVector2Array = _loops[T.width / 2.0]
	if not T.straight: full_line = full_line.duplicate(); full_line.append(full_line[0])
	draw_polyline(full_line, surf, T.width)
	if race.chute.has("L"):
		draw_line(RaceEngine.race_xy(race, -12.0, T.width / 2.0), RaceEngine.race_xy(race, race.chute.L, T.width / 2.0), surf, T.width)
	if not dirtC:
		for p in _stripes: draw_polyline(p, Color(1, 1, 1, 0.05), T.width)
	# slope tint (orange = uphill, blue = downhill)
	var am := 0.35 if sc > 2.5 else 1.0
	for seg in _tint:
		var c: Color = seg[1]
		draw_polyline(seg[0], Color(c.r, c.g, c.b, c.a * am), T.width)
	# rails
	for off in [0.0, T.width]:
		var rail: PackedVector2Array = _loops[off]
		if not T.straight: rail = rail.duplicate(); rail.append(rail[0])
		draw_polyline(rail, Color("f7f7f7"), maxf(_line_w(1.2), 0.25))
	if race.chute.has("L"):
		for off in [0.0, T.width]:
			draw_line(RaceEngine.race_xy(race, -12.0, off), RaceEngine.race_xy(race, race.chute.L, off), Color("f7f7f7"), maxf(_line_w(1.2), 0.25))
	# poles, finish, start
	var k := 1
	var lab: Array = []
	while k * 200 < (T.finish if T.straight else T.C):
		var s: float = T.finish - 200.0 * k
		draw_line(RaceEngine.xy(s, -1.0), RaceEngine.xy(s, T.width + 1.0), Color(1, 1, 1, 0.45), _line_w(1.0))
		if sc > 2.5 or k % 2 == 0: lab.append([RaceEngine.xy(s, -6.0), str(200 * k), Color(1, 1, 1, 0.6)])
		k += 1
	draw_line(RaceEngine.xy(T.finish, -1.0), RaceEngine.xy(T.finish, T.width + 1.0), Color("ff4d4d"), maxf(_line_w(2.0), 0.4))
	lab.append([RaceEngine.xy(T.finish, -6.0), "GOAL", Color("ff4d4d")])
	draw_line(RaceEngine.race_xy(race, 0.0, -1.0), RaceEngine.race_xy(race, 0.0, T.width + 1.0), ACC_START, maxf(_line_w(2.0), 0.3))
	lab.append([RaceEngine.race_xy(race, 0.0, T.width + 7.0), "START", ACC_START])
	draw_line(RaceEngine.race_xy(race, -5.0, -1.0), RaceEngine.race_xy(race, -5.0, T.width + 1.0), Color(0.95, 0.76, 0.31, 0.5), maxf(_line_w(1.0), 0.15))
	draw_set_transform(Vector2.ZERO)
	if mini:
		for r in race.runners:
			if r.state == &"dnf": continue
			var mp := P(RaceEngine.race_xy(race, r.dist, r.lane))
			draw_circle(mp, 4.0 if r.i == sel else 3.0, Color(r.h.get("color", "#ffffff")))
			draw_arc(mp, 4.0 if r.i == sel else 3.0, 0, TAU, 10, UiTheme.ACC if r.i == sel else Color.BLACK, 1.0, true)
		return
	# labels (screen space)
	var fs := int(clampf(6.0 + sc, 9.0, 13.0))
	for l in lab:
		var p := P(l[0])
		if p.x < -40 or p.x > W + 40 or p.y < -20 or p.y > H + 20: continue
		draw_string(font, p + Vector2(-20, 4), l[1], HORIZONTAL_ALIGNMENT_CENTER, 40, fs, l[2])
	var gp := P(grect.get_center())
	draw_string(font, gp + Vector2(-60, 5), "GRANDSTAND", HORIZONTAL_ALIGNMENT_CENTER, 120, int(clampf(5.0 + sc * 2.0, 9.0, 14.0)), Color(0.87, 0.87, 0.87))
	if sc < 2.0 and not T.straight:
		var m := -1.0 if T.dir == "R" else 1.0
		var fl := func(t: String, w: Vector2) -> void:
			var q := P(w)
			draw_string(font, q + Vector2(-80, 0), t, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(1, 1, 1, 0.8))
		fl.call("← Home straight" if T.dir == "R" else "Home straight →", Vector2(0, -T.r + 22.0))
		fl.call("Backstretch →" if T.dir == "R" else "← Backstretch", Vector2(0, T.r - 16.0))
		fl.call("1–2 corner", Vector2(m * (T.S / 2.0 + T.r * 0.55), 0))
		fl.call("3–4 corner", Vector2(-m * (T.S / 2.0 + T.r * 0.55), 0))
	# runners (inside lanes first so outer horses draw on top)
	var order := race.runners.duplicate()
	order.sort_custom(func(a, b): return a.lane < b.lane)
	var big := sc >= 3.2
	for r in order:
		var wp := RaceEngine.race_xy(race, r.dist, r.lane)
		var px := P(wp)
		if px.x < -30 or px.x > W + 30 or px.y < -30 or px.y > H + 30: continue
		var w2 := RaceEngine.race_xy(race, r.dist + 1.0, r.lane)
		var ang := atan2(-(w2.y - wp.y), w2.x - wp.x)
		var gone: bool = r.state == &"dnf" or r.state == &"pulling"
		var col := Color(r.h.get("color", "#ffffff"))
		if big:
			_draw_horse(r, px, ang, sc, col, 0.45 if gone else 1.0)
			if r.i == sel or not r.injury.is_empty():
				draw_arc(px, 1.9 * sc, 0, TAU, 32, Color("ff3b3b") if not r.injury.is_empty() else UiTheme.ACC, 2.0, true)
			if r.eiph > 0: draw_circle(px + Vector2(0.9, -0.9) * sc, maxf(2.5, 0.25 * sc), Color("d0103a"))
			var t := str(r.i + 1)
			var fsz := int(maxf(10.0, sc * 1.1))
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			var tp := px + Vector2(-tw / 2.0, -1.3 * sc)
			draw_rect(Rect2(tp + Vector2(-3, -fsz), Vector2(tw + 6, fsz + 4)), Color(0, 0, 0, 0.55))
			draw_string(font, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color.WHITE)
		else:
			var rad := maxf(3.5, 0.75 * sc)
			draw_circle(px, rad, Color("666666") if gone else col)
			draw_arc(px, rad, 0, TAU, 16, Color("ff3b3b") if not r.injury.is_empty() else (UiTheme.ACC if r.i == sel else Color.BLACK), 3.0 if r.i == sel else 1.0, true)
			if r.eiph > 0: draw_circle(px + Vector2(rad, -rad), 2.2, Color("d0103a"))
	_draw_hud(font)
	_draw_mini()

const ACC_START := Color("f2c14e")

func _draw_horse(r, px: Vector2, ang: float, sc: float, silk: Color, alpha: float) -> void:
	var coat := Color(r.h.get("coatColor", "#7a4a26"))
	coat.a = alpha
	var ph: float = r.strides * TAU
	var moving: bool = r.v > 0.5
	draw_set_transform(px, ang, Vector2(sc, sc))
	draw_colored_polygon(_ellipse(Vector2(0.25, 0.3), 1.25, 0.42), Color(0, 0, 0, 0.28 * alpha))
	for lg in [[0.75, -0.2, 0.0], [0.75, 0.2, 0.6], [-0.75, -0.2, 2.6], [-0.75, 0.2, 3.2]]:
		var sw := sin(ph + lg[2]) * 0.45 if moving else 0.0
		draw_line(Vector2(lg[0], lg[1]), Vector2(lg[0] + sw, lg[1] * 1.6), coat, 0.13)
	var tail := PackedVector2Array()
	for k in 6:
		var u := k / 5.0
		tail.append(Vector2(-1.0 - 0.6 * u, sin(ph * (1.0 - 0.5 * u)) * 0.18 * u))
	draw_polyline(tail, Color(0.1, 0.07, 0.05, alpha), 0.14)
	draw_colored_polygon(_ellipse(Vector2.ZERO, 1.05, 0.34), coat)
	var nod := sin(ph) * 0.06 if moving else 0.0
	draw_colored_polygon(_ellipse(Vector2(1.2 + nod, 0), 0.42, 0.15), coat)
	draw_colored_polygon(_ellipse(Vector2(1.62 + nod, 0), 0.2, 0.11), coat)
	draw_rect(Rect2(-0.45, -0.38, 0.55, 0.76), Color(0.96, 0.96, 0.96, alpha))
	silk.a = alpha
	draw_colored_polygon(_ellipse(Vector2.ZERO, 0.3, 0.27), silk)
	draw_circle(Vector2(0.3, 0), 0.13, silk)
	draw_set_transform(Vector2.ZERO)

func _draw_hud(font: Font) -> void:
	var st := RaceCommentary.standings(race).filter(func(r): return r.state != &"dnf")
	var L = st[0] if not st.is_empty() else null
	draw_rect(Rect2(8, 8, 160, 44), Color(0.04, 0.06, 0.05, 0.75))
	draw_string(font, Vector2(16, 30), RaceEngine.fmt_time(RaceEngine.race_clock(race)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.ACC)
	var sub := "FINISHED" if race.done else ("%d/%d finished" % [race.order.size(), race.runners.size()] if not race.order.is_empty() else "%d m to go" % roundi(maxf(0.0, race.opts.dist - (L.dist if L != null else 0.0))))
	draw_string(font, Vector2(16, 46), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT)
	var n := mini(6, st.size())
	var bw := 34.0
	var x0 := size.x - 8.0 - n * bw
	if n > 0: draw_rect(Rect2(x0 - 4, 8, n * bw + 4, 30), Color(0.04, 0.06, 0.05, 0.75))
	for k in n:
		var r = st[k]
		var c := Color(r.h.get("color", "#ffffff"))
		draw_rect(Rect2(x0 + k * bw, 12, bw - 4, 22), c)
		draw_string(font, Vector2(x0 + k * bw, 29), str(r.i + 1), HORIZONTAL_ALIGNMENT_CENTER, bw - 4, 13, UiTheme.on_silk(c))
	if banner != "" and banner_alpha > 0.0:
		var a := minf(1.0, banner_alpha * 3.0)
		draw_rect(Rect2(0, size.y / 2.0 - 28, size.x, 56), Color(0, 0, 0, 0.65 * a))
		draw_string(font, Vector2(0, size.y / 2.0 + 8), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(UiTheme.ACC, a))

func _draw_mini() -> void:
	var T: Dictionary = race.course
	if _cam.z <= full_scale() * 1.3 or T.straight: return
	var mw := minf(160.0, size.x * 0.3)
	var ms: float = mw / (T.S + 2.0 * (T.r + T.width))
	var mh: float = 2.0 * (T.r + T.width) * ms + 8.0
	var o := Vector2(size.x - mw - 12, size.y - mh - 12)
	var c := o + Vector2(mw, mh) / 2.0
	draw_rect(Rect2(o - Vector2(4, 4), Vector2(mw + 8, mh + 8)), Color(0.04, 0.06, 0.05, 0.75))
	var pts := PackedVector2Array()
	for p in _loops[T.width / 2.0]: pts.append(c + Vector2(p.x, -p.y) * ms)
	pts.append(pts[0])
	draw_polyline(pts, Color("3f8a49"), maxf(3.0, T.width * ms))
	var f := RaceEngine.xy(T.finish, T.width / 2.0)
	draw_rect(Rect2(c + Vector2(f.x, -f.y) * ms - Vector2(1, 4), Vector2(2, 8)), Color("ff4d4d"))
	for r in race.runners:
		if r.state == &"dnf": continue
		var p := RaceEngine.race_xy(race, r.dist, r.lane)
		draw_circle(c + Vector2(p.x, -p.y) * ms, 3.0 if r.i == sel else 2.0, Color(r.h.get("color", "#ffffff")))

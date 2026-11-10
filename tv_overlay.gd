class_name TvOverlay
extends Control
## JRA-style TV graphics, from the 2026 Takarazuka Kinen broadcast:
##  • top-left: race clock in big outlined figures (whole seconds, "m.ss" after a minute, tenths at the finish),
##    the leader's 1000 m split flashes in yellow
##  • bottom-left: 2.5D course map (tilted, with depth) and a red dot for the leader, surface + distance,
##    the gradient under the leader (%) and his speed (km/h)
##  • bottom-centre: the field as numbered balls in gate-bracket colours — spread by distance behind the leader and by
##    lane — with an arrow at the leader. The direction follows the camera: right-to-left when the field runs
##    right-to-left on screen, left-to-right otherwise. Distance poles appear as they come up ("600m").
##  • bottom-right: the first three with their win odds, then the race name / course rotating, "— 阪神 Hanshin —"

var race: RaceEngine.Race
var cam: Camera3D
var tb: TrackBuilder
var title := ""
var band_offset := 120.0          # distance from the bottom of the screen to the bottom of the graphics band
var odds := {}                    # runner i -> win odds
var _map_pts: Array = []          # [outer PackedVector2Array, inner, rail] in map space
var _map_rect := Rect2()
var _xf_ex := Vector2.RIGHT
var _xf_ey := Vector2.DOWN
var _dir := -1.0                  # -1: field runs right-to-left on screen
var _lane_dir := 1.0
var _rot := 0.0
var _split_t := -1.0
var _split_txt := ""
var _font: Font
var _jp: SystemFont

const MAP_SIZE := Vector2(210, 92)
const TILT := 0.62
const BRACKET_TEXT := ["#111111", "#ffffff", "#ffffff", "#ffffff", "#111111", "#ffffff", "#ffffff", "#111111"]
const JP_COURSE := { "tokyo": "東京", "nakayama": "中山", "hanshin": "阪神", "kyoto": "京都", "niigata": "新潟", "chukyo": "中京",
	"sapporo": "札幌", "hakodate": "函館", "fukushima": "福島", "kokura": "小倉" }
const JP_RACE := { "takarazuka kinen": "宝塚記念", "tokyo yushun": "東京優駿", "japanese derby": "東京優駿", "japan cup": "ジャパンカップ",
	"arima kinen": "有馬記念", "tenno sho (spring)": "天皇賞（春）", "tenno sho (autumn)": "天皇賞（秋）", "tenno sho": "天皇賞",
	"satsuki sho": "皐月賞", "kikuka sho": "菊花賞", "yasuda kinen": "安田記念", "osaka hai": "大阪杯", "victoria mile": "ヴィクトリアマイル",
	"yushun himba": "優駿牝馬", "japanese oaks": "優駿牝馬", "oka sho": "桜花賞", "shuka sho": "秋華賞", "sprinters stakes": "スプリンターズS",
	"takamatsunomiya kinen": "高松宮記念", "mile championship": "マイルCS", "queen elizabeth ii cup": "エリザベス女王杯",
	"february stakes": "フェブラリーS", "champions cup": "チャンピオンズC", "nhk mile cup": "NHKマイルC", "hopeful stakes": "ホープフルS",
	"asahi hai futurity stakes": "朝日杯FS", "hanshin juvenile fillies": "阪神JF" }

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_jp = SystemFont.new()
	_jp.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Noto Sans JP"])

func setup(r: RaceEngine.Race, camera: Camera3D, builder: TrackBuilder, race_title: String) -> void:
	race = r; cam = camera; tb = builder; title = race_title
	_split_t = -1.0
	_build_map()
	if _map_layer != null: _map_layer.queue_redraw()
	_make_odds()

# ---------------- odds: from the runners' ratings, 20 % takeout like the JRA win pool ----------------
func _make_odds() -> void:
	odds = {}
	var q: Array = []
	var best := -INF
	for r in race.runners:
		var v := 60.0 + float(hash(int(r.h.get("id", r.i))) % 100) / 10.0
		if r.h.has("stats"): v = Career.rating(Game.view(r.h) if Game.mode == "career" else r.h)
		q.append(v); best = maxf(best, v)
	var w: Array = []
	var tot := 0.0
	var rng := RandomNumberGenerator.new(); rng.seed = int(race.opts.get("seed", 1)) * 31 + 7
	for k in q.size():
		var x := exp((float(q[k]) - best) / 3.2) * rng.randf_range(0.75, 1.3)   # the public is not a perfect judge
		w.append(x); tot += x
	for r in race.runners:
		var p: float = w[r.i] / tot
		odds[r.i] = float(r.h.odds) if r.h.has("odds") else clampf(snappedf(0.8 / p, 0.1), 1.1, 999.9)   # career races: the race card's odds

# ---------------- 2.5D map ----------------
func _build_map() -> void:
	RaceEngine.use_course(race.course.id)
	var T: Dictionary = race.course
	var W: float = T.width
	var end: float = T.S if T.straight else T.C
	# orient: home straight along the bottom, seen from the stands; a right-handed course runs right-to-left in the straight
	var f: Vector2 = RaceEngine.xy(T.finish + 2.0, W * 0.5) - RaceEngine.xy(T.finish - 2.0, W * 0.5)
	var n: Vector2 = RaceEngine.xy(T.finish, W + 10.0) - RaceEngine.xy(T.finish, W * 0.5)
	_xf_ey = n.normalized()
	_xf_ex = Vector2(-_xf_ey.y, _xf_ey.x)
	var want := -1.0 if String(T.get("dir", "R")) == "R" else 1.0
	if signf(f.dot(_xf_ex)) != want: _xf_ex = -_xf_ex
	var outer := PackedVector2Array(); var inner := PackedVector2Array(); var rail := PackedVector2Array()
	var s := 0.0
	while s <= end:
		outer.append(_m(RaceEngine.xy(s, W + 14.0))); inner.append(_m(RaceEngine.xy(s, -14.0))); rail.append(_m(RaceEngine.xy(s, W * 0.5)))
		s += 12.0
	# fit into MAP_SIZE
	var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for p in outer: mn = mn.min(p); mx = mx.max(p)
	_map_rect = Rect2(mn, mx - mn)
	_map_pts = [outer, inner, rail]

func _m(p: Vector2) -> Vector2:   # world -> tilted map space (before fitting)
	return Vector2(p.dot(_xf_ex), p.dot(_xf_ey) * TILT)

func _fit(p: Vector2, at: Vector2) -> Vector2:
	var sc := minf(MAP_SIZE.x / maxf(1.0, _map_rect.size.x), MAP_SIZE.y / maxf(1.0, _map_rect.size.y))
	return at + (p - _map_rect.position) * sc

## The course map is drawn once into its own layer (it never changes during a race); only the leader's dot is drawn
## every frame. Re-triangulating the map every frame meant hundreds of new GPU buffers per frame.
var _map_layer: Control
var _dot_layer: Control

func _ensure_map_layer() -> void:
	if _map_layer != null: return
	_map_layer = Control.new()
	_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_layer.size = MAP_SIZE + Vector2(0, 10)
	_map_layer.draw.connect(_draw_map_static)
	add_child(_map_layer)
	_dot_layer = Control.new()           # the leader's dot, above the map
	_dot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot_layer.draw.connect(_draw_dot)
	_map_layer.add_child(_dot_layer)

func _draw_map_static() -> void:
	if _map_pts.is_empty(): return
	var L := _map_layer
	var o := PackedVector2Array(); var i := PackedVector2Array(); var rl := PackedVector2Array()
	for p in _map_pts[0]: o.append(_fit(p, Vector2.ZERO))
	for p in _map_pts[1]: i.append(_fit(p, Vector2.ZERO))
	for p in _map_pts[2]: rl.append(_fit(p, Vector2.ZERO))
	var depth := Vector2(0, 7)
	# side wall (depth), then the top: dark rim, turf band, infield
	var dk := PackedVector2Array(); for p in o: dk.append(p + depth)
	_poly_on(L, dk, Color(0.10, 0.22, 0.08, 0.95))
	_poly_on(L, o, Color(0.28, 0.48, 0.18))
	var band := Color(0.72, 0.6, 0.42) if race.course.surface == "dirt" else Color(0.55, 0.78, 0.35)
	# the band as one strip of triangles
	var strip := PackedVector2Array(); var cols := PackedColorArray()
	for k in mini(o.size(), i.size()) - 1:
		for v in [o[k], o[k + 1], i[k + 1], o[k], i[k + 1], i[k]]: strip.append(v); cols.append(band)
	if not strip.is_empty(): RenderingServer.canvas_item_add_triangle_array(L.get_canvas_item(), PackedInt32Array(), strip, cols)
	_poly_on(L, i, Color(0.33, 0.55, 0.22))
	L.draw_polyline(rl, Color(1, 1, 1, 0.55), 1.2, true)
	L.draw_polyline(o, Color(0.92, 0.95, 0.85), 1.5, true)
	L.draw_polyline(i, Color(0.92, 0.95, 0.85), 1.5, true)
	RaceEngine.use_course(race.course.id)
	var fp := _fit(_m(RaceEngine.xy(race.course.finish, race.course.width + 4.0)), Vector2.ZERO)
	L.draw_line(fp, fp + Vector2(0, -9), Color.WHITE, 2.0)

func _poly_on(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3: return
	if Geometry2D.triangulate_polygon(pts).is_empty(): c.draw_polyline(pts, col, 3.0); return
	c.draw_colored_polygon(pts, col)

func _draw_map(at: Vector2) -> void:
	if _map_pts.is_empty(): return
	_ensure_map_layer()
	if _map_layer.position != at: _map_layer.position = at
	_dot_layer.queue_redraw()

func _draw_dot() -> void:
	RaceEngine.use_course(race.course.id)
	var L = _leader()
	var lp := _fit(_m(RaceEngine.race_xy(race, maxf(L.dist, -5.0), L.lane)), Vector2.ZERO)
	_dot_layer.draw_circle(lp + Vector2(0, 1.5), 5.5, Color(0, 0, 0, 0.4))
	_dot_layer.draw_circle(lp, 5.0, Color("ff3030"))
	_dot_layer.draw_arc(lp, 5.0, 0, TAU, 16, Color.WHITE, 1.4, true)

func _poly(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3: return
	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		draw_polyline(pts, c, 3.0); return
	draw_colored_polygon(pts, c)

func _ring(o: PackedVector2Array, i: PackedVector2Array, c: Color) -> void:
	for k in mini(o.size(), i.size()) - 1:
		draw_colored_polygon(PackedVector2Array([o[k], o[k + 1], i[k + 1], i[k]]), c)

# ---------------- helpers ----------------
func _leader():
	var L = race.runners[0]
	for r in race.runners:
		if r.state != &"dnf" and r.dist > L.dist: L = r
	return L

func _standings() -> Array:
	return RaceCommentary.standings(race)

func _txt(s: String, pos: Vector2, size: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, f: Font = null) -> void:
	var fn: Font = f if f != null else _font
	draw_string(fn, pos + Vector2(1.5, 1.5), s, align, w, size, Color(0, 0, 0, 0.55))
	draw_string(fn, pos, s, align, w, size, col)

func _outlined(s: String, pos: Vector2, size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _ball(c: Vector2, n: int, rad: float) -> void:
	var b := Silks.bracket(n, race.runners.size())
	var col := Color(Silks.CAPS[b - 1])
	draw_circle(c + Vector2(0.8, 1.2), rad, Color(0, 0, 0, 0.45))
	draw_circle(c, rad, col)
	draw_arc(c, rad, 0, TAU, 20, Color(1, 1, 1, 0.9) if b != 1 else Color(0.2, 0.2, 0.2), 1.3, true)
	var s := str(n)
	var fs := int(rad * 1.25)
	var sz := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, c + Vector2(-sz.x / 2.0, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(BRACKET_TEXT[b - 1]))

func _num_box(at: Vector2, n: int, h: float) -> void:
	var b := Silks.bracket(n, race.runners.size())
	draw_rect(Rect2(at, Vector2(h * 1.15, h)), Color(Silks.CAPS[b - 1]))
	if b == 1: draw_rect(Rect2(at, Vector2(h * 1.15, h)), Color(0.3, 0.3, 0.3), false, 1.0)
	var s := str(n); var fs := int(h * 0.78)
	var sz := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, at + Vector2((h * 1.15 - sz.x) / 2.0, h * 0.8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(BRACKET_TEXT[b - 1]))

## the runner's silks as worn today: catalogue jacket + cap layer (JRA bracket cap in Japan), or generated silks
func _silk_icon(at: Vector2, h: Dictionary, sz: float) -> void:
	var tex := JockeyLook.ui_icon(String(h.get("silkId", "")), h.get("silks", Silks.default_for(String(h.get("color", "#cccccc")))), int(h.get("bracket", 0)))
	if tex == null: return
	var asp := float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	var w := sz * 1.25
	draw_texture_rect(tex, Rect2(at + Vector2(-(w - sz) * 0.5, (sz - w / asp) * 0.5), Vector2(w, w / asp)), false)

# ---------------- per frame ----------------
func _process(delta: float) -> void:
	if race == null or not visible: return
	_rot += delta
	# screen direction of travel and of the outside lanes, from the camera that is on air
	if cam != null and tb != null:
		var L = _leader()
		var d := maxf(L.dist, 0.0)
		var a := tb.race3(d, L.lane, 1.0)
		if not cam.is_position_behind(a):
			var p0 := cam.unproject_position(a)
			var p1 := cam.unproject_position(tb.race3(d + 8.0, L.lane, 1.0))
			if absf(p1.x - p0.x) > 2.0: _dir = signf(p1.x - p0.x)
			var p2 := cam.unproject_position(tb.race3(d, L.lane + 8.0, 1.0))
			if absf(p2.y - p0.y) > 1.0: _lane_dir = signf(p2.y - p0.y)
	# 1000 m split flash
	if race.lead.has(1000) and _split_t < 0.0 and race.opts.dist > 1200:
		_split_t = 0.0; _split_txt = _fmt(float(race.lead[1000]), true)
	if _split_t >= 0.0: _split_t += delta
	queue_redraw()

func _fmt(t: float, tenths: bool) -> String:
	if t < 60.0 and not tenths: return str(int(t))
	var m := int(t / 60.0); var s := t - m * 60.0
	if tenths: return "%d.%02d.%d" % [m, int(s), int(fposmod(s * 10.0, 10.0))] if m > 0 else "%d.%d" % [int(s), int(fposmod(s * 10.0, 10.0))]
	return "%d.%02d" % [m, int(s)]

func _draw() -> void:
	if race == null: return
	var W := size.x
	var y1 := size.y - band_offset          # bottom of the band
	var y0 := y1 - 140.0
	# dark gradient behind the band
	var gh := y1 - y0 + 30.0
	for k in 24:
		var t := float(k) / 23.0
		draw_rect(Rect2(0, y0 - 24 + gh * t, W, gh / 23.0 + 1.0), Color(0.02, 0.05, 0.02, 0.62 * t * t))
	# clock
	var clk := RaceEngine.race_clock(race)
	var fin := not race.order.is_empty()
	var ct := ""
	if race.clock0 >= 0.0:
		ct = _fmt(float(race.lead[race.opts.dist]) if fin and race.lead.has(race.opts.dist) else clk, fin)
	var flash := _split_t >= 0.0 and _split_t < 4.0 and not fin
	if ct != "" and not flash: _outlined(ct, Vector2(46, 70), 46, Color.WHITE)
	if flash:
		_outlined(_split_txt, Vector2(46, 70), 46, Color("ffe14a"))
		for k in 7: draw_rect(Rect2(48 + k * 11, 80, 7, 3), Color("ffe14a"))
	# 2.5D map + course, gradient, speed
	_draw_map(Vector2(30, y0 - 6))
	var surf := "TURF" if race.course.surface != "dirt" else "DIRT"
	_txt("%s %s" % [surf, _thousands(race.opts.dist) + "m"], Vector2(110, y0 + 100), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 140)
	var wc := String(race.opts.get("weather", ""))
	if wc != "": _txt(String(Weather.SHORT.get(wc, "")), Vector2(30, y0 + 100), 15, Color(0.9, 0.95, 0.9))
	var L = _leader()
	RaceEngine.use_course(race.course.id)
	var gr := 0
	if race.clock0 >= 0.0: gr = roundi(RaceEngine.grade(RaceEngine.wrap_s(race.startS + maxf(L.dist, 0.0)) if not race.course.straight else race.startS + L.dist) * 100.0)
	var kmh := "--.-" if race.clock0 < 0.0 else "%.1f" % (L.v * 3.6)
	draw_line(Vector2(30, y0 + 108), Vector2(250, y0 + 108), Color(1, 1, 1, 0.5), 1.0)
	_txt("▲ %s%d%%" % ["+" if gr > 0 else "", gr], Vector2(30, y0 + 134), 20, Color(0.92, 0.96, 0.9))

	_txt("◷ %s km/h" % kmh, Vector2(112, y0 + 134), 24)
	# positions
	_draw_balls(Rect2(280, y0 + 16, W - 280 - 500, 110))
	# first three + odds
	var st := _standings()
	var x3 := W - 470.0
	for k in mini(3, st.size()):
		var r = st[k]
		var yy := y0 + 22 + k * 38
		_num_box(Vector2(x3, yy), r.i + 1, 30)
		_silk_icon(Vector2(x3 + 44, yy), r.h, 30)
		_txt("%.1f" % float(odds.get(r.i, 0.0)), Vector2(x3 + 80, yy + 25), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 90)
	# race name / course
	var xr := W - 230.0
	_txt("◈ HRS TV", Vector2(xr, y0 + 44), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 200)
	var rn := String(Settings.get_v("race_names"))
	var jr: String = JP_RACE.get(title.to_lower().strip_edges(), "")
	var names: Array = [] if (rn == "jp" and jr != "") else [title.to_upper()]
	if jr != "" and rn != "en": names.append(jr)
	var gr_s := String(race.opts.get("grade", ""))
	if gr_s != "": names.append(gr_s)
	var nm: String = names[int(_rot / 4.0) % names.size()]
	_txt(nm, Vector2(xr, y0 + 86), 24 if nm.length() < 18 else 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 200, _jp if nm == jr else null)
	var cid := String(race.course.id).trim_suffix("_d")
	var en := String(race.course.get("short", cid)).split(" ")[0]
	var jp: String = JP_COURSE.get(cid, "")
	_txt("—  %s %s  —" % [jp, en], Vector2(xr, y0 + 122), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 200, _jp)

func _thousands(n: int) -> String:
	return "%d,%03d" % [n / 1000, n % 1000] if n >= 1000 else str(n)

func _draw_balls(box: Rect2) -> void:
	var L = _leader()
	var ds: Array = []
	for r in race.runners:
		if r.state != &"dnf": ds.append(L.dist - r.dist)
	ds.sort()
	var span: float = clampf(float(ds[ds.size() - 1]) + 6.0, 40.0, 400.0)
	var ppm := (box.size.x - 40.0) / span
	var r0 := 13.0
	# the leader sits at the front edge in the direction of travel, with the arrow ahead of him
	var front_x := box.position.x + 26.0 if _dir < 0.0 else box.end.x - 26.0
	var ay := box.position.y + box.size.y * 0.5
	var tip := front_x + (-22.0 if _dir < 0.0 else 22.0)
	draw_polyline(PackedVector2Array([Vector2(tip - _dir * 8.0, ay - 9), Vector2(tip, ay), Vector2(tip - _dir * 8.0, ay + 9)]), Color.WHITE, 2.0, true)
	# distance poles coming up (every 200 m from home), like "600m"
	var togo: float = race.opts.dist - L.dist
	for m in [1000, 800, 600, 400, 200]:
		var back_m: float = togo - m       # >0: pole still ahead of the leader
		if back_m < 0.0 and -back_m < span:
			var x := front_x - _dir * (-back_m) * ppm
			draw_line(Vector2(x, box.position.y + 4), Vector2(x, box.end.y - 4), Color(1, 1, 1, 0.35), 1.0)
			draw_set_transform(Vector2(x - 4, box.end.y - 6), -PI / 2.0)
			draw_string(_font, Vector2.ZERO, "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
			draw_set_transform(Vector2.ZERO)
	# balls: back to front so the leaders are on top
	var rs: Array = race.runners.duplicate()
	rs.sort_custom(func(a, b): return a.dist < b.dist)
	for r in rs:
		if r.state == &"dnf": continue
		var back: float = L.dist - r.dist
		var x := front_x - _dir * back * ppm
		var ly := clampf(r.lane / 10.0, 0.0, 1.0) - 0.5     # most of the field runs within ~10 m of the rail
		var y := box.position.y + box.size.y * 0.5 + _lane_dir * ly * (box.size.y - 2.0 * r0)
		_ball(Vector2(x, clampf(y, box.position.y + r0, box.end.y - r0)), r.i + 1, r0)

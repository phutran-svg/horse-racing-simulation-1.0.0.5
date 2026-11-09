class_name CameraDirector
extends Camera3D
## TV-style race cameras, modelled on the JRA feed of the 2026 Tokyo Yushun:
## gate close-up -> high wide shot of the break -> tight high tracking of the leaders -> infield shot past the stands ->
## back straight split screen (whole field strip on top, telephoto rail close-up below) -> turn from the inside rail ->
## high homestretch shot -> head-on -> finish line -> pull-up from behind.
## (older summary: AUTO cuts between them like a broadcast:
## gates -> side-on tracking -> blimp on the bends -> high homestretch view (JRA style) -> head-on -> side-on for the finish -> finish line.

enum Mode { AUTO, SIDE, HEAD_ON, BLIMP, FOLLOW, GATE, FINISH, STRETCH, START, TELE, TURN, PULLUP }
const NAMES := ["Auto (TV)", "Side-on", "Head-on", "Blimp", "Follow", "Gates", "Finish line", "Homestretch", "Start (high)", "Rail close-up", "Turn", "Pull-up"]

var mode := Mode.AUTO
var shot := Mode.GATE              # what AUTO is showing now
var race: RaceEngine.Race
var tb: TrackBuilder
var horses: Array = []             # Horse3D per runner (index = runner i)
var sel := 0
var side := 0                       # side-on camera: 0 auto, 1 outside, 2 inside
var _hold := 0.0
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _fov := 40.0
var _cut := true
var _finish_t := -1.0
var split := false                  # back-straight split screen: race_3d shows split_pose() in a strip on top
var split_pose := [Vector3.ZERO, Vector3.ZERO, 30.0]

func reset(r: RaceEngine.Race, builder: TrackBuilder, hs: Array) -> void:
	race = r; tb = builder; horses = hs
	shot = Mode.GATE; _hold = 0.0; _cut = true; _finish_t = -1.0
	near = 0.3; far = 6000.0

func set_mode(m: int) -> void:
	mode = m as Mode
	_cut = true

func _leader():
	var L = null
	for r in race.runners:
		if r.state != &"dnf" and (L == null or r.dist > L.dist): L = r
	return L if L != null else race.runners[0]

func _pack_d() -> float:
	# centre of the leading group: average of the first few
	var ds: Array = []
	for r in race.runners:
		if r.state != &"dnf": ds.append(r.dist)
	ds.sort(); ds.reverse()
	var n := mini(5, ds.size())
	var t := 0.0
	for k in n: t += ds[k]
	return t / maxf(1.0, n)

func _in_home_straight(d: float) -> bool:
	var T: Dictionary = race.course
	var rem: float = race.opts.dist - d
	if T.straight: return true
	var s := RaceEngine.wrap_s(race.startS + d)
	return s < T.finish + 1.0 and rem <= T.finish + 1.0 and not RaceEngine.race_on_spur(race, d)

## is race distance d alongside the grandstand (outside cameras there would be inside the stand)?
func _by_stand(d: float) -> bool:
	var T: Dictionary = race.course
	if RaceEngine.race_on_spur(race, d) and not T.straight: return false
	var s := RaceEngine.wrap_s(race.startS + d) if not T.straight else race.startS + d
	return s > T.finish - 340.0 and s < T.finish + 90.0

## outside offset if clear of the stand, else the infield side
func _out(d: float, W: float, dist_out: float, dist_in: float) -> float:
	return -dist_in if _by_stand(d) else W + dist_out

func _turn_ahead(L) -> bool:
	# the final turn: on a bend now or within 80 m, and the straight still to come
	var D: int = race.opts.dist
	var rem: float = D - L.dist
	return rem < race.course.finish + 450.0 and (RaceEngine.race_curve(race, L.dist) or RaceEngine.race_curve(race, L.dist + 80.0)) and not _in_home_straight(L.dist)

func _auto_pick() -> int:
	var L = _leader()
	var D: int = race.opts.dist
	var rem: float = D - L.dist
	if race.t < 3.0: return Mode.GATE
	if race.t < 9.0: return Mode.START
	if not race.order.is_empty():
		if _finish_t < 0.0: _finish_t = race.t
		return Mode.FINISH if race.t - _finish_t < 4.0 else Mode.PULLUP
	if rem < 140.0: return Mode.SIDE
	if _in_home_straight(L.dist): return Mode.STRETCH if rem > 330.0 else Mode.HEAD_ON
	if _turn_ahead(L): return Mode.TURN
	if race.t < 16.0: return Mode.TELE
	if RaceEngine.race_curve(race, L.dist) or RaceEngine.race_curve(race, L.dist + 60.0): return Mode.BLIMP
	return Mode.SIDE

func update_cam(dt: float) -> void:
	if race == null: return
	RaceEngine.use_course(race.course.id)
	var want := mode
	if mode == Mode.AUTO:
		_hold -= dt
		var p := _auto_pick()
		if p != shot and (_hold <= 0.0 or p == Mode.FINISH or p == Mode.GATE):
			shot = p as Mode; _hold = 4.0; _cut = true
		want = shot
	split = false
	var W: float = race.course.width
	var L = _leader()
	var pd := _pack_d()
	var pos := Vector3.ZERO
	var look := Vector3.ZERO
	var fov := 30.0
	match want:
		Mode.SIDE:
			if mode == Mode.AUTO and race.t > 20.0:
				# back straight: telephoto close-up below, whole-field strip on top (video 39–84 s)
				split = true
				var lastd: float = pd
				for r in race.runners:
					if r.state != &"dnf": lastd = minf(lastd, r.dist)
				var md: float = (L.dist + lastd) * 0.5
				var spr: float = maxf(L.dist - lastd, 20.0)
				var sp_inside := _in_home_straight(md)
				var sp_pos := tb.race3(md, -110.0 if (sp_inside or _by_stand(md)) else W + 110.0, 30.0)
				var sp_look := tb.race3(md, W * 0.4, 1.0)
				split_pose = [sp_pos, sp_look, clampf(rad_to_deg(2.0 * atan(spr * 0.6 / 110.0)) * 0.3, 3.0, 30.0)]
			var d := pd - 4.0
			# auto: outside, except in the home straight where the grandstand is (film from the infield there)
			var inside := side == 2 or (side == 0 and (_in_home_straight(d) or _by_stand(d)))
			if inside:
				pos = tb.race3(d + 6.0, -40.0, 9.0)
				look = tb.race3(d - 2.0, W * 0.55, 1.0)
			else:
				pos = tb.race3(d + 6.0, W + 38.0, 9.0)
				look = tb.race3(d - 2.0, W * 0.4, 1.0)
			fov = 34.0
			if split:   # the close-up half: tight on the leading group through the rail
				pos = tb.race3(pd - 1.0, -24.0 if inside else W + 24.0, 3.0)
				look = tb.race3(pd - 3.0, W * 0.35, 1.3)
				fov = 15.0
		Mode.HEAD_ON:
			var T: Dictionary = race.course
			var Lpos: Vector3 = horses[L.i].global_position
			if _in_home_straight(L.dist):
				pos = tb.loop3(T.finish + 90.0 if not T.straight else T.finish + 60.0, W * 0.5, 6.0)
			else:
				pos = tb.race3(L.dist + 140.0, W * 0.5, 6.0)
			look = Lpos + Vector3(0, 0.6, 0)
			fov = clampf(rad_to_deg(2.0 * atan(16.0 / maxf(10.0, pos.distance_to(look)))), 5.0, 45.0)
		Mode.BLIMP:
			var c := tb.race3(pd - 8.0, W * 0.5, 0.0)
			var outw: Vector3 = tb.race3(pd - 8.0, W + 1.0, 0.0) - tb.race3(pd - 8.0, 0.0, 0.0)
			outw.y = 0.0
			pos = c + outw.normalized() * 45.0 + Vector3(0, 95.0, 0)
			look = c
			fov = 30.0
		Mode.STRETCH:
			# JRA homestretch shot: high on the stand side, ahead of the field, looking back at the leading group.
			# The pack fills most of the frame (video: 120–141 s).
			var ds: Array = []
			for r in race.runners:
				if r.state != &"dnf": ds.append(r.dist)
			ds.sort(); ds.reverse()
			var k0 := 0
			while k0 < 3 and k0 + 1 < ds.size() and ds[k0] - ds[k0 + 1] > 15.0: k0 += 1   # a runaway leader leaves the frame, like on TV
			var front: float = ds[k0]
			var back: float = maxf(ds[mini(k0 + 6, ds.size() - 1)], front - 22.0)
			var mid: float = (front + back) * 0.5
			var spread: float = maxf(front - back, 10.0)
			pos = tb.race3(front + 20.0 + spread * 0.25, W + 12.0, 14.0)
			look = tb.race3(mid + 1.0, W * 0.35, 0.8)
			fov = clampf(rad_to_deg(2.0 * atan((spread * 0.3 + 4.0) / maxf(15.0, pos.distance_to(look)))), 9.0, 45.0)
		Mode.START:
			# high wide shot from the stand side as the gates open (video 3–9 s), panning with the field
			var dd: float = maxf(pd, 0.0)
			pos = tb.race3(dd + 25.0, _out(dd, W, 60.0, 45.0), 26.0)
			look = tb.race3(dd + 4.0, W * 0.45, 1.0)
			fov = 34.0
		Mode.TELE:
			# telephoto through the outside rail, low, tracking the leaders tight (video 12–24 s, 42–84 s)
			var d2: float = pd - 2.0
			pos = tb.race3(d2 + 2.0, _out(d2, W, 24.0, 24.0), 3.4)
			look = tb.race3(d2 - 2.0, W * 0.35, 1.3)
			fov = 22.0
		Mode.TURN:
			# from the inside rail at the end of the final turn, the field swinging round towards the camera (video 111–117 s)
			var Lp: Vector3 = horses[L.i].global_position
			var exit_d: float = L.dist
			while exit_d < L.dist + 600.0 and (RaceEngine.race_curve(race, exit_d) or not _in_home_straight(exit_d)): exit_d += 10.0
			pos = tb.race3(minf(exit_d + 30.0, L.dist + 75.0), -3.0, 2.6)
			look = Lp + Vector3(0, 0.8, 0)
			fov = clampf(rad_to_deg(2.0 * atan(14.0 / maxf(10.0, pos.distance_to(look)))), 8.0, 48.0)
		Mode.PULLUP:
			# after the line: high behind the winner as the runners ease down (video 159–162 s)
			var hp: Vector3 = horses[L.i].global_position
			var fw: Vector3 = horses[L.i].global_transform.basis.z   # horses face +Z
			fw.y = 0.0; fw = fw.normalized()
			pos = hp - fw * 32.0 + Vector3(0, 13.0, 0)
			look = hp + fw * 10.0
			fov = 34.0
		Mode.FOLLOW:
			var r = race.runners[sel]
			pos = tb.race3(r.dist - 13.0, r.lane + 2.0, 4.2)
			look = tb.race3(r.dist + 8.0, r.lane, 1.4)
			fov = 50.0
		Mode.GATE:
			# in front of the stalls; from the infield side when the start is in front of the stand (crowd on the apron)
			pos = tb.race3(28.0, -9.0 if _by_stand(28.0) or _by_stand(0.0) else W + 9.0, 3.6)
			look = tb.race3(-RaceEngine.CAL.GATE, W * 0.35, 1.2)
			fov = 42.0
		Mode.FINISH:
			var T2: Dictionary = race.course
			pos = tb.loop3(T2.finish, W + 22.0, 5.5)
			look = tb.loop3(T2.finish, W * 0.4, 1.0)
			fov = 38.0
	if _cut or dt <= 0.0:
		_pos = pos; _look = look; _fov = fov; _cut = false
	else:
		var k := 1.0 - exp(-dt * (2.5 if want == Mode.HEAD_ON or want == Mode.TURN else 4.0))
		_pos = _pos.lerp(pos, k); _look = _look.lerp(look, minf(1.0, k * 1.6)); _fov = lerpf(_fov, fov, k)
	global_position = _pos
	if _pos.distance_to(_look) > 0.01: look_at(_look, Vector3.UP)
	self.fov = _fov
	for h in horses: h.number_label.visible = want == Mode.BLIMP

func current_name() -> String:
	var n: String = NAMES[mode] + ("" if mode != Mode.AUTO else " · " + NAMES[shot])
	return n + (" (%s)" % ["auto side", "outside", "inside"][side] if (mode == Mode.SIDE or (mode == Mode.AUTO and shot == Mode.SIDE)) else "")

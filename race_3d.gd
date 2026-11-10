extends Node3D
## 3D race. Quick Race: uses AppState (course, field, seed). Career: plays the stored race from Game.pending_replay
## (same seed + same horses = the same race as the career result).
## Keys: Space start/pause · 1 Auto TV · 2 Side-on · 3 Head-on · 4 Blimp · 5 Follow · 6 Gates · 7 Finish · 8 Paddock · 9 Homestretch · 0 Rail close-up · T Turn
##       S side-on: auto / outside / inside · R restart · Esc back

const SPEEDS := [0.5, 1.0, 2.0, 4.0]

var race: RaceEngine.Race
var tb: TrackBuilder
var cam: CameraDirector
var comm := RaceCommentary.new()
var horses: Array = []
var prev_d := PackedFloat64Array()
var prev_l := PackedFloat64Array()
var running := false
var speed := 1.0
var acc := 0.0
var sel := 0
var gates_open := false
var _hud_t := 0.0
var _results_shown := false
var course_node: Node3D
var horse_root: Node3D
var field: Array = []
var opts: Dictionary = {}
var title := ""
var career := false
var queue: Array = []

# HUD
var hud: Control
var tvg: TvOverlay
var tv_on := true
var _panels: Array = []     # classic HUD panels hidden while the TV graphics are on
var _bottom: Control
var clock_lbl: Label
var info_lbl: Label
var cam_lbl: Label
var comm_lbl: Label
var play_btn: Button
var next_btn: Button
var side_btn: Button
var results: PanelContainer
var results_txt: RichTextLabel
var loading: Label
var board: StandingsBoard
var minimap: RaceView

func _ready() -> void:
	UiTheme.set_dark(true)
	get_tree().root.content_scale_size = Vector2i(1600, 900)
	_build_environment()
	cam = CameraDirector.new()
	add_child(cam)
	cam.current = true
	_build_hud()
	comm.line.connect(func(_c, t, _i): comm_lbl.text = "🎙 " + t)
	career = Game.mode == "career" and Game.pending_replay.has("queue")
	paddock_mode = Game.mode == "career" and Game.pending_replay.has("paddock")
	if career: queue = Game.pending_replay.queue.duplicate()
	elif AppState.field.is_empty(): AppState.build_field("rand")
	await get_tree().process_frame
	await get_tree().process_frame
	_load_next()

var _loading_next := false

## a stored replay record we can build a race from, or {} (missing record, missing/odd opts or field, unknown course)
static func _valid_replay(rp) -> Dictionary:
	if not (rp is Dictionary): return {}
	var o = rp.get("opts")
	var f = rp.get("field")
	if not (o is Dictionary) or not (f is Array) or f.size() < 2: return {}
	if not RaceEngine.COURSES.has(o.get("course", "")) or int(o.get("dist", 0)) <= 0: return {}
	for h in f:
		if not (h is Dictionary) or not h.has("stats"): return {}
	return rp

func _unavailable(msg: String) -> void:
	loading.text = msg + "\nPress Back to return."
	loading.visible = true
	play_btn.disabled = true
	next_btn.visible = false
	for b in race_btns + race_extra:
		if b is BaseButton: b.disabled = true
	running = false; paused = false

func _next_pressed() -> void:
	if _loading_next or queue.is_empty(): return
	_loading_next = true
	next_btn.disabled = true
	await _load_next()
	_loading_next = false
	next_btn.disabled = false

func _load_next() -> void:
	if paddock_mode:
		var pd: Dictionary = Game.pending_replay.paddock
		opts = pd.opts.duplicate(true)
		field = []
		for k in pd.field.size():
			var h: Dictionary = pd.field[k].duplicate(true)
			h["color"] = Silks.main_hex(Career.W) if Career.W.stable.has(int(h.id)) else UiTheme.SILKS[(k + 2) % UiTheme.SILKS.size()]
			field.append(h)
		title = pd.name
		next_btn.visible = false
		await new_race()
		return
	if career:
		# take the next replay that can actually be played; skip missing or damaged records
		var rp := {}
		while not queue.is_empty() and rp.is_empty():
			var id_v = queue.pop_front()
			rp = _valid_replay(Career.replay_of(int(id_v)) if (id_v is int or id_v is float) else null)
		if rp.is_empty():
			_unavailable("This replay is no longer available.")
			return
		opts = rp.opts.duplicate(true)
		field = []
		for k in rp.field.size():
			var h: Dictionary = rp.field[k].duplicate(true)
			h["color"] = Silks.main_hex(Career.W) if Career.W.stable.has(int(h.get("id", -1))) else UiTheme.SILKS[(k + 2) % UiTheme.SILKS.size()]
			field.append(h)
		title = String(rp.get("name", "Replay"))
		for k in field.size():
			if Career.W.stable.has(int(field[k].get("id", -1))): sel = k
		if sel < 0 or sel >= field.size(): sel = 0
	else:
		field = AppState.field
		opts = AppState.race_opts()
		title = "Quick race"
	next_btn.visible = career and not queue.is_empty()
	await new_race()

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.42, 0.78)
	sm.sky_horizon_color = Color(0.66, 0.76, 0.86)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.55, 0.6, 0.55)
	sm.ground_bottom_color = Color(0.25, 0.3, 0.25)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.ambient_light_color = Color(0.82, 0.82, 0.8)
	env.ambient_light_sky_contribution = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.76, 0.86)
	env.fog_density = 0.00035
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	world_env = env
	Settings.apply_3d(get_viewport(), env)
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.35
	sun.shadow_enabled = bool(Settings.get_v("shadows"))
	sun.directional_shadow_max_distance = 320.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


# ---------------- paddock ----------------
var paddock_root: Node3D
var paddock_horses: Array = []
var paddock_cam := false
var _pk_ang := 0.0
var paddock_mode := false          # opened from a race card: the runners in the paddock before the race, no race
var pk_sel := 0
var _pk_t := 0.0
var pk_prev: Button
var pk_next: Button
var race_btns: Array = []
var race_extra: Array = []
const CAM_KEYS := [CameraDirector.Mode.AUTO, CameraDirector.Mode.TURN, CameraDirector.Mode.HEAD_ON, CameraDirector.Mode.BLIMP, CameraDirector.Mode.FOLLOW]
const PK_SHOW := 7.0               # seconds on each horse before the paddock camera moves to the next one

func _pk_pick(d: int) -> void:
	if paddock_horses.is_empty(): return
	pk_sel = posmod(pk_sel + d, paddock_horses.size())
	_pk_t = 0.0
	_pk_caption()

func _pk_caption() -> void:
	if race == null or pk_sel >= race.runners.size(): return
	var h: Dictionary = race.runners[pk_sel].h
	var bwd = h.get("bwd")
	var bw := ""
	if h.has("bwDay"): bw = " · %d kg (%s)" % [int(h.bwDay), ("+%d" % int(bwd) if int(bwd) > 0 else str(int(bwd))) if bwd != null else ("first run" if int(h.get("starts", 0)) == 0 else "–")]
	var od := " · odds %.1f (%s fav)" % [float(h.odds), _ord(int(h.get("fav", 0)))] if h.has("odds") else ""
	comm_lbl.text = "🐎 Paddock · %s — No.%d %s · %d%s%s%s" % [title, pk_sel + 1, h.name, int(h.get("age", 0)), "F" if h.get("sex", "") == "F" else "", bw, od]

static func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]: return "%dth" % n
	return "%d%s" % [n, ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]]

func _spawn_paddock() -> void:
	if paddock_root != null: paddock_root.queue_free()
	paddock_horses = []
	paddock_root = null
	if tb.paddock == null: return
	paddock_root = Node3D.new()
	add_child(paddock_root)
	var n: int = race.runners.size()
	for r in race.runners:
		var ph := PaddockHorse.new()
		paddock_root.add_child(ph)
		ph.setup(r.h, r.i + 1, UiTheme.silk(r.i), 1.0 - float(r.i) / n)      # in number order, spaced evenly round the ring
		ph.walk(0.0, tb.paddock)
		paddock_horses.append(ph)

func _update_paddock(delta: float) -> void:
	if paddock_root == null: return
	paddock_root.visible = not running and race.t <= 0.0          # the field leaves the paddock for the start
	if not paddock_root.visible: return
	for ph in paddock_horses: ph.walk(delta, tb.paddock)
	if paddock_mode and not paddock_horses.is_empty():
		_pk_t += delta
		if _pk_t > PK_SHOW: _pk_pick(1)
		var ph: Node3D = paddock_horses[pk_sel]
		var fw: Vector3 = ph.global_transform.basis.z; fw.y = 0.0; fw = fw.normalized()
		var side := fw.cross(Vector3.UP).normalized()
		var want := ph.global_position + side * 7.5 + fw * 3.0 + Vector3(0, 2.4, 0)
		var k := 1.0 - exp(-delta * 2.5)
		cam.global_position = want if _pk_t < 0.05 else cam.global_position.lerp(want, k)
		cam.look_at(ph.global_position + Vector3(0, 1.3, 0) + fw * 0.4, Vector3.UP)
		cam.fov = 40.0
	elif paddock_cam:
		_pk_ang += delta * 0.05
		var c := tb.paddock.global_transform * Vector3(cos(_pk_ang) * 34.0, 13.0, sin(_pk_ang) * 26.0)
		cam.global_position = c
		cam.look_at(tb.paddock.global_transform * Vector3(0, 1.0, 0), Vector3.UP)


# ---------------- Turf Vision live picture ----------------
var tv_vp: SubViewport
var tv_cam: Camera3D

func _setup_screen() -> void:
	if tv_vp != null: tv_vp.queue_free(); tv_vp = null
	if tb.screen_mat == null: return
	tv_vp = SubViewport.new()
	tv_vp.size = Vector2i(672, 120)
	tv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tv_cam = Camera3D.new()
	tv_cam.fov = 30.0
	tv_cam.far = 900.0
	tv_vp.add_child(tv_cam)
	add_child(tv_vp)
	tb.screen_mat.albedo_texture = tv_vp.get_texture()
	tb.screen_mat.albedo_color = Color(1.1, 1.1, 1.1)

## broadcast-style side view of the leaders on the big screen
var split_vp: SubViewport
var split_box: SubViewportContainer
var split_cam: Camera3D

func _update_split() -> void:
	if split_box == null:
		split_box = SubViewportContainer.new()
		split_box.stretch = true
		split_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		split_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
		split_box.offset_bottom = 200
		split_vp = SubViewport.new()
		split_vp.world_3d = get_viewport().world_3d
		split_cam = Camera3D.new(); split_cam.far = 3000.0
		split_vp.add_child(split_cam)
		split_box.add_child(split_vp)
		hud.add_child(split_box); hud.move_child(split_box, 0)
	split_box.visible = cam.split and not paddock_mode
	if not split_box.visible: return
	var sp: Array = cam.split_pose
	split_cam.global_position = sp[0]
	split_cam.look_at(sp[1], Vector3.UP)
	split_cam.fov = sp[2]

func _update_screen() -> void:
	if tv_cam == null: return
	var best = race.runners[0]
	for r in race.runners:
		if r.dist > best.dist: best = r
	var d: float = best.dist
	var p := tb.race3(d + 2.0, best.lane + 2.0, 1.2)
	var outw := tb.race3(d - 6.0, race.course.width + 9.0, 5.5)
	tv_cam.global_position = outw
	tv_cam.look_at(p, Vector3.UP)


# ---------------- crowd + sound ----------------
var snd := {}

func _setup_sound() -> void:
	if snd.is_empty():
		for k in ["fanfare_g1", "fanfare_short", "gate_open", "crowd_cheer"]:
			var ap := AudioStreamPlayer.new()
			var st = load("res://assets/sound/%s.mp3" % k)
			if st == null: continue
			if k == "crowd_cheer": st.loop = true
			ap.stream = st
			add_child(ap)
			snd[k] = ap
	for k in snd: snd[k].stop()
	var big: bool = String(opts.get("cls", "")) in ["G1", "G2"]
	var f: String = "fanfare_g1" if big else "fanfare_short"
	if snd.has(f):
		snd[f].volume_db = Settings.fx_db(-4.0)
		snd[f].play()
	if snd.has("crowd_cheer"):
		snd.crowd_cheer.volume_db = Settings.fx_db(-26.0, true)
		snd.crowd_cheer.play()

## crowd noise and movement follow the race: murmur early, building from 600 m out, roar at the line
func _update_crowd(delta: float) -> void:
	var L = race.runners[0]
	for r in race.runners:
		if r.dist > L.dist: L = r
	var togo: float = float(race.opts.dist) - L.dist
	var e := 0.08
	if race.t > 0.0 and race.t < 4.0: e = 0.35
	if togo < 600.0: e = lerpf(0.25, 1.0, clampf((600.0 - togo) / 600.0, 0.0, 1.0))
	if race.done: e = maxf(0.0, 1.0 - _after_finish * 0.08)
	if race.done: _after_finish += delta
	tb.set_excite(e)
	_crowd_clock += delta
	tb.set_clock(_crowd_clock)
	if snd.has("crowd_cheer"):
		var target := Settings.fx_db(lerpf(-26.0, -2.0, e), true)
		snd.crowd_cheer.volume_db = lerpf(snd.crowd_cheer.volume_db, target, clampf(delta * 1.5, 0.0, 1.0))
var _after_finish := 0.0
var _crowd_clock := 0.0
var world_env: Environment
var sun_light: DirectionalLight3D
var wx: WeatherFX


# ---------------- race ----------------
func new_race() -> void:
	if paused: _set_paused(false)
	loading.visible = true
	loading.text = "Building %s…" % RaceEngine.COURSES[opts.course].name
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuild: bool = race == null or race.course.id != opts.course or race.opts.dist != int(opts.dist) or race.runners.size() != field.size()
	race = RaceEngine.create_race(field, opts)
	HorseLook.warm_up()          # starts the horse textures loading in the background while the course is built
	if rebuild:
		if course_node != null: course_node.queue_free()
		tb = TrackBuilder.new()
		course_node = tb.build(self, race)
	else:
		tb.race = race
		for d in tb.gate_doors: d.visible = true
		tb.remove_gates(false)
	if horse_root != null: horse_root.queue_free()
	horse_root = Node3D.new()
	add_child(horse_root)
	horses = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(race.opts.seed)
	var nrun: int = race.runners.size()
	loading.text = "Saddling %d runners…" % nrun
	await get_tree().process_frame
	var jra := String(RaceEngine.COURSES.get(race.course.id, {}).get("country", "JPN")) == "JPN"
	for r in race.runners:
		_dress(r.h, r.i, nrun, jra)
		var h := Horse3D.new()
		horse_root.add_child(h)
		h.setup(r.h, r.i + 1, rng.randf())
		horses.append(h)
	if paddock_mode: _spawn_paddock()
	elif paddock_root != null: paddock_root.queue_free(); paddock_root = null; paddock_horses = []
	prev_d.resize(race.runners.size()); prev_l.resize(race.runners.size())
	for r in race.runners:
		prev_d[r.i] = r.dist; prev_l[r.i] = r.lane
	comm.reset(race)
	comm_lbl.text = "🎙 " + comm.intro()
	cam.reset(race, tb, horses)
	cam.sel = sel
	tvg.setup(race, cam, tb, title)
	_apply_tv()
	board.race = race; board.sel = sel
	minimap.set_race(race); minimap.sel = sel
	minimap.cam_mode = RaceView.Cam.FULL
	running = false; acc = 0.0; gates_open = false; _results_shown = false
	results.visible = false
	play_btn.text = "▶ Start"
	info_lbl.text = "%s · %s · %d m · %s · %d runners" % [title, race.course.name, race.opts.dist, RaceEngine.going_label(race.opts.going, race.course.surface), race.runners.size()]
	_place_horses(1.0)
	cam.update_cam(0.0)
	_update_hud()
	if rebuild or tv_vp == null: _setup_screen()
	_after_finish = 0.0
	if paddock_mode:
		pk_sel = 0; _pk_t = 0.0
		_pk_caption()
	_setup_sound()
	if wx != null: wx.queue_free()
	wx = WeatherFX.new()
	add_child(wx)
	wx.setup(world_env, sun_light, tb, cam, race.opts)
	loading.visible = false

## states: pre-race (cameras live at the gates, crowd murmuring) · running · paused (the whole scene frozen:
## simulation, horses' legs, cameras, crowd, sounds) · finished (cameras follow the pull-up, crowd dies down)
var paused := false

func _toggle_play() -> void:
	if race == null or loading.visible: return
	if race.done:
		new_race(); return
	if running:
		_set_paused(true)
	else:
		_set_paused(false)
		running = true
	play_btn.text = "⏸ Pause" if running else "▶ Resume"

func _set_paused(on: bool) -> void:
	paused = on
	if on: running = false
	for h in horses: h.freeze(on)
	if wx != null: wx.freeze(on)
	for k in snd: snd[k].stream_paused = on
	tvg.set_process(not on)
	if tv_vp != null: tv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS

func _back() -> void:
	if career: Game.return_page = "results"
	if paddock_mode: Game.pending_replay = {}
	get_tree().change_scene_to_file("res://ui/main.tscn")

func _process(delta: float) -> void:
	if race == null or loading.visible: return
	if running and not race.done:
		acc += delta * speed
		var t0 := Time.get_ticks_usec()
		var n := 0
		while acc >= RaceEngine.DT and not race.done:
			for r in race.runners:
				prev_d[r.i] = r.dist; prev_l[r.i] = r.lane
			RaceEngine.step(race)
			acc -= RaceEngine.DT
			n += 1
			if n % 4 == 0: comm.update()
			if Time.get_ticks_usec() - t0 > 12000:
				acc = minf(acc, RaceEngine.DT)
				break
		comm.update()
		if not gates_open and race.t > 0.05:
			gates_open = true; tb.open_gates()
			if snd.has("gate_open"):
				snd.gate_open.volume_db = Settings.fx_db(0.0)
				snd.gate_open.play()
		tb.remove_gates(race.t > 9.0)
		if race.done:
			running = false
			play_btn.text = "↺ Watch again"
	if paused: return              # nothing moves; Resume / Back still work
	if wx != null: wx.follow(delta)
	var alpha := clampf(acc / RaceEngine.DT, 0.0, 1.0) if (race.t > 0.0 and not race.done) else 1.0
	_place_horses(alpha)
	cam.sel = sel
	if not paddock_mode:
		cam.update_cam(delta)
	_update_paddock(delta)
	minimap.update_camera(0.0)
	_update_screen()
	_update_split()
	if _bottom != null: tvg.band_offset = _bottom.size.y + 18.0
	_update_crowd(delta)
	_hud_t += delta
	if _hud_t > 0.15:
		_hud_t = 0.0
		_update_hud()
	if race.done and not _results_shown:
		_results_shown = true
		_show_results()

## silks for a runner: the owner's catalogue silk (JockeyLook) or game silks; in Japan the cap is the gate bracket
func _dress(h: Dictionary, i: int, nrun: int, jra: bool) -> void:
	var mine: bool = Game.mode == "career" and Career.W.has("stable") and Career.W.stable.has(int(h.get("id", -1)))
	var sid := JockeyLook.silk_for(h)
	h["silkId"] = sid
	if mine and sid == "": h["silks"] = Silks.of(Career.W)
	elif sid != "": h["silks"] = JockeyLook.game_silks(sid)
	elif Game.mode == "career" and not Owners.of(h).is_empty(): h["silks"] = Owners.of(h).silks
	elif not h.has("silks"): h["silks"] = Silks.random_for(int(h.get("id", i)) * 7919 + 13, String(h.get("color", "")))
	h["bracket"] = Silks.bracket(i + 1, nrun) if jra else 0
	h["cap"] = Silks.cap_hex(i + 1, nrun) if jra else String(h.silks.get("sleeve", h.silks.body))

## what the rider is doing: sitting (0), pushing in the drive (1) or using the crop (2) in bursts inside the last
## 400 m — each rider in his own rhythm, hands and heels only once past the post or eased
func _ride_mode(r) -> int:
	if r.state != &"run" or not r.driving_started: return 0
	var rem: float = float(race.opts.dist) - r.dist
	if rem < 0.0: return 0
	if rem < 420.0 and rem > 40.0 and fposmod(race.t + float(r.i) * 0.83, 3.2) < 1.6: return 2
	return 1

func _place_horses(alpha: float) -> void:
	RaceEngine.use_course(race.course.id)
	for r in race.runners:
		var d := lerpf(prev_d[r.i], r.dist, alpha)
		var l := lerpf(prev_l[r.i], r.lane, alpha)
		var p := tb.race3(d, l, 0.03)
		# face where the horse is going: a horse moving across the track angles its body slightly (crab-free)
		var slope: float = clampf((r.lane - prev_l[r.i]) / RaceEngine.DT / maxf(3.0, r.v), -0.25, 0.25) if r.v > 0.5 else 0.0
		var f: Vector3 = tb.race3(d + 1.0, l + slope, 0.0) - tb.race3(d - 1.0, l - slope, 0.0)
		var h: Horse3D = horses[r.i]
		h.position = p
		var flat := Vector2(f.x, f.z)
		h.rotation = Vector3(-atan2(f.y, maxf(0.01, flat.length())), atan2(f.x, f.z), 0.0)
		h.visible = r.state != &"dnf" or r.v > 0.0
		h.ride_mode = _ride_mode(r)
		h.animate(r.v, r.sf, race.t < r.t0)


# ---------------- HUD ----------------
func _panel_box(a := 0.72) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.15, a)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

func _btn(t: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.theme = UiTheme.build()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	# top-left: clock
	var tl := PanelContainer.new()
	tl.add_theme_stylebox_override("panel", _panel_box())
	tl.position = Vector2(12, 12)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tl.add_child(tv)
	clock_lbl = UiTheme.title_label("0:00.0", 26)
	tv.add_child(clock_lbl)
	info_lbl = UiTheme.dim_label("", 12)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(info_lbl)
	cam_lbl = UiTheme.dim_label("", 12)
	cam_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(cam_lbl)
	hud.add_child(tl)
	_panels.append(tl)
	# top-right: running order
	var tr := PanelContainer.new()
	tr.add_theme_stylebox_override("panel", _panel_box(0.68))
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-12, 12)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.custom_minimum_size = Vector2(330, 0)
	var trv := VBoxContainer.new()
	trv.add_theme_constant_override("separation", 2)
	tr.add_child(trv)
	trv.add_child(UiTheme.section("Running order"))
	board = StandingsBoard.new()
	board.custom_minimum_size = Vector2(306, 0)
	board.horse_selected.connect(func(i): sel = i; board.sel = i; minimap.sel = i)
	trv.add_child(board)
	hud.add_child(tr)
	_panels.append(tr)
	# bottom-left: course map
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", _panel_box(0.6))
	mp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mp.position = Vector2(12, -270)
	mp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap = RaceView.new()
	minimap.mini = true
	minimap.custom_minimum_size = Vector2(300, 170)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_child(minimap)
	hud.add_child(mp)
	_panels.append(mp)
	# bottom: commentary + controls
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12; bottom.offset_right = -12; bottom.offset_bottom = -10
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	_bottom = bottom
	tvg = TvOverlay.new()
	hud.add_child(tvg)
	tvg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.move_child(tvg, 0)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", _panel_box())
	comm_lbl = Label.new()
	comm_lbl.add_theme_font_size_override("font_size", 17)
	comm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cp.add_child(comm_lbl)
	bottom.add_child(cp)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_child(_btn("‹ Back", _back, "Esc"))
	play_btn = _btn("▶ Start", _toggle_play, "Space")
	bar.add_child(play_btn)
	var rb := _btn("↺ Restart", func(): new_race(), "R")
	bar.add_child(rb)
	var sp := OptionButton.new()
	for s in SPEEDS: sp.add_item("%s×" % ("½" if s == 0.5 else str(int(s))))
	sp.select(1)
	sp.focus_mode = Control.FOCUS_NONE
	sp.item_selected.connect(func(i): speed = SPEEDS[i])
	bar.add_child(sp)
	race_extra = [rb, sp]
	race_btns = [play_btn]
	for k in CAM_KEYS.size():
		var m: int = CAM_KEYS[k]
		var cb := _btn("🎥 " + CameraDirector.NAMES[m], func(): cam.set_mode(m), "Key %d" % (k + 1))
		bar.add_child(cb); race_btns.append(cb)
	pk_prev = _btn("◀ Prev horse", func(): _pk_pick(-1), "Left arrow")
	pk_next = _btn("Next horse ▶", func(): _pk_pick(1), "Right arrow")
	bar.add_child(pk_prev); bar.add_child(pk_next)
	next_btn = _btn("Next race ››", _next_pressed)
	next_btn.visible = false
	bar.add_child(next_btn)
	bottom.add_child(bar)
	# results
	results = PanelContainer.new()
	var rsb := _panel_box(0.92)
	rsb.border_color = UiTheme.ACC.darkened(0.3)
	rsb.set_border_width_all(1)
	results.add_theme_stylebox_override("panel", rsb)
	results.set_anchors_preset(Control.PRESET_CENTER)
	results.position = Vector2(-240, -220)
	results.custom_minimum_size = Vector2(480, 0)
	results.visible = false
	results_txt = RichTextLabel.new()
	results_txt.bbcode_enabled = true
	results_txt.fit_content = true
	results_txt.custom_minimum_size = Vector2(456, 0)
	results.add_child(results_txt)
	hud.add_child(results)
	loading = UiTheme.title_label("Building course…", 22)
	loading.set_anchors_preset(Control.PRESET_CENTER)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.mouse_filter = Control.MOUSE_FILTER_IGNORE      # Back stays usable under the message
	hud.add_child(loading)

func _apply_tv() -> void:
	tvg.visible = not paddock_mode       # the race overlay is always on in races; the old panels are retired
	for p in _panels: p.visible = false
	for b in race_btns + race_extra: b.visible = not paddock_mode
	pk_prev.visible = paddock_mode; pk_next.visible = paddock_mode
	if next_btn != null and paddock_mode: next_btn.visible = false

func _cycle_side() -> void:
	cam.side = (cam.side + 1) % 3
	side_btn.text = "Side: " + ["Auto", "Outside", "Inside"][cam.side]
	if cam.mode != CameraDirector.Mode.AUTO and cam.mode != CameraDirector.Mode.SIDE: cam.set_mode(CameraDirector.Mode.SIDE)

func _update_hud() -> void:
	if race == null: return
	clock_lbl.text = RaceEngine.fmt_time(RaceEngine.race_clock(race))
	var st := RaceCommentary.standings(race)
	var L = st[0]
	var togo := "FINISHED" if race.done else ("%d m to go" % roundi(maxf(0.0, race.opts.dist - L.dist)))
	cam_lbl.text = "%s   ·   🎥 %s" % [togo, cam.current_name()]
	board.refresh()

func _show_results() -> void:
	var res := RaceEngine.results(race)
	var t := "[b][color=#f5a524]Result — %s · %s %d m[/color][/b]\n" % [title, race.course.short, race.opts.dist]
	t += "[table=5][cell padding=0,1,18,1][b]Pos[/b][/cell][cell padding=0,1,18,1][b]Horse[/b][/cell][cell padding=0,1,18,1][b]Time[/b][/cell][cell padding=0,1,18,1][b]Margin[/b][/cell][cell padding=0,1,18,1][b]3F[/b][/cell]"
	for x in res.rows.slice(0, 8):
		var mine: bool = career and Career.W.stable.has(int(x.r.h.get("id", -1)))
		var sp := JockeyLook.shirt_path(String(x.r.h.get("silkId", "")))
		var sw := ("[img=22x19]%s[/img]" % sp) if sp != "" else ("[color=%s]■[/color]" % String(x.r.h.get("silks", {}).get("body", x.r.h.color)))
		t += "[cell padding=0,1,18,1]%s[/cell][cell padding=0,1,18,1]%s %s%s%s[/cell][cell padding=0,1,18,1]%s[/cell][cell padding=0,1,18,1]%s[/cell][cell padding=0,1,18,1]%s[/cell]" % [
			"DNF" if x.pos < 0 else str(x.pos), sw, "[color=#%s]" % UiTheme.MINE.to_html(false) if mine else "", x.name, "[/color]" if mine else "", RaceEngine.fmt_time(x.time), x.margin, "%.1f" % x.last3f if x.last3f > 0 else "-"]
	t += "[/table]\n"
	if career:
		for x in res.rows.slice(8):
			if Career.W.stable.has(int(x.r.h.get("id", -1))):
				t += ("[color=#%s]" % UiTheme.MINE.to_html(false)) + "%s finished %s · %s[/color]\n" % [x.name, "DNF" if x.pos < 0 else ("%d of %d" % [x.pos, res.rows.size()]), RaceEngine.fmt_time(x.time)]
	var laps: PackedStringArray = []
	for x in res.laps: laps.append("%.1f" % x)
	t += "[color=#a5a2c0]Laps: %s[/color]" % " - ".join(laps)
	results_txt.text = t
	results.visible = true

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	match e.keycode:
		KEY_ESCAPE: _back()
		KEY_LEFT: if paddock_mode: _pk_pick(-1)
		KEY_RIGHT: if paddock_mode: _pk_pick(1)
	if paddock_mode: return
	match e.keycode:
		KEY_SPACE: _toggle_play()
		KEY_R: new_race()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			if e.keycode - KEY_1 < CAM_KEYS.size(): cam.set_mode(CAM_KEYS[e.keycode - KEY_1])

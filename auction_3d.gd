extends Node3D
## Step 5 — the sale ring in 3D (Select Sale style): a wood-panelled hall with the auctioneers' rostrum, the price
## board above it (lot number, the horse's catalogue name, price in 万円 and US$), a sand ring behind a rope where a
## groom leads each lot round (foals come in with their dam), potted conifers, and the buyers seated around.
## The bidding is live: CPU bidders raise their paddles one step at a time, the auctioneer calls "going once…
## twice…" and the hammer falls unless someone (you) bids again. Uses the Auction model (sim/auction.gd).

const USD_RATE := 155.0          # yen per US$ for the board
const WALK := 1.45               # m/s, a groom's walk
const RING_A := 3.9              # walking oval (x half-axis, m)
const RING_B := 1.7              # (z half-axis)
const RING_Z := 0.6
const DOOR_L := Vector3(-6.6, 0, -4.6)
const DOOR_R := Vector3(6.6, 0, -4.6)
const CALL_TIME := 1.25          # seconds per auctioneer call ("going once", "going twice", "sold")

const C_TEXT := Color("ecebf5")    # HUD colours (always on dark panels)
const C_DIM := Color("a5a2c0")
const C_ACC := Color("f5c542")
const C_GOOD := Color("4cd964")
const C_STRONG := Color.WHITE

enum St { IDLE, ENTER, BIDDING, CALLING, SOLD, EXIT, DONE }

var a: Dictionary = {}           # the sale (Auction.current())
var st := St.IDLE
var lot_i := -1
var clock := 0.0
var next_ai := 0.0
var call_n := 0
var call_t := 0.0
var auto_next := true
var player_out := false          # the player has said "let it go" on this lot
var rng := RandomNumberGenerator.new()
var speed := 1.0
var result: Dictionary = {}

var cam: Camera3D
var cam_mode := 0
var horse_root: Node3D
var walkers: Array = []          # [{node, ap, an, off}] the lot (and its dam), each with a groom
var path_s := 0.0                # distance walked along the current path
var path: PackedVector3Array = PackedVector3Array()
var crowd: Array = []            # seated buyers (MeshInstance3D) for paddle raises
var paddle_t := {}
var auctioneer_arm: Node3D

# board
var b_vp: SubViewport
var b_lot: Label
var b_name: Label
var b_price: Label
var b_usd: Label
# HUD
var hud: CanvasLayer
var title_l: Label
var cash_l: Label
var info_l: Label
var price_l: Label
var high_l: Label
var call_l: Label
var log_box: VBoxContainer
var bid_b: Button
var stop_b: Button
var next_b: Button
var skip_b: Button
var auto_c: CheckBox
var lots_box: VBoxContainer
var jp: SystemFont

func _ready() -> void:
	rng.seed = int(Time.get_ticks_usec())
	jp = SystemFont.new()
	jp.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Noto Sans JP"])
	a = Auction.current()
	_build_hall()
	_build_hud()
	if a.is_empty() or not Auction.is_sale_week():
		_set_call("There is no sale this week.")
		st = St.DONE
	else:
		_next_lot_ready()
	_refresh()

# ======================================================================= HALL
func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = size
	mi.mesh = b; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)
	return mi

func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new(); sh.code = code
	var m := ShaderMaterial.new(); m.shader = sh
	return m

func _build_hall() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("120c0a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9b49a")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.35
	env.environment = e
	add_child(env)
	Settings.apply_3d(get_viewport(), e)
	# ceiling lights: warm spots on the ring and the rostrum
	for p in [Vector3(-3, 7.5, 1.5), Vector3(3, 7.5, 1.5), Vector3(0, 7.5, -1.0), Vector3(0, 7.0, 4.5)]:
		var sp := SpotLight3D.new()
		sp.position = p
		sp.look_at_from_position(p, Vector3(p.x * 0.6, 0, p.z - 1.0))
		sp.spot_angle = 42.0; sp.spot_range = 14.0; sp.light_energy = 2.4
		sp.light_color = Color("ffe2bd"); sp.shadow_enabled = p.z < 2.0 and bool(Settings.get_v("shadows"))
		add_child(sp)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 20, 0)
	fill.light_energy = 0.35; fill.light_color = Color("ffd9b0")
	add_child(fill)
	# floor: sand ring inside, darker sand outside
	var floor_m := _shader("""
shader_type spatial;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz;
	float ring = length(vec2(p.x / 5.6, (p.y - 0.6) / 3.2));
	float g = n(p * 9.0) * 0.5 + n(p * 37.0) * 0.35 + n(p * 1.3) * 0.15;
	vec3 sand = mix(vec3(0.43, 0.33, 0.23), vec3(0.56, 0.45, 0.33), g);
	vec3 outer = mix(vec3(0.25, 0.19, 0.14), vec3(0.32, 0.25, 0.18), g);
	float hoof = smoothstep(0.08, 0.0, abs(length(vec2(p.x / 3.9, (p.y - 0.6) / 1.7)) - 1.0)) * 0.12;
	ALBEDO = mix(sand, outer, smoothstep(0.98, 1.04, ring)) * (1.0 - hoof);
	ROUGHNESS = 0.97;
}""")
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(30, 24)
	fl.mesh = pm; fl.material_override = floor_m; fl.position = Vector3(0, 0, 3)
	add_child(fl)
	# back wall: dark wood panels, red curtain band above
	var wood := _shader("""
shader_type spatial;
uniform vec3 base : source_color = vec3(0.24, 0.14, 0.08);
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float panel = smoothstep(0.0, 0.03, abs(fract(wp.x / 1.2) - 0.5) - 0.47);
	float grain = sin(wp.y * 40.0 + sin(wp.x * 7.0) * 2.0) * 0.04 + sin(wp.y * 9.0 + wp.x) * 0.03;
	ALBEDO = base * (0.85 + grain) * (1.0 - panel * 0.45);
	ROUGHNESS = 0.55;
}""")
	_box(Vector3(26, 9, 0.4), Vector3(0, 4.5, -6.0), wood)
	for sx in [-1.0, 1.0]: _box(Vector3(0.4, 9, 20), Vector3(12.5 * sx, 4.5, 3.0), wood)
	var curtain := _shader("""
shader_type spatial;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; VERTEX.z += sin(wp.x * 9.0) * 0.06; }
void fragment(){
	float f = 0.6 + 0.4 * sin(wp.x * 9.0);
	ALBEDO = vec3(0.55, 0.06, 0.08) * f;
	ROUGHNESS = 0.6;
	SPECULAR = 0.6;
}""")
	_box(Vector3(26, 1.1, 0.2), Vector3(0, 8.4, -5.7), curtain)
	var stripe := _mat(Color("c9a65a"), 0.4, 0.5)
	_box(Vector3(26, 0.08, 0.25), Vector3(0, 7.85, -5.65), stripe)
	_box(Vector3(26, 0.4, 20), Vector3(0, 9.2, 3.0), _mat(Color("1a1310")))           # ceiling
	# doors in and out of the ring: lit corridor behind green-framed openings
	for d in [DOOR_L, DOOR_R]:
		var fr := _mat(Color("38503f"), 0.5)
		var g := _mat(Color("6e5f4c"), 1.0)
		g.emission_enabled = true; g.emission = Color("caa77a"); g.emission_energy_multiplier = 0.35
		_box(Vector3(2.6, 3.4, 0.25), Vector3(d.x, 1.7, -5.75), g)
		_box(Vector3(0.18, 3.6, 0.35), Vector3(d.x - 1.35, 1.8, -5.7), fr)
		_box(Vector3(0.18, 3.6, 0.35), Vector3(d.x + 1.35, 1.8, -5.7), fr)
		_box(Vector3(2.9, 0.22, 0.35), Vector3(d.x, 3.55, -5.7), fr)
	# the rostrum: stage, wooden desk, the sale's name on the front
	_box(Vector3(7.4, 0.6, 2.2), Vector3(0, 0.3, -4.75), _mat(Color("3a2416"), 0.6))
	var desk := _mat(Color("6a3519"), 0.45)
	_box(Vector3(5.6, 1.5, 0.6), Vector3(0, 0.75, -3.75), desk)
	_box(Vector3(5.8, 0.1, 0.8), Vector3(0, 1.52, -3.75), _mat(Color("8a4f2c"), 0.35))
	for sx in [-1.0, 1.0]: _box(Vector3(0.12, 1.5, 0.66), Vector3(2.75 * sx, 0.75, -3.73), _mat(Color("7a4426"), 0.4))
	var s := Auction.sale(String(a.get("key", "select_y"))) if not a.is_empty() else {}
	var top := "SELECT SALE"
	var sub := "JRHA"
	var key := String(a.get("key", ""))
	if key.begins_with("select"): pass
	elif key == "training": top = "TRAINING SALE"; sub = "HBA"
	elif key == "mixed": top = "MIXED SALE"; sub = "NORTHERN HORSE PARK"
	else: top = String(s.get("name", "HBA SALE")).replace("HBA ", "").split(" (")[0].to_upper(); sub = "HBA"
	var l1 := Label3D.new()
	l1.text = top; l1.font_size = 120; l1.pixel_size = 0.0042; l1.modulate = Color("e9d29a"); l1.outline_size = 0
	l1.position = Vector3(0, 0.98, -3.43); l1.shaded = true
	add_child(l1)
	var l2 := Label3D.new()
	l2.text = sub; l2.font_size = 70; l2.pixel_size = 0.0042; l2.modulate = Color("e9d29a"); l2.outline_size = 0
	l2.position = Vector3(0, 0.55, -3.43); l2.shaded = true
	add_child(l2)
	# auctioneers behind the desk (navy suits), the middle one taking the bids
	var person := TrackBuilder._person_mesh()
	for i in 3:
		var p := MeshInstance3D.new()
		p.mesh = person
		p.material_override = _mat(Color("1d2433") if i != 1 else Color("232a3a"), 0.7)
		p.position = Vector3((i - 1) * 1.15, 0.6, -4.35)
		add_child(p)
		_head(p)
	auctioneer_arm = Node3D.new()
	auctioneer_arm.position = Vector3(0.22, 0.6 + 1.42, -4.3)
	add_child(auctioneer_arm)
	_box(Vector3(0.09, 0.55, 0.09), Vector3(0, 0.27, 0), _mat(Color("232a3a")), auctioneer_arm)
	auctioneer_arm.rotation.z = 0.2
	# flower arrangements on the desk ends
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.3, 0.25, 0.3), Vector3(2.4 * sx, 1.7, -3.8), _mat(Color("6b4a2e")))
		for k in 5:
			var f := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.1; sm.height = 0.2
			f.mesh = sm
			f.material_override = _mat([Color("d9416c"), Color("f2f2f2"), Color("e38bb0")][k % 3], 0.6)
			f.position = Vector3(2.4 * sx + (k - 2) * 0.08, 1.92 + (k % 2) * 0.08, -3.8 + (k % 3 - 1) * 0.06)
			add_child(f)
	# potted conifers either side of the rostrum
	for x in [-5.0, -4.2, -3.5, 3.5, 4.2, 5.0]:
		var z := -4.2 if absf(x) < 4.5 else -3.6
		_box(Vector3(0.7, 0.55, 0.7), Vector3(x, 0.28, z), _mat(Color("3c2a1c"), 0.8))
		for k in 3:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.5 - k * 0.12; cm.height = 1.0; cm.radial_segments = 10
			c.mesh = cm
			c.material_override = _mat(Color("1f3d26").lerp(Color("2f5a33"), k * 0.3), 0.9)
			c.position = Vector3(x, 1.0 + k * 0.55, z)
			add_child(c)
	_build_board()
	# rope rail in front of the ring
	var post_m := _mat(Color("1b1b1b"), 0.4, 0.3)
	var rope_m := _mat(Color("efe9df"), 0.7)
	var px := -6.0
	while px <= 6.01:
		var po := MeshInstance3D.new()
		var cy := CylinderMesh.new(); cy.top_radius = 0.035; cy.bottom_radius = 0.045; cy.height = 1.0; cy.radial_segments = 8
		po.mesh = cy; po.material_override = post_m; po.position = Vector3(px, 0.5, 3.4)
		add_child(po)
		var ba := _box(Vector3(0.18, 0.04, 0.18), Vector3(px, 0.02, 3.4), post_m)
		ba.name = "base"
		if px < 5.99:
			for seg in 6:   # sagging rope between posts
				var t0 := float(seg) / 6.0
				var t1 := float(seg + 1) / 6.0
				var y0 := 0.97 - 0.08 * sin(PI * t0)
				var y1 := 0.97 - 0.08 * sin(PI * t1)
				var p0 := Vector3(px + 2.0 * t0, y0, 3.4)
				var p1 := Vector3(px + 2.0 * t1, y1, 3.4)
				var r := MeshInstance3D.new()
				var rc := CylinderMesh.new(); rc.top_radius = 0.018; rc.bottom_radius = 0.018; rc.height = p0.distance_to(p1); rc.radial_segments = 6
				r.mesh = rc; r.material_override = rope_m
				r.position = (p0 + p1) / 2.0
				r.rotation.z = PI / 2.0 + atan2(y1 - y0, p1.x - p0.x)
				add_child(r)
		px += 2.0
	# the buyers: rows of seats around the ring (a horseshoe), people in dark suits and some in colour
	var cols := [Color("23262d"), Color("2c2f36"), Color("3a3d45"), Color("4a3b30"), Color("e6e2da"), Color("5b6b80"), Color("1c1c1c")]
	for row in 3:
		for k in 15:
			var ang := lerpf(-1.05, 1.05, float(k) / 14.0)
			var rad := 7.6 + row * 1.1
			var pos := Vector3(sin(ang) * rad * 1.25, 0.0, 1.6 + cos(ang) * rad * 0.8)
			if pos.z > 9.3 or absf(pos.x) < 2.2 and pos.z > 6.5: continue     # keep the camera's view clear
			_box(Vector3(0.55, 0.45, 0.5), pos + Vector3(0, 0.22 + row * 0.3, 0), _mat(Color("5a1f22"), 0.8))
			var p := MeshInstance3D.new()
			p.mesh = person
			p.material_override = _mat(cols[rng.randi() % cols.size()], 0.8)
			p.scale = Vector3(1.0, 0.72, 1.0)       # seated
			p.position = pos + Vector3(0, 0.3 + row * 0.3, 0.05)
			p.rotation.y = atan2(-pos.x, -(pos.z - RING_Z)) + PI
			add_child(p)
			_head(p)
			var pad := _box(Vector3(0.02, 0.22, 0.16), Vector3(0.25, 1.05, -0.12), _mat(Color("f4f1ea"), 0.6), p)
			pad.visible = false
			pad.name = "paddle"
			crowd.append(p)
	horse_root = Node3D.new()
	add_child(horse_root)
	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	_set_cam(0)

## a face and hair on the simple person mesh
func _head(p: Node3D) -> void:
	var hd := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.115; sm.height = 0.25; sm.radial_segments = 12; sm.rings = 6
	hd.mesh = sm
	hd.material_override = _mat([Color("e0b58f"), Color("d6a77c"), Color("c99a70")][rng.randi() % 3], 0.7)
	hd.position = Vector3(0, 1.63, 0)
	p.add_child(hd)
	var hair := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.12; hm.height = 0.14; hm.radial_segments = 12; hm.rings = 4
	hair.mesh = hm
	hair.material_override = _mat([Color("17120f"), Color("2a221c"), Color("8f8a84")][rng.randi() % 3], 0.8)
	hair.position = Vector3(0, 1.71, -0.01)
	p.add_child(hair)

func _set_cam(m: int) -> void:
	cam_mode = m
	match m:
		0: cam.look_at_from_position(Vector3(0, 2.6, 11.5), Vector3(0, 2.4, -2.0))      # from the seats (like the TV picture)
		1: cam.look_at_from_position(Vector3(-5.5, 1.7, 6.5), Vector3(0, 1.2, 0.5))      # ringside, close to the horse
		2: cam.look_at_from_position(Vector3(0, 6.5, 8.5), Vector3(0, 0.5, 0.0))         # over the ring

# ---------------------------------------------------------------- price board
func _build_board() -> void:
	b_vp = SubViewport.new()
	b_vp.size = Vector2i(1024, 400)
	b_vp.transparent_bg = false
	b_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(b_vp)
	var bg := ColorRect.new()
	bg.color = Color("0b0b0d")
	bg.size = Vector2(1024, 400)
	b_vp.add_child(bg)
	var top := ColorRect.new()
	top.color = Color("17171c"); top.position = Vector2(0, 0); top.size = Vector2(1024, 150)
	b_vp.add_child(top)
	b_lot = _blabel(Vector2(0, 4), Vector2(1024, 70), 54, Color.WHITE)
	b_name = _blabel(Vector2(0, 72), Vector2(1024, 70), 50, Color.WHITE)
	var panel := ColorRect.new()
	panel.color = Color("f4f4f4"); panel.position = Vector2(110, 160); panel.size = Vector2(804, 140)
	b_vp.add_child(panel)
	b_price = _blabel(Vector2(110, 160), Vector2(804, 140), 112, Color("101010"))
	b_usd = _blabel(Vector2(0, 312), Vector2(1024, 80), 52, Color.WHITE)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(5.6, 2.19)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = b_vp.get_texture()
	m.emission_enabled = true
	m.emission_texture = b_vp.get_texture()
	m.emission_energy_multiplier = 0.9
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = m
	q.position = Vector3(0, 5.45, -5.7)
	add_child(q)
	_box(Vector3(5.9, 2.45, 0.12), Vector3(0, 5.45, -5.78), _mat(Color("101010"), 0.4, 0.4))

func _blabel(pos: Vector2, size: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos; l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", jp)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	b_vp.add_child(l)
	return l

## the catalogue name: unnamed young horses are listed by their dam and year (シーツの2019 = Sheets' 2019 foal)
func _cat_name(h: Dictionary) -> String:
	if h.get("retired", false) or int(h.get("age", 0)) >= 2: return String(h.name)
	var d = Breeding.get_horse(h.get("dam"))
	var born := int(h.get("c", {}).get("born", int(Career.W.year) - int(h.get("age", 0))))
	return "%sの%d" % [d.name if d != null else "?", born]

func _board(lot: Dictionary, price_m: float, show_price: bool) -> void:
	var h = Breeding.get_horse(lot.id)
	b_lot.text = "No. %d" % int(lot.lot)
	b_name.text = _cat_name(h) if h != null else ""
	if show_price:
		var man := int(round(price_m * 100.0))
		b_price.text = "%s 万円" % _commas(man)
		b_usd.text = "US$ %s" % _commas(int(round(price_m * 1e6 / USD_RATE)))
	else:
		b_price.text = ""; b_usd.text = ""

func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# ======================================================================= HORSES
func _bring_in(lot: Dictionary) -> void:
	for w in walkers: w.node.queue_free()
	walkers.clear()
	var h = Breeding.get_horse(lot.id)
	if h == null: return
	var age := int(h.get("age", 0))
	var sc: float = 1.0 if h.get("retired", false) else float({ 0: 0.62, 1: 0.86, 2: 0.96 }.get(age, 1.0))
	var d = Breeding.get_horse(h.get("dam")) if age == 0 and not h.get("retired", false) else null
	# foal sessions: the dam is led in first and her foal follows at foot
	walkers.append(_walker(h, sc, 2.6 if d != null else 0.0, lot.lot))
	if d != null: walkers.append(_walker(d, 1.0, 0.0, -1))
	# path: in through the left door, round the ring, then on and on until the hammer falls
	path = PackedVector3Array([DOOR_L + Vector3(0, 0, -0.6), DOOR_L + Vector3(0, 0, 1.6), Vector3(-RING_A, 0, RING_Z)])
	path_s = 0.0

func _walker(h: Dictionary, sc: float, off: float, number: int) -> Dictionary:
	var n := Node3D.new()
	horse_root.add_child(n)
	var model := HorseLook.make(h)
	model.scale *= sc
	n.add_child(model)
	var ap := HorseLook.anim_player(model)
	var nm := HorseLook.anim_name(ap, "walk")
	var an := ap.get_animation(nm)
	ap.play(nm)
	ap.speed_scale = WALK / (1.75 * sc) * an.length
	# groom on the near side, purple jacket like the sale staff
	var g := MeshInstance3D.new()
	g.mesh = TrackBuilder._person_mesh()
	g.material_override = _mat(Color("4b2f7a") if number >= 0 else Color("2c3550"), 0.7)
	g.position = Vector3(0.75 * sc + 0.15, 0, 0.85 * sc)
	n.add_child(g)
	_head(g)
	var rope := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = 0.012; c.bottom_radius = 0.012; c.height = 0.7; c.radial_segments = 5
	rope.mesh = c; rope.material_override = _mat(Color("d9d2c3"))
	rope.position = Vector3(0.45 * sc + 0.1, 1.1 * sc, 0.95 * sc); rope.rotation = Vector3(0, 0, PI / 2.0 - 0.35)
	n.add_child(rope)
	if number > 0:            # hip number
		for side in [-1.0, 1.0]:
			var tag := Label3D.new()
			tag.text = str(number); tag.font_size = 64; tag.pixel_size = 0.003 * sc
			tag.modulate = Color("111111"); tag.outline_modulate = Color.WHITE; tag.outline_size = 14
			tag.position = Vector3(0.36 * side * sc, 1.42 * sc, -0.62 * sc)
			tag.rotation = Vector3(0, PI / 2.0 * side, 0)
			n.add_child(tag)
	return { "node": n, "ap": ap, "off": off }

## position along the entry path, then laps of the oval (anticlockwise seen from the seats)
func _pos_at(s: float) -> Vector3:
	var acc := 0.0
	for i in path.size() - 1:
		var l := path[i].distance_to(path[i + 1])
		if s <= acc + l: return path[i].lerp(path[i + 1], (s - acc) / l)
		acc += l
	var ring_len := PI * (3.0 * (RING_A + RING_B) - sqrt((3.0 * RING_A + RING_B) * (RING_A + 3.0 * RING_B)))
	var u := (s - acc) / ring_len * TAU
	return Vector3(-RING_A * cos(u), 0, RING_Z + RING_B * sin(u))

func _walk(delta: float) -> void:
	if walkers.is_empty(): return
	path_s += WALK * delta
	for w in walkers:
		var s: float = maxf(0.0, path_s - float(w.off))
		var p := _pos_at(s)
		var q := _pos_at(s + 0.15)
		var n: Node3D = w.node
		n.position = p
		if q.distance_to(p) > 0.001:
			var fwd := (q - p).normalized()
			n.basis = Basis(fwd.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, fwd)

func _lead_out() -> void:
	# from wherever they are, out through the right-hand door
	var p0: Vector3 = walkers[0].node.position if not walkers.is_empty() else Vector3.ZERO
	path = PackedVector3Array([p0, Vector3(RING_A * 0.8, 0, RING_Z - 0.5), DOOR_R + Vector3(0, 0, 1.6), DOOR_R + Vector3(0, 0, -1.2)])
	path_s = 0.0

# ======================================================================= HUD
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.05, 0.1, 0.8)))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	var back := Button.new(); back.text = "◀ Leave the ring"
	back.pressed.connect(_leave)
	th.add_child(back)
	title_l = _hl("", 18, C_STRONG)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(title_l)
	for k in 3:
		var cb := Button.new()
		cb.text = ["Seats", "Ringside", "Overhead"][k]
		cb.pressed.connect(func(): _set_cam(k))
		th.add_child(cb)
	var spd := Button.new(); spd.text = "Speed ×1"
	spd.tooltip_text = "Run the sale faster (the walk, the bids and the auctioneer's calls)."
	spd.pressed.connect(func():
		speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
		spd.text = "Speed ×%d" % int(speed))
	th.add_child(spd)
	cash_l = _hl("", 15, C_ACC)
	th.add_child(cash_l)
	# right panel: the lot and the bidding
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.05, 0.1, 0.84)))
	rp.anchor_left = 1.0; rp.anchor_right = 1.0; rp.anchor_top = 0.0; rp.anchor_bottom = 1.0
	rp.offset_left = -420; rp.offset_right = -12; rp.offset_top = 64; rp.offset_bottom = -12
	hud.add_child(rp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	rp.add_child(v)
	info_l = _hl("", 13)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info_l)
	price_l = _hl("", 34, C_ACC)
	v.add_child(price_l)
	high_l = _hl("", 15)
	v.add_child(high_l)
	call_l = _hl("", 20, C_STRONG)
	call_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(call_l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	bid_b = Button.new(); bid_b.custom_minimum_size = Vector2(190, 46)
	bid_b.add_theme_font_size_override("font_size", 18)
	bid_b.pressed.connect(_bid)
	hb.add_child(bid_b)
	stop_b = Button.new(); stop_b.text = "Let it go"; stop_b.custom_minimum_size = Vector2(120, 46)
	stop_b.tooltip_text = "Stop bidding on this lot: the auctioneer knocks it down at the current price."
	stop_b.pressed.connect(_let_go)
	hb.add_child(stop_b)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 8)
	v.add_child(hb2)
	next_b = Button.new(); next_b.text = "Next lot into the ring ›"
	next_b.pressed.connect(_start_lot)
	hb2.add_child(next_b)
	skip_b = Button.new(); skip_b.text = "Skip lot"
	skip_b.tooltip_text = "This lot is sold without you."
	skip_b.pressed.connect(_skip)
	hb2.add_child(skip_b)
	auto_c = CheckBox.new(); auto_c.text = "Bring in the next lot automatically"; auto_c.button_pressed = true
	auto_c.toggled.connect(func(b): auto_next = b)
	v.add_child(auto_c)
	var fin := Button.new(); fin.text = "Leave — sell the rest without me"
	fin.pressed.connect(func():
		if not a.is_empty(): Auction.finish(a)
		_leave())
	v.add_child(fin)
	v.add_child(_hd("Bid log", 12))
	log_box = VBoxContainer.new()
	v.add_child(log_box)
	# bottom-left: the next lots
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.05, 0.1, 0.72)))
	lp.anchor_top = 1.0; lp.anchor_bottom = 1.0
	lp.offset_left = 12; lp.offset_right = 560; lp.offset_top = -190; lp.offset_bottom = -12
	hud.add_child(lp)
	lots_box = VBoxContainer.new()
	lp.add_child(lots_box)

func _hl(t: String, size := 14, col := C_TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", jp)
	return l

func _hd(t: String, size := 13) -> Label:
	return _hl(t, size, C_DIM)

func _sb(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	return sb

func _refresh() -> void:
	var lot0: Dictionary = a.lots[maxi(0, lot_i)] if not a.is_empty() and not a.lots.is_empty() else {}
	var s := Auction.sale(String(lot0.get("sale", a.get("key", "")))) if not a.is_empty() else {}
	title_l.text = "%s · %s" % [s.get("name", "Sale ring"), s.get("place", "")]
	cash_l.text = "Cash %s" % Game.money(Finance.money())
	var b = a.get("bid") if not a.is_empty() else null
	var lot: Dictionary = a.lots[lot_i] if lot_i >= 0 and not a.is_empty() else {}
	if not lot.is_empty():
		var h = Breeding.get_horse(lot.id)
		info_l.text = "Lot %d — %s\n%s" % [int(lot.lot), _cat_name(h) if h != null else "?", _lot_line(h, lot) if h != null else ""]
	else: info_l.text = ""
	if b != null:
		price_l.text = Game.money(float(b.price))
		high_l.text = "Highest bid: %s" % ("YOU" if b.high == "you" else (String(b.high) if b.high != "" else "none yet"))
		high_l.add_theme_color_override("font_color", C_GOOD if b.high == "you" else C_TEXT)
	elif not result.is_empty():
		price_l.text = Game.money(float(result.price))
		high_l.text = "Bought back (reserve not reached)" if result.buyer == "bought back" else ("Sold to YOU" if result.buyer == "you" else "Sold to %s" % String(result.buyer))
		high_l.add_theme_color_override("font_color", C_GOOD if result.buyer == "you" else C_TEXT)
	else:
		price_l.text = ""; high_l.text = ""
	var can := Profile.can_own()
	var bidding := b != null and (st == St.BIDDING or st == St.CALLING)
	bid_b.disabled = not bidding or not can or player_out or b.high == "you" or lot.get("cons", "") == "player"
	bid_b.text = "Bid %s" % Game.money(float(b.price) + Auction.increment(float(b.price))) if b != null else "Bid"
	if not can: bid_b.tooltip_text = "You need an owner licence to buy."
	stop_b.disabled = not bidding or player_out or (b != null and b.high == "you")
	next_b.disabled = st != St.IDLE
	skip_b.disabled = st != St.IDLE
	for c in log_box.get_children(): c.queue_free()
	if b != null:
		for l in b.log.slice(0, 7): log_box.add_child(_hd(l, 12))
	for c in lots_box.get_children(): c.queue_free()
	lots_box.add_child(_hl("Catalogue", 13, C_ACC))
	if not a.is_empty():
		var shown := 0
		for i in a.lots.size():
			var l: Dictionary = a.lots[i]
			if i < lot_i - 1 or shown >= 6: continue
			var h = Breeding.get_horse(l.id)
			var txt := "%3d  %s  by %s" % [int(l.lot), _cat_name(h) if h != null else "?", Breeding.get_horse(h.sire).name if h != null and Breeding.get_horse(h.sire) != null else "?"]
			if l.done: txt += "   — %s %s" % [Game.money(float(l.price)), "(YOU)" if l.buyer == "you" else ("(bought back)" if l.buyer == "bought back" else "")]
			else: txt += "   est. %s–%s" % [Game.money(float(l.mv) * 0.7), Game.money(float(l.mv) * 1.4)]
			lots_box.add_child(_hl(txt, 12, C_ACC if i == lot_i else (C_DIM if l.done else C_TEXT)))
			shown += 1

func _lot_line(h: Dictionary, lot: Dictionary) -> String:
	var s = Breeding.get_horse(h.sire)
	var d = Breeding.get_horse(h.dam)
	var ds = Breeding.get_horse(d.sire) if d != null else null
	var age := int(h.get("age", 0))
	var what := "broodmare" if h.get("retired", false) else ("foal" if age == 0 else ("yearling" if age == 1 else "2-year-old"))
	var dam_rec := ""
	if d != null:
		var dc: Dictionary = d.get("c", {})
		dam_rec = " · dam: %d wins%s" % [int(dc.get("wins", 0)), (", G1 winner" if int(dc.get("g1", 0)) > 0 else (", graded winner" if int(dc.get("graded", 0)) > 0 else ""))]
	return "%s %s · by %s (fee %s) out of %s (%s)%s\nConsignor: %s · Estimate %s–%s" % [String(h.get("coat", "")), what if what != "foal" and what != "yearling" else "%s %s" % [Game.sex_word(h), what],
		s.name if s != null else "?", Game.money(Auction.fee_of(s)), d.name if d != null else "?", ds.name if ds != null else "?", dam_rec,
		"YOU" if lot.cons == "player" else "Breeder", Game.money(float(lot.mv) * 0.7), Game.money(float(lot.mv) * 1.4)]

func _set_call(t: String) -> void:
	call_l.text = t

# ======================================================================= SALE FLOW
func _next_lot_ready() -> void:
	lot_i = -1
	for i in a.lots.size():
		if not a.lots[i].done: lot_i = i; break
	result = {}
	if lot_i < 0:
		st = St.DONE
		_set_call("All lots have been offered. Leave the ring to see the results.")
		b_lot.text = "SALE CLOSED"; b_name.text = ""; b_price.text = ""; b_usd.text = ""
		return
	st = St.IDLE
	_board(a.lots[lot_i], 0.0, false)
	_set_call("Next: Lot %d" % int(a.lots[lot_i].lot))
	clock = 0.0

func _start_lot() -> void:
	if st != St.IDLE or lot_i < 0: return
	result = {}
	player_out = false
	Auction.open_lot(lot_i)                   # opening price; the first CPU bid comes in
	_bring_in(a.lots[lot_i])
	st = St.ENTER
	clock = 0.0
	_set_call("Lot %d into the ring…" % int(a.lots[lot_i].lot))
	_board(a.lots[lot_i], float(a.bid.price), true)
	_refresh()

func _skip() -> void:
	if st != St.IDLE or lot_i < 0: return
	Auction.auto_lot(a.lots[lot_i])
	_next_lot_ready()
	_refresh()

func _bid() -> void:
	if a.get("bid") == null: return
	if not Auction.player_bid(false):
		_set_call("Not enough money (cash plus bank credit).")
		return
	_raise_paddle(null)
	_board(a.lots[lot_i], float(a.bid.price), true)
	st = St.BIDDING
	next_ai = 0.7 + rng.randf() * 0.9
	_set_call("Your bid! %s" % Game.money(float(a.bid.price)))
	_refresh()

func _let_go() -> void:
	if a.get("bid") == null: return
	# the player is out: the CPU bidders finish it between them, then the hammer
	player_out = true
	_set_call("You're out on this lot.")
	_refresh()

func _hammer() -> void:
	var lot := Auction.hammer()
	result = lot
	st = St.SOLD
	clock = 0.0
	_board(lot, float(lot.price), true)
	if lot.buyer == "you": _set_call("SOLD to you! Lot %d for %s." % [int(lot.lot), Game.money(float(lot.price))])
	elif lot.buyer == "bought back": _set_call("Bought back — the reserve was not reached.")
	else: _set_call("SOLD to %s." % String(lot.buyer))
	auctioneer_arm.rotation.z = 1.6
	_refresh()

func _raise_paddle(who: Variant) -> void:
	if crowd.is_empty(): return
	var p: Node3D = crowd[rng.randi() % crowd.size()] if who == null else crowd[abs(hash(who)) % crowd.size()]
	var pad := p.get_node_or_null("paddle")
	if pad != null:
		pad.visible = true
		paddle_t[p] = 1.2

func _process(delta_real: float) -> void:
	var delta := delta_real * speed
	clock += delta
	_walk(delta)
	for p in paddle_t.keys():
		paddle_t[p] -= delta
		if paddle_t[p] <= 0.0:
			var pad = p.get_node_or_null("paddle")
			if pad != null: pad.visible = false
			paddle_t.erase(p)
	auctioneer_arm.rotation.z = lerpf(auctioneer_arm.rotation.z, 0.2 + (0.5 + 0.25 * sin(clock * 6.0) if st == St.BIDDING else 0.0), delta * 4.0)
	match st:
		St.IDLE:
			if auto_next and clock > 1.5: _start_lot()
		St.ENTER:
			if path_s > 9.0:
				st = St.BIDDING
				next_ai = 0.6
				clock = 0.0
		St.BIDDING:
			next_ai -= delta
			if next_ai <= 0.0:
				var b: Dictionary = a.bid
				var before := String(b.high)
				if Auction._ai_round(b, a.lots[lot_i]):
					_raise_paddle(b.high)
					_board(a.lots[lot_i], float(b.price), true)
					_set_call("%s at the back… %s!" % [String(b.high), Game.money(float(b.price))] if before != "" else "Starting at %s" % Game.money(float(b.price)))
					next_ai = 0.45 + rng.randf() * 0.8
					_refresh()
				else:
					st = St.CALLING
					call_n = 0; call_t = 0.0
		St.CALLING:
			call_t -= delta
			if call_t <= 0.0:
				var b2: Dictionary = a.bid
				# a CPU bidder can still come back in when the player is high (the player's "let it go" means they're out)
				if call_n == 0 and String(b2.high) == "you" and Auction._ai_round(b2, a.lots[lot_i]):
					_raise_paddle(b2.high)
					_board(a.lots[lot_i], float(b2.price), true)
					_set_call("%s comes back in! %s" % [String(b2.high), Game.money(float(b2.price))])
					st = St.BIDDING
					next_ai = 0.8 + rng.randf()
					_refresh()
					return
				call_n += 1
				call_t = CALL_TIME
				if call_n == 1: _set_call("Going once… %s" % Game.money(float(b2.price)))
				elif call_n == 2: _set_call("Going twice…")
				else: _hammer()
		St.SOLD:
			if clock > 2.2:
				_lead_out()
				st = St.EXIT
				clock = 0.0
		St.EXIT:
			if clock > 9.0 or path_s > 12.5:
				for w in walkers: w.node.queue_free()
				walkers.clear()
				_next_lot_ready()
				_refresh()

func _leave() -> void:
	Game.return_page = "auctions"
	get_tree().change_scene_to_file("res://ui/main.tscn")

class_name PaddockHorse
extends Node3D
## A runner in the paddock: the Hyper3D horse walking (its walk clip, timed to the walking speed), its coat
## colour, the number cloth on both sides, and a groom (厩務員) leading it on the inside.

const SCALE := 1.45            # model is 1.6 m to the ear tips; ×1.45 gives ~1.63 m at the withers
const WALK_SPEED := 1.6        # m/s, a paddock walk
const CLIP_STRIDE := 1.75      # metres covered by one loop of the walk clip at speed scale 1

static var _coat_shader: Shader
static var _person: ArrayMesh

var ap: AnimationPlayer
var t := 0.0                   # position around the ring (0..1)
var lane := 0.0

## coat recolouring: the bay texture's body (saturated brown) takes the coat colour, dark points stay dark
## (chestnuts get no black points, greys lighten)
static func coat_material(src: StandardMaterial3D, coat: String, h: Dictionary = {}) -> ShaderMaterial:
	if _coat_shader == null:
		_coat_shader = Shader.new()
		_coat_shader.code = """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D nmap : hint_normal, filter_linear_mipmap;
uniform bool has_n = false;
uniform vec3 body : source_color = vec3(0.48, 0.29, 0.15);
uniform vec3 points : source_color = vec3(0.06, 0.05, 0.05);
uniform float grey = -1.0;          // < 0: not grey. 0 dark iron-grey youngster … 1 almost white
uniform int face = 0;               // 0 none 1 star 2 stripe 3 star+stripe 4 snip 5 star+snip 6 blaze 7 blaze+snip 8 bald
uniform vec4 legs = vec4(0.0);      // white height per leg (LF, RF, LH, RH), fraction of the horse's height
varying vec4 hc;                    // head coords: lateral (-1..1), along (0 nose … 1 poll), front (-1..1), in-head flag
varying vec2 lg;                    // rest height (0 ground … 1 ears), leg code (1 LF 2 RF 3 LH 4 RH)
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() { hc = COLOR; lg = UV2; }
float band(float x, float a, float b, float s) { return smoothstep(a - s, a + s, x) * (1.0 - smoothstep(b - s, b + s, x)); }
float face_white() {
	if (hc.w < 0.5 || face == 0) return 0.0;
	float lat = abs(hc.x * 2.0 - 1.0);
	float al = hc.y;
	float fr = smoothstep(0.42, 0.62, hc.z);              // front of the face only
	float wob = (vnoise(vec2(al * 9.0, hc.x * 5.0)) - 0.5) * 0.06;   // irregular edges like real markings
	float star = band(al, 0.66, 0.84, 0.015) * (1.0 - smoothstep(0.13, 0.16, lat + wob + abs(al - 0.75) * 0.6));
	float stripe = band(al, 0.22, 0.72, 0.02) * (1.0 - smoothstep(0.05, 0.075, lat + wob * 0.6));
	float blaze = band(al, 0.06, 0.86, 0.02) * (1.0 - smoothstep(0.17 + al * 0.12, 0.2 + al * 0.12, lat + wob));
	float snip = band(al, 0.0, 0.2, 0.02) * (1.0 - smoothstep(0.16, 0.2, lat + wob));
	float bald = band(al, 0.0, 0.88, 0.02) * (1.0 - smoothstep(0.45, 0.5, lat + wob));
	float m = 0.0;
	if (face == 1) m = star;
	else if (face == 2) m = stripe;
	else if (face == 3) m = max(star, stripe);
	else if (face == 4) m = snip;
	else if (face == 5) m = max(star, snip);
	else if (face == 6) m = blaze;
	else if (face == 7) m = max(blaze, snip * 1.0);
	else if (face == 8) m = bald;
	return m * fr;
}
float leg_white(float ux) {
	int code = int(lg.y + 0.5);
	if (code < 1) return 0.0;
	float hgt = code == 1 ? legs.x : (code == 2 ? legs.y : (code == 3 ? legs.z : legs.w));
	if (hgt <= 0.0) return 0.0;
	float edge = hgt + (vnoise(vec2(lg.x * 40.0, float(code) * 7.0 + ux * 30.0)) - 0.5) * 0.012;
	return 1.0 - smoothstep(edge - 0.004, edge + 0.004, lg.x);
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b)); float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float bodym = smoothstep(0.2, 0.42, sat) * smoothstep(0.1, 0.22, lum);
	float shade = clamp(lum / 0.6, 0.35, 1.25);
	vec3 b = body; vec3 p = points;
	float dap = 0.0;
	if (grey >= 0.0) {                                    // greys lighten with age; dapples strongest mid-way
		b = mix(vec3(0.2, 0.2, 0.2), vec3(0.9, 0.89, 0.87), grey);
		p = mix(vec3(0.12, 0.12, 0.12), vec3(0.62, 0.61, 0.6), grey);
		float d = vnoise(UV * 110.0) * 0.6 + vnoise(UV * 260.0) * 0.4;
		dap = 4.0 * grey * (1.0 - grey);
		b *= 1.0 + dap * 0.22 * (smoothstep(0.4, 0.8, d) - 0.5);
	}
	vec3 coat = b * shade;
	vec3 pts = p * (0.7 + 0.6 * lum);
	vec3 col = mix(pts, coat, bodym);
	float hoof = (1.0 - smoothstep(0.1, 0.25, sat)) * smoothstep(0.38, 0.55, lum);
	float w = max(face_white(), leg_white(UV.x) * (1.0 - hoof));
	col = mix(col, vec3(0.92, 0.91, 0.89) * clamp(lum / 0.5, 0.75, 1.15), w);   // white hair keeps the shading
	ALBEDO = mix(col, c * 0.8, hoof);
	ROUGHNESS = 0.5;
	SPECULAR = 0.35;
	if (has_n) { NORMAL_MAP = texture(nmap, UV).rgb; }
}
"""
	var m := ShaderMaterial.new()
	m.shader = _coat_shader
	m.set_shader_parameter("tex", src.albedo_texture)
	if src.normal_enabled and src.normal_texture != null:
		m.set_shader_parameter("nmap", src.normal_texture); m.set_shader_parameter("has_n", true)
	# body, points (mane, tail, lower legs), grey flag
	var cs := { "bay": ["#5e3219", "#141110", 0.0], "dark bay": ["#3a2114", "#0d0a09", 0.0], "chestnut": ["#86451f", "#73391b", 0.0],
		"black": ["#1d1a19", "#0b0a0a", 0.0], "grey": ["#a9a8a4", "#4a4846", 1.0] }
	var v: Array = cs.get(coat, cs.bay)
	m.set_shader_parameter("body", Color(v[0]))
	m.set_shader_parameter("points", Color(v[1]))
	m.set_shader_parameter("grey", Markings.grey_level(h) if coat == "grey" and not h.is_empty() else (0.55 if coat == "grey" else -1.0))
	if not h.is_empty():
		var mk: Dictionary = Markings.of(h)
		m.set_shader_parameter("face", Markings.FACE.find(String(mk.face)))
		var lv := [0.0, 0.058, 0.085, 0.14, 0.27]           # coronet, pastern, sock (above the fetlock), stocking (to the knee/hock)
		m.set_shader_parameter("legs", Vector4(lv[int(mk.legs[0])], lv[int(mk.legs[1])], lv[int(mk.legs[2])], lv[int(mk.legs[3])]))
	return m

## Adds rest-pose coordinates to the mesh so markings stay on the face and legs while the horse moves:
## COLOR = head coordinates (lateral, along, front, in-head flag) from the head's own axes (found by PCA of the
## head vertices, so a slightly turned head in the rest pose does not matter); UV2 = (height, leg code).
static var _prep := {}
static func prepared_mesh(mesh: Mesh) -> Mesh:
	if _prep.has(mesh): return _prep[mesh]
	var arr := mesh.surface_get_arrays(0)
	var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var mn := Vector3(INF, INF, INF); var mx := -mn
	for p in P: mn = mn.min(p); mx = mx.max(p)
	var sz := mx - mn
	# mesh axes (normalised): x across, y nose (0) to tail (1), z ground (0) to ears (1)
	var head: Array[Vector3] = []
	for p in P:
		var q := (p - mn) / sz
		if q.y < 0.15 and q.z > 0.55: head.append(Vector3(q.x * sz.x, q.y * sz.y, q.z * sz.z))
	var cen := Vector3.ZERO
	for p in head: cen += p
	cen /= maxf(1.0, head.size())
	var cxx := 0.0; var cxy := 0.0; var cxz := 0.0; var cyy := 0.0; var cyz := 0.0; var czz := 0.0
	for p in head:
		var d := p - cen
		cxx += d.x * d.x; cxy += d.x * d.y; cxz += d.x * d.z; cyy += d.y * d.y; cyz += d.y * d.z; czz += d.z * d.z
	var M := Basis(Vector3(cxx, cxy, cxz), Vector3(cxy, cyy, cyz), Vector3(cxz, cyz, czz))
	var v1 := _power(M, Vector3(0.1, -1.0, -0.5))
	var lam := (M * v1).length()
	var M2 := Basis(M.x - v1 * (lam * v1.x), M.y - v1 * (lam * v1.y), M.z - v1 * (lam * v1.z))
	var v2 := _power(M2, Vector3(0.0, -0.5, 1.0))
	v2 = (v2 - v1 * v1.dot(v2)).normalized()
	var v3 := v1.cross(v2).normalized()                  # across the head (smallest spread)
	# signs: v1 points to the nose tip; v2 (front) points away from the throat, i.e. forwards/up
	var tip := cen; var tv := INF
	for p in head:
		if p.y < tv: tv = p.y; tip = p
	if v1.dot(tip - cen) < 0.0: v1 = -v1
	if v2.dot(Vector3(0, -1.0, 0.6)) < 0.0: v2 = -v2
	var a0 := INF; var a1 := -INF; var l0 := INF; var l1 := -INF; var f0 := INF; var f1 := -INF
	for p in head:
		var d := p - cen
		a0 = minf(a0, d.dot(v1)); a1 = maxf(a1, d.dot(v1))
		l0 = minf(l0, d.dot(v3)); l1 = maxf(l1, d.dot(v3))
		f0 = minf(f0, d.dot(v2)); f1 = maxf(f1, d.dot(v2))
	var lmid := 0.0
	for p in head: lmid += (p - cen).dot(v3)
	lmid /= maxf(1.0, head.size())
	var lw := maxf(absf(l0 - lmid), absf(l1 - lmid))
	# legs: lower legs, split into fore/hind and left/right around each pair's own centre
	var mxf := 0.0; var nf := 0; var mxh := 0.0; var nh := 0
	for p in P:
		var q := (p - mn) / sz
		if q.z < 0.3:
			if q.y < 0.5: mxf += q.x; nf += 1
			else: mxh += q.x; nh += 1
	mxf /= maxf(1, nf); mxh /= maxf(1, nh)
	var cols := PackedColorArray(); cols.resize(P.size())
	var uv2 := PackedVector2Array(); uv2.resize(P.size())
	for i in P.size():
		var q := (P[i] - mn) / sz
		var p := Vector3(q.x * sz.x, q.y * sz.y, q.z * sz.z)
		var inh := q.y < 0.16 and q.z > 0.5
		var d := p - cen
		var al := 1.0 - (d.dot(v1) - a0) / maxf(1e-6, a1 - a0)          # 0 at the nose, 1 at the back of the head
		var lt := clampf(0.5 + 0.5 * (d.dot(v3) - lmid) / maxf(1e-6, lw), 0.0, 1.0)
		var fr := clampf((d.dot(v2) - f0) / maxf(1e-6, f1 - f0), 0.0, 1.0)
		cols[i] = Color(lt, clampf(al, 0.0, 1.0), fr, 1.0 if inh else 0.0)
		var code := 0
		if q.z < 0.32:
			var fore := q.y < 0.5
			var left := q.x > (mxf if fore else mxh)                       # +x is the horse's left
			code = (1 if left else 2) if fore else (3 if left else 4)
		uv2[i] = Vector2(q.z, float(code))
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var out := ArrayMesh.new()
	var fmt: int = mesh.surface_get_format(0)
	var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 0
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	out.surface_set_material(0, mesh.surface_get_material(0))
	_prep[mesh] = out
	return out

static func _power(M: Basis, v: Vector3) -> Vector3:
	v = v.normalized()
	for i in 60: v = (M * v).normalized()
	return v

func setup(h: Dictionary, number: int, cloth: Color, start_t: float) -> PaddockHorse:
	t = start_t
	var model := HorseLook.make(h)          # the new 43-bone horse with its baked coat & markings
	add_child(model)
	ap = HorseLook.anim_player(model)
	var nm := HorseLook.anim_name(ap, "walk")
	var an := ap.get_animation(nm)
	ap.play(nm)
	ap.seek(fposmod(start_t * 17.0, 1.0) * an.length, true)
	ap.speed_scale = WALK_SPEED / CLIP_STRIDE * an.length
	_cloth(number, cloth)
	_groom(number)
	return self

## number cloth (ゼッケン) on both sides of the back, in the gate colour
func _cloth(number: int, cloth: Color) -> void:
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new(); b.size = Vector3(0.025, 0.42, 0.62)
		mi.mesh = b
		var m := StandardMaterial3D.new(); m.albedo_color = cloth; m.roughness = 0.8
		mi.material_override = m
		mi.position = Vector3(0.345 * side, 1.42, 0.0)
		mi.rotation = Vector3(0, 0, -0.12 * side)
		add_child(mi)
		var lab := Label3D.new()
		lab.text = str(number)
		lab.font_size = 96; lab.pixel_size = 0.003
		lab.modulate = UiTheme.on_silk(cloth); lab.outline_size = 0
		lab.position = Vector3(0.365 * side, 1.42, -0.03)
		lab.rotation = Vector3(0, PI / 2.0 * side, -0.12 * side)
		add_child(lab)
	var pad := MeshInstance3D.new()
	var pb := BoxMesh.new(); pb.size = Vector3(0.7, 0.04, 0.66)
	pad.mesh = pb
	var pm := StandardMaterial3D.new(); pm.albedo_color = cloth
	pad.material_override = pm
	pad.position = Vector3(0, 1.63, 0.0)
	add_child(pad)

## the groom walks on the horse's left (near side), level with the head, holding the lead rope
func _groom(number: int) -> void:
	if _person == null: _person = TrackBuilder._person_mesh()
	var g := MeshInstance3D.new()
	g.mesh = _person
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2b3f6b") if number % 2 == 0 else Color("6b2b2b")
	g.material_override = m
	g.position = Vector3(0.75, 0, 0.85)
	add_child(g)
	var rope := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = 0.012; c.bottom_radius = 0.012; c.height = 0.75; c.radial_segments = 5
	rope.mesh = c
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color("d9d2c3")
	rope.material_override = rm
	rope.position = Vector3(0.45, 1.15, 1.05)
	rope.rotation = Vector3(0, 0, PI / 2.0 - 0.35)
	add_child(rope)

## walk round the ring (anticlockwise); called every frame with the paddock node as reference frame
func walk(delta: float, paddock: Node3D) -> void:
	t = fposmod(t + delta * WALK_SPEED / TrackBuilder.ring_length(), 1.0)
	var p := TrackBuilder.ring_point(t, lane)
	var q := TrackBuilder.ring_point(t + 0.002, lane)
	var fwd := (q - p).normalized()
	var xf := Transform3D(Basis(fwd.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, fwd), p + Vector3(0, 0.04, 0))
	global_transform = paddock.global_transform * xf

class_name TrackBuilder
extends RefCounted
## Builds the 3D racecourse from the engine's course data: Terrain3D landscape (real elevation under the
## track, flat infield with a lake, gentle hills outside), racing surface (turf stripes / harrowed dirt),
## the second course (dirt inside turf, or turf outside dirt), rails with posts, starting spur,
## furlong poles, finish post and line, start line and gates, grandstand, trees.
## Coordinates: engine 2D (x, y) -> 3D (x, elevation, -y). Everything is in metres.

const TERRAIN_SPACING := 4.0          # Terrain3D vertex spacing (m)
const RAIL_H := 1.05
static var use_terrain3d := true      # set false to use a plain ground mesh instead of Terrain3D

var race: RaceEngine.Race
var T: Dictionary
var root: Node3D
var terrain: Node3D                   # Terrain3D node (or fallback mesh)
var gate_doors: Array = []
var gate_node: Node3D
var water_level := 0.0
var _hill := FastNoiseLite.new()
var _lake_a := 0.0
var _lake_b := 0.0
var _bounds := Rect2()
var _stand := {}                       # grandstand span info


# ---------------- coordinates ----------------
static func to3(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, -p.y)

func loop3(s: float, off: float, dh := 0.0) -> Vector3:
	return to3(RaceEngine.xy(s, off), RaceEngine.elevation(s) + dh)

func race3(d: float, off: float, dh := 0.0) -> Vector3:
	return to3(RaceEngine.race_xy(race, d, off), RaceEngine.race_elev(race, d) + dh)

## inverse of the stadium mapping: 2D point -> (s along the loop, offset from the inside rail)
func s_off(x: float, y: float) -> Vector2:
	var S: float = T.S
	var r: float = T.r
	var xm: float = -x if T.dir == "R" else x
	if T.straight:
		return Vector2(clampf(xm + S / 2.0, 0.0, S), -y - r)
	if absf(xm) <= S / 2.0:
		if y < 0.0: return Vector2(xm + S / 2.0, -y - r)
		return Vector2(S + PI * r + (S / 2.0 - xm), y - r)
	if xm > S / 2.0:
		var dx := xm - S / 2.0
		var a := atan2(y, dx)
		return Vector2(S + (a + PI / 2.0) * r, sqrt(dx * dx + y * y) - r)
	var dx2 := xm + S / 2.0
	var a2 := fposmod(atan2(y, dx2), TAU)
	return Vector2(2.0 * S + PI * r + (a2 - PI / 2.0) * r, sqrt(dx2 * dx2 + y * y) - r)


# ---------------- build ----------------
func build(parent: Node3D, r: RaceEngine.Race) -> Node3D:
	race = r
	T = r.course
	RaceEngine.use_course(T.id)
	root = Node3D.new()
	root.name = "Course"
	parent.add_child(root)
	_hill.seed = 7
	_hill.frequency = 0.004
	_lake_a = T.S * 0.28
	_lake_b = T.r * 0.28
	var emin := 99.0
	for e in T.elev: emin = minf(emin, float(e[1]))
	water_level = emin - 0.35
	_compute_bounds()
	_build_terrain()
	_build_surfaces()
	_build_rails()
	_build_markers()
	_build_gates()
	_build_grandstand()
	_build_lake()
	_build_infield()
	_build_trees()
	return root

func _compute_bounds() -> void:
	var pts: Array = []
	var end: float = T.S if T.straight else T.C
	var s := 0.0
	while s <= end:
		pts.append(RaceEngine.xy(s, T.width + 260.0)); pts.append(RaceEngine.xy(s, -T.r * 0.9 if not T.straight else -60.0))
		s += 25.0
	if race.chute.has("L"):
		for d in [-60.0, race.chute.L]:
			pts.append(RaceEngine.race_xy(race, d, -120.0)); pts.append(RaceEngine.race_xy(race, d, T.width + 120.0))
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y)); mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	_bounds = Rect2(mn, mx - mn)


# ---------------- terrain ----------------
func height_at(x: float, y: float) -> float:
	var so := s_off(x, y)
	var s: float = so.x
	var off: float = so.y
	var base: float = RaceEngine.elevation(s)
	var W: float = T.width
	# starting spur: flatten along it
	if race.chute.has("L"):
		var a := RaceEngine.race_xy(race, -60.0, W / 2.0)
		var b := RaceEngine.race_xy(race, race.chute.L, W / 2.0)
		var ab := b - a
		var t := clampf((Vector2(x, y) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var dist := (Vector2(x, y) - (a + ab * t)).length()
		if dist < W / 2.0 + 14.0:
			var d: float = -60.0 + t * (race.chute.L + 60.0)
			return RaceEngine.race_elev(race, d) - 0.25
	if T.straight:
		if off > -40.0 and off < W + 70.0: return base - 0.25
		return base - 0.25 + _hills(x, y, absf(off - W / 2.0) - W / 2.0 - 70.0)
	if off < -30.0:
		var e := (x / _lake_a) * (x / _lake_a) + (y / _lake_b) * (y / _lake_b)
		if e < 1.0: return water_level - 1.2
		if e < 1.15: return lerpf(water_level - 1.2, base - 0.1, (e - 1.0) / 0.15)
		return base - 0.1
	if off <= W + 70.0: return base - 0.25
	# flat ground behind the stand for the paddock and plaza (same span as _build_grandstand)
	var ss0: float = maxf(5.0, T.finish - 360.0)
	var ss1: float = minf(T.S - 5.0, T.finish + 110.0)
	if s > ss0 and s < ss1 and off < W + 200.0: return base - 0.25
	return base - 0.25 + _hills(x, y, off - W - 70.0)

func _hills(x: float, y: float, dist_out: float) -> float:
	var k := smoothstep(0.0, 220.0, dist_out)
	# fade back to 0 at the edge of the imported area so it meets Terrain3D's flat world background
	var ex := minf(x - _bounds.position.x, _bounds.end.x - x)
	var ey := minf(y - _bounds.position.y, _bounds.end.y - y)
	var edge := smoothstep(0.0, 160.0, minf(ex, ey))
	return (6.0 + 9.0 * _hill.get_noise_2d(x, y)) * k * edge

func _build_terrain() -> void:
	var vs := TERRAIN_SPACING
	var x0 := floorf(_bounds.position.x / vs) * vs
	var y0 := floorf(_bounds.position.y / vs) * vs
	var nx := int(ceil(_bounds.size.x / vs)) + 2
	var ny := int(ceil(_bounds.size.y / vs)) + 2
	# 3D z = -y: image row j runs from z0 = -(y0 + (ny-1)*vs) towards +z
	var z0 := -(y0 + (ny - 1) * vs)
	var himg := Image.create_empty(nx, ny, false, Image.FORMAT_RF)
	var cimg := Image.create_empty(nx, ny, false, Image.FORMAT_RGBA8)
	for j in ny:
		var z := z0 + j * vs
		var y := -z
		for i in nx:
			var x := x0 + i * vs
			var h := height_at(x, y)
			himg.set_pixel(i, j, Color(h, 0, 0))
			var so := s_off(x, y)
			var tint := 1.0 + 0.08 * _hill.get_noise_2d(x * 3.0, y * 3.0)
			var near: bool = so.y > -30.0 and so.y < T.width + 70.0
			var c := Color(0.95 * tint, 1.0 * tint, 0.9 * tint, 0.5) if near else Color(0.85 * tint, 0.9 * tint, 0.72 * tint, 0.5)
			cimg.set_pixel(i, j, c)
	if use_terrain3d and ClassDB.class_exists("Terrain3D"):
		var t: Node3D = ClassDB.instantiate("Terrain3D")
		t.name = "Terrain3D"
		t.set("free_editor_textures", false)
		t.set("vertex_spacing", vs)
		root.add_child(t)
		var assets: Resource = ClassDB.instantiate("Terrain3DAssets")
		var ta: Resource = ClassDB.instantiate("Terrain3DTextureAsset")
		ta.set("name", "Grass")
		ta.set("albedo_texture", _grass_albedo())
		ta.set("normal_texture", _flat_normal())
		ta.set("uv_scale", 0.12)
		assets.call("set_texture_asset", 0, ta)
		t.set("assets", assets)
		var mat: Resource = t.get("material")
		if mat != null: mat.set("world_background", 1)      # flat ground beyond the imported area
		var data: Object = t.get("data")
		data.call("import_images", [himg, null, cimg], Vector3(x0, 0.0, z0), 0.0, 1.0)
		terrain = t
	else:
		terrain = _fallback_ground(himg, Vector3(x0, 0.0, z0), vs)

func _fallback_ground(himg: Image, origin: Vector3, vs: float) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2
	var nx := himg.get_width()
	var ny := himg.get_height()
	var j := 0
	while j < ny - step:
		var i := 0
		while i < nx - step:
			var q := [Vector2i(i, j), Vector2i(i + step, j), Vector2i(i + step, j + step), Vector2i(i, j + step)]
			var p: Array = []
			for c in q: p.append(origin + Vector3(c.x * vs, himg.get_pixel(c.x, c.y).r, c.y * vs))
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(p[k].x, p[k].z) * 0.1)
				st.add_vertex(p[k])
			i += step
		j += step
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = _grass_albedo()
	m.uv1_scale = Vector3(0.3, 0.3, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root.add_child(mi)
	return mi

func _grass_albedo() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var fine := randf() * 0.12
			img.set_pixel(x, y, Color(0.10 + 0.04 * v + fine * 0.15, 0.20 + 0.07 * v + fine * 0.45, 0.07 + 0.03 * v, 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _flat_normal() -> ImageTexture:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 1.0, 0.85))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------- racing surfaces ----------------
static var _surf_cache := {}
## racing surface. UV.x = metres across from the inside rail, UV.y = metres along the course
static func surface_material(dirt: bool) -> ShaderMaterial:
	if _surf_cache.has(dirt): return _surf_cache[dirt]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 c1 : source_color;
uniform vec3 c2 : source_color;
uniform vec3 wear : source_color;
uniform bool dirt = false;
uniform float width = 25.0;
uniform float wet = 0.0;           // 0 dry … 1 waterlogged (heavy going, rain)
uniform float snow = 0.0;          // dusting of snow on the turf
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return 0.5 * vnoise(p) + 0.25 * vnoise(p * 2.03) + 0.125 * vnoise(p * 4.1) + 0.0625 * vnoise(p * 8.3); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 w = wp.xz;
	float dcam = length(VERTEX);
	float fine = mix(vnoise(w * 6.0), 0.5, smoothstep(15.0, 60.0, dcam));   // blade-scale detail fades with distance
	vec3 col;
	float rough;
	if (dirt) {
		// harrowed sand: fine lines along the course, hoof scuffs, darker damp band by the inside rail
		float harrow = 0.5 + 0.5 * sin(UV.x * 18.0 + fbm(w * 0.7) * 3.0);
		harrow = mix(harrow, 0.5, smoothstep(25.0, 90.0, dcam));
		float scuff = smoothstep(0.62, 0.8, fbm(w * 1.6 + 7.0));
		col = c1 * (0.9 + 0.12 * harrow) * (0.92 + 0.14 * fbm(w * 0.35));
		col = mix(col, c2, scuff * 0.55);
		col = mix(col, c2 * 0.85, (1.0 - smoothstep(0.0, 3.0, UV.x)) * 0.35);
		col *= 0.94 + 0.12 * fine;
		rough = 0.95;
	} else {
		// mown turf: wide light/dark bands across the course, clumpy grass, worn lanes by the inside rail
		float band = smoothstep(0.42, 0.58, abs(fract(UV.y / 20.0) * 2.0 - 1.0));
		col = mix(c1, c2, band);
		col *= 0.86 + 0.26 * fbm(w * 0.22);
		col *= 0.9 + 0.18 * fine;
		float worn = (1.0 - smoothstep(0.5, 6.0, UV.x)) * smoothstep(0.45, 0.7, fbm(w * 0.5 + 3.0));
		col = mix(col, wear, worn * 0.22);
		float divot = smoothstep(0.86, 0.9, vnoise(w * 2.2 + 11.0)) * (1.0 - smoothstep(20.0, 70.0, dcam));
		col = mix(col, wear * 0.8, divot * 0.35);
		rough = 0.88;
	}
	float spec = 0.25;
	if (wet > 0.0) {
		// wet ground is darker and glossier; dirt collects standing water in the hoof-churned hollows
		float wetness = wet * (0.75 + 0.25 * fbm(w * 0.15 + 5.0));
		col *= mix(1.0, dirt ? 0.55 : 0.78, wetness);
		rough = mix(rough, dirt ? 0.32 : 0.5, wetness);
		spec = mix(spec, 0.5, wetness);
		if (dirt) {
			float pud = smoothstep(0.72 - wet * 0.2, 0.78 - wet * 0.2, fbm(w * 0.45 + 17.0)) * smoothstep(0.35, 0.8, wet);
			col = mix(col, col * 0.45, pud);
			rough = mix(rough, 0.04, pud);
			spec = mix(spec, 0.9, pud);
		}
	}
	if (snow > 0.0) {
		float cov = smoothstep(0.5 - snow * 0.5, 0.8 - snow * 0.5, fbm(w * 0.9) + 0.25 * fine) * snow;
		cov *= 1.0 - (1.0 - smoothstep(0.0, 4.0, UV.x)) * 0.6;   // churned off the racing line
		col = mix(col, vec3(0.86, 0.88, 0.92), cov);
		rough = mix(rough, 0.75, cov);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	if dirt:
		m.set_shader_parameter("c1", Color("b39672")); m.set_shader_parameter("c2", Color("8a6e50")); m.set_shader_parameter("dirt", true)
	else:
		m.set_shader_parameter("c1", Color("2a5f27")); m.set_shader_parameter("c2", Color("36702f")); m.set_shader_parameter("wear", Color("7d7a4e"))
	_surf_cache[dirt] = m
	return m

## ribbon between two offsets; f(t, off, dh) -> Vector3
func _ribbon(f: Callable, t0: float, t1: float, step: float, off_a: float, off_b: float, dh: float, mat: Material, across := 2) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var ts: Array = []
	var t := t0
	while t < t1:
		ts.append(t); t += step
	ts.append(t1)
	for k in ts.size() - 1:
		for a in across:
			var oa := lerpf(off_a, off_b, float(a) / across)
			var ob := lerpf(off_a, off_b, float(a + 1) / across)
			var q := [[ts[k], oa], [ts[k], ob], [ts[k + 1], ob], [ts[k + 1], oa]]
			var v: Array = []
			for c in q: v.append(f.call(c[0], c[1], dh))
			# keep every triangle facing up (mirrored right-handed courses reverse the winding)
			var up: bool = (v[1] - v[0]).cross(v[2] - v[0]).y < 0.0
			for idx in ([0, 1, 2, 0, 2, 3] if up else [0, 2, 1, 0, 3, 2]):
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(q[idx][1], q[idx][0]))
				st.add_vertex(v[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

func _loop_end() -> float:
	return T.S if T.straight else T.C

func _build_surfaces() -> void:
	var dirtC: bool = T.surface == "dirt"
	var W: float = T.width
	var main := surface_material(dirtC)
	var lp := Callable(self, "loop3")
	var t0 := -60.0 if T.straight else 0.0
	_ribbon(lp, t0, _loop_end() + (60.0 if T.straight else 0.0), 2.0, -0.6, W + 0.6, 0.03, main, 6)
	if race.chute.has("L"):
		_ribbon(Callable(self, "race3"), -70.0, race.chute.L, 2.0, -0.6, W + 0.6, 0.03, main, 6)
	if not T.straight:
		if dirtC: _ribbon(lp, 0.0, T.C, 2.0, W + 5.0, W + 31.0, 0.0, surface_material(false), 4)   # turf course outside
		else: _ribbon(lp, 0.0, T.C, 2.0, -24.0, -6.0, 0.0, surface_material(true), 4)                # dirt course inside


# ---------------- rails ----------------
## round rail bar along a path at offset 'off' and height h; posts collects frames every 'gap' m
func _rail(f: Callable, t0: float, t1: float, off: float, mat: Material, posts: Array, h := RAIL_H, r := 0.065, gap := 3.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ts: Array = []
	var t := t0
	while t < t1:
		ts.append(t); t += 3.0
	ts.append(t1)
	var prof: Array = []
	for e in 8: prof.append(Vector2(cos(TAU * e / 8.0) * r, h + sin(TAU * e / 8.0) * r))
	for k in ts.size() - 1:
		for e in 8:
			var pa: Vector2 = prof[e]
			var pb: Vector2 = prof[(e + 1) % 8]
			var v := [f.call(ts[k], off + pa.x, pa.y), f.call(ts[k], off + pb.x, pb.y), f.call(ts[k + 1], off + pb.x, pb.y), f.call(ts[k + 1], off + pa.x, pa.y)]
			for idx in ([0, 2, 1, 0, 3, 2] if T.dir == "R" else [0, 1, 2, 0, 2, 3]): st.add_vertex(v[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	if gap <= 0.0: return
	t = t0
	while t <= t1:
		posts.append(_frame(f, t, off)); t += gap

## goose-neck post (JRA inside rail): upright, then curving over towards the track (+z in the frame)
static func _gooseneck_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var path: Array = []
	for k in 7: path.append(Vector3(0, 0.08 + k * 0.1, 0))
	for k in 7:
		var a := PI / 2.0 * (k + 1) / 7.0
		path.append(Vector3(0, 0.68 + sin(a) * 0.3, (1.0 - cos(a)) * 0.3))
	var r := 0.035
	for k in path.size() - 1:
		var p0: Vector3 = path[k]; var p1: Vector3 = path[k + 1]
		var d := (p1 - p0).normalized()
		var side := Vector3.RIGHT
		var up := d.cross(side).normalized()
		for e in 6:
			var a0 := TAU * e / 6.0; var a1 := TAU * (e + 1) / 6.0
			var o0 := (side * cos(a0) + up * sin(a0)) * r
			var o1 := (side * cos(a1) + up * sin(a1)) * r
			for v in [p0 + o0, p1 + o0, p1 + o1, p0 + o0, p1 + o1, p0 + o1]: st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _posts(xfs: Array, mesh: Mesh, mat: Material, flip := false) -> void:
	if xfs.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		var xf: Transform3D = xfs[k]
		if flip: xf.basis = xf.basis * Basis(Vector3.UP, PI)
		mm.set_instance_transform(k, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)

func _build_rails() -> void:
	var W: float = T.width
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.95)
	white.roughness = 0.35
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lp := Callable(self, "loop3")
	var rc := Callable(self, "race3")
	var inner: Array = []
	var outer: Array = []
	var t0 := -60.0 if T.straight else 0.0
	var t1 := _loop_end() + (60.0 if T.straight else 0.0)
	# inside rail: bar carried on goose-neck posts that lean over the track
	if race.chute.has("L"):
		_rail(rc, -70.0, race.chute.L, -0.3 + 0.3, white, inner, 0.98)
		_rail(rc, -70.0, race.chute.L, W + 0.3, white, outer)
		_rail(rc, -70.0, race.chute.L, W + 0.3, white, outer, 0.45, 0.04, 0.0)
	_rail(lp, t0, t1, -0.3 + 0.3, white, inner, 0.98)
	# outside rail: two bars on straight posts
	_rail(lp, t0, t1, W + 0.3, white, outer)
	_rail(lp, t0, t1, W + 0.3, white, outer, 0.45, 0.04, 0.0)
	if not T.straight:
		if T.surface == "dirt": _rail(lp, 0.0, T.C, W + 31.3, white, outer)
		else: _rail(lp, 0.0, T.C, -24.0, white, inner, 0.98)
	# goose-neck posts stand 0.3 m inside the rail line and curve out over it
	var gx: Array = []
	for xf in inner: gx.append((xf as Transform3D).translated_local(Vector3(0, 0, -0.3)))
	_posts(gx, _gooseneck_mesh(), white)
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045; pm.bottom_radius = 0.055; pm.height = RAIL_H; pm.radial_segments = 6; pm.rings = 1
	var ox: Array = []
	for xf in outer: ox.append((xf as Transform3D).translated_local(Vector3(0, RAIL_H / 2.0, 0)))
	_posts(ox, pm, white)


# ---------------- poles, lines, gates ----------------
func _box(size: Vector3, xf: Transform3D, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	mi.material_override = m
	mi.transform = xf
	(parent if parent != null else root).add_child(mi)
	return mi

## frame at a point on a path: x = along track, y = up, z = across (outward)
func _frame(f: Callable, t: float, off: float, dh := 0.0) -> Transform3D:
	var p: Vector3 = f.call(t, off, dh)
	var fwd: Vector3 = (f.call(t + 1.0, off, dh) - f.call(t - 1.0, off, dh))
	fwd.y = 0.0
	fwd = fwd.normalized()
	var outw: Vector3 = (f.call(t, off + 1.0, dh) - p)
	outw.y = 0.0
	outw = outw.normalized()
	return Transform3D(Basis(fwd, Vector3.UP, outw), p)

func _label(text: String, pos: Vector3, size := 96, color := Color.WHITE, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.position = pos
	root.add_child(l)
	return l

func _build_markers() -> void:
	var W: float = T.width
	var lp := Callable(self, "loop3")
	# furlong poles every 200 m back from the post (inside rail)
	var k := 1
	var total: float = (T.finish + 60.0) if T.straight else T.C
	while k * 200.0 < total - 50.0:
		var s: float = T.finish - 200.0 * k
		if T.straight and s < -60.0: break
		var fr := _frame(lp, fposmod(s, T.C) if not T.straight else s, -1.4)
		_box(Vector3(0.12, 3.2, 0.12), fr.translated_local(Vector3(0, 1.6, 0)), Color.WHITE)
		var band := Color("e5484d") if k % 2 == 1 else Color("2f6fd0")
		_box(Vector3(0.9, 0.6, 0.08), fr.translated_local(Vector3(0, 3.0, 0)), band)
		_label(str(200 * k), fr.origin + Vector3(0, 3.9, 0), 110)
		k += 1
	# distance numbers mown/painted into the grass of the home straight, every 100 m (read from the stand side)
	var m := 100
	while m <= 600:
		var sm: float = T.finish - m
		if T.straight and sm < 0.0: break
		var gf := _frame(lp, fposmod(sm, T.C) if not T.straight else sm, W * 0.72)
		var gl := Label3D.new()
		gl.text = str(m)
		gl.font_size = 900; gl.pixel_size = 0.01
		gl.outline_size = 0
		gl.modulate = Color(0.12, 0.3, 0.1, 0.45)
		gl.shaded = false; gl.double_sided = true
		gl.transform = Transform3D(gf.basis * Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.FORWARD, -PI / 2.0), gf.origin + Vector3(0, 0.06, 0))
		root.add_child(gl)
		m += 100
	# finish post (inside) with the round red-and-white board, judge's box (outside), line across the track
	var fp := _frame(lp, T.finish, -1.8)
	_box(Vector3(0.18, 5.0, 0.18), fp.translated_local(Vector3(0, 2.5, 0)), Color.WHITE)
	var disk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9; cm.bottom_radius = 0.9; cm.height = 0.06
	disk.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("e5484d")
	disk.material_override = dm
	disk.transform = Transform3D(fp.basis * Basis(Vector3.RIGHT, PI / 2.0), fp.origin + Vector3(0, 5.2, 0))
	root.add_child(disk)
	_label("GOAL", fp.origin + Vector3(0, 6.6, 0), 160, Color("ffdf6e"))
	var jb := _frame(lp, T.finish, W + 6.0)
	_box(Vector3(3.0, 5.5, 3.0), jb.translated_local(Vector3(0, 2.75, 0)), Color("e9e4d6"))
	_box(Vector3(3.4, 0.3, 3.4), jb.translated_local(Vector3(0, 5.6, 0)), Color("7d838b"))
	_ribbon(lp, T.finish - 0.15, T.finish + 0.15, 0.3, -0.3, W + 0.3, 0.05, _flat(Color(0.98, 0.98, 0.98)), 1)
	# start line (race distance 0) and gates 5 m behind it
	var sl := Callable(self, "race3")
	_ribbon(sl, -0.12, 0.12, 0.24, -0.3, W + 0.3, 0.05, _flat(Color(0.98, 0.98, 0.98)), 1)

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_gates() -> void:
	var n := race.runners.size()
	var sl := Callable(self, "race3")
	var g := Node3D.new()
	g.name = "StartingGate"
	root.add_child(g)
	gate_node = g
	var fr := _frame(sl, -RaceEngine.CAL.GATE, 0.0)
	g.transform = fr
	var stall := 1.15
	var w0 := 0.8 - stall / 2.0 - 0.3
	var w1 := 0.8 + (n - 1) * stall + stall / 2.0 + 0.3
	var green := Color("2e7d4f")
	_box(Vector3(2.6, 0.35, w1 - w0), Transform3D(Basis(), Vector3(-0.4, 2.7, (w0 + w1) / 2.0)), green, g)
	for i in n + 1:
		var z := 0.8 - stall / 2.0 + i * stall
		_box(Vector3(2.6, 2.6, 0.08), Transform3D(Basis(), Vector3(-0.4, 1.3, z)), green.lightened(0.15), g)
	for i in n:
		var z := 0.8 + i * stall
		var door := _box(Vector3(0.06, 1.7, stall - 0.12), Transform3D(Basis(), Vector3(0.9, 1.15, z)), Color("dfe7e2"), g)
		gate_doors.append(door)
		var lab := Label3D.new()
		lab.text = str(i + 1)
		lab.font_size = 64
		lab.pixel_size = 0.008
		lab.position = Vector3(1.0, 2.75, z)
		lab.rotation.y = PI / 2.0
		lab.modulate = UiTheme.silk(i)
		lab.outline_size = 10
		g.add_child(lab)

func open_gates() -> void:
	for d in gate_doors: d.visible = false

## the gate is towed off the track once the field has gone
func remove_gates(on: bool) -> void:
	if gate_node != null: gate_node.visible = not on


# ---------------- grandstand + crowd ----------------
var crowd_mat: ShaderMaterial              # shared by every spectator; race_3d sets "excite" (0..1)
var leaf_mm: MultiMesh                     # tree crowns: WeatherFX strips or colours them by season

func set_excite(v: float) -> void:
	if crowd_mat != null: crowd_mat.set_shader_parameter("excite", clampf(v, 0.0, 1.0))

func set_clock(t: float) -> void:
	if crowd_mat != null: crowd_mat.set_shader_parameter("clock", t)

## stepped seating: rows of (tread depth d, riser h) from (z0, y0); one mesh, seat-row shading in the shader
func _tier(g: Node3D, L: float, z0: float, y0: float, rows: int, d: float, h: float, mat: Material) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tops: Array = []
	for k in rows:
		var z := z0 + k * d
		var y := y0 + k * h
		var q := [Vector3(-L / 2.0, y, z), Vector3(L / 2.0, y, z), Vector3(L / 2.0, y + h, z), Vector3(-L / 2.0, y + h, z)]   # riser (faces the track)
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_uv(Vector2(q[i].x, 0.0)); st.set_normal(Vector3(0, 0, -1)); st.add_vertex(q[i])
		var t := [Vector3(-L / 2.0, y + h, z), Vector3(L / 2.0, y + h, z), Vector3(L / 2.0, y + h, z + d), Vector3(-L / 2.0, y + h, z + d)]   # tread
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(t[i].x, 1.0)); st.set_normal(Vector3.UP); st.add_vertex(t[i])
		tops.append(Vector2(z + d * 0.55, y + h))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	g.add_child(mi)
	return tops

static func _person_mesh() -> ArrayMesh:
	# body (legs+torso) as a tapered box, head as an octahedron. Height 1.7 m standing. ~28 triangles.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := func(c: Vector3, sx: float, sy: float, sz: float, top_k: float) -> void:
		var v: Array = []
		for yy in [-1.0, 1.0]:
			var k: float = top_k if yy > 0.0 else 1.0
			for zz in [-1.0, 1.0]:
				for xx in [-1.0, 1.0]: v.append(c + Vector3(xx * sx * k, yy * sy, zz * sz * k))
		var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
		for f in faces:
			for i in [0, 1, 2, 0, 2, 3]: st.add_vertex(v[f[i]])
	box.call(Vector3(0, 0.45, 0), 0.15, 0.45, 0.11, 1.0)      # legs
	box.call(Vector3(0, 1.2, 0), 0.21, 0.32, 0.13, 0.85)      # torso
	var hc := Vector3(0, 1.62, 0)
	var o := [Vector3(0.11, 0, 0), Vector3(-0.11, 0, 0), Vector3(0, 0.13, 0), Vector3(0, -0.11, 0), Vector3(0, 0, 0.11), Vector3(0, 0, -0.11)]
	for tri in [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]:
		for i in tri: st.add_vertex(hc + o[i])
	st.generate_normals()
	return st.commit()

func _crowd_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform float excite = 0.0;
uniform float clock = 0.0;          // the scene's own clock: stops when the race is paused
varying vec3 shirt;
varying float part;
void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float lively = INSTANCE_CUSTOM.y;                 // how much this person reacts
	part = VERTEX.y > 1.5 ? 2.0 : (VERTEX.y > 0.88 ? 1.0 : 0.0);
	float sway = sin(clock * (1.1 + lively) + ph) * 0.03 * VERTEX.y;
	float e = excite * lively;
	float jump = e * max(0.0, sin(clock * (5.0 + 2.0 * lively) + ph)) * 0.22;
	VERTEX.x += sway + e * 0.06 * sin(clock * 7.0 + ph) * step(0.9, VERTEX.y);
	VERTEX.y += jump;
	shirt = COLOR.rgb;
}
void fragment() {
	if (length(VERTEX) < 9.0) discard;            // nobody blocks a camera standing in the crowd
	vec3 skin = vec3(0.86, 0.68, 0.55);
	vec3 legs = mix(vec3(0.12, 0.13, 0.18), shirt * 0.4, 0.3);
	ALBEDO = part > 1.5 ? skin : (part > 0.5 ? shirt : legs);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _crowd(g: Node3D, spots: Array) -> void:
	if spots.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var shirts := [Color("f4f4f2"), Color("1d1f24"), Color("2e4a7d"), Color("b23a3a"), Color("d9b54a"), Color("3b6b45"), Color("8a8f98"), Color("e07a2f"), Color("6b4c9a"), Color("c9d6e6"), Color("2a2a2a"), Color("f1e3c6")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _person_mesh()
	mm.instance_count = spots.size()
	mm.visible_instance_count = int(ceil(spots.size() * clampf(float(Settings.get_v("crowd")), 0.1, 1.0)))   # crowd size setting (front rows first)
	for k in spots.size():
		var sp: Array = spots[k]           # [position, seated?]
		var hs := rng.randf_range(0.92, 1.08)
		var b := Basis(Vector3.UP, PI + rng.randf_range(-0.35, 0.35)).scaled(Vector3(hs, hs * (0.72 if sp[1] else 1.0), hs))
		mm.set_instance_transform(k, Transform3D(b, sp[0]))
		mm.set_instance_color(k, shirts[rng.randi() % shirts.size()].darkened(rng.randf_range(0.0, 0.25)))
		mm.set_instance_custom_data(k, Color(rng.randf(), rng.randf_range(0.3, 1.0), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = crowd_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mmi)

func _build_grandstand() -> void:
	var W: float = T.width
	var lp := Callable(self, "loop3")
	var s0: float = maxf(-40.0 if T.straight else 5.0, T.finish - 320.0)
	var s1: float = minf(T.S - 5.0 if not T.straight else T.finish + 80.0, T.finish + 70.0)
	if s1 - s0 < 80.0: return
	var go := 34.0 if T.surface == "dirt" else 0.0       # dirt course: turf course lies between the track and the stand
	var sm := (s0 + s1) / 2.0
	var L := s1 - s0
	var fr := _frame(lp, sm, W + 14.0 + go)
	var h0: float = maxf(RaceEngine.elevation(s0), RaceEngine.elevation(s1)) - 0.2
	fr.origin.y = h0
	var g := Node3D.new()
	g.name = "Grandstand"
	g.transform = fr
	root.add_child(g)
	crowd_mat = _crowd_material()
	var concrete := Color("d3d0c8")
	var seat_mat := ShaderMaterial.new()
	var ssh := Shader.new()
	ssh.code = """
shader_type spatial;
uniform vec3 seat : source_color;
uniform vec3 conc : source_color;
void fragment() {
	// treads: rows of seats (coloured backs every 0.55 m); risers: plain concrete
	float s = step(0.25, fract(UV.x / 0.55));
	ALBEDO = UV.y > 0.5 ? mix(conc, seat, s * 0.85) : conc * 0.86;
	ROUGHNESS = 0.8;
}
"""
	seat_mat.shader = ssh
	seat_mat.set_shader_parameter("seat", Color("2f5fa8"))
	seat_mat.set_shader_parameter("conc", concrete)
	var spots: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# apron by the rail (z < 0 is towards the track; the outer rail is ~14 m in front)
	_box(Vector3(L + 30.0, 0.3, 16.0), Transform3D(Basis(), Vector3(0, 0.1, -6.0)), Color("bdb9b0"), g)
	var x := -L / 2.0
	while x < L / 2.0:
		var dens := 0.85 if absf(x - (T.finish - sm)) < 120.0 else 0.35          # thickest near the winning post
		for row in 6:
			if rng.randf() < dens * (1.0 - row * 0.12):
				spots.append([Vector3(x + rng.randf_range(-0.2, 0.2), 0.25, -12.2 + row * 0.75 + rng.randf_range(-0.15, 0.15)), false])
		x += 0.62
	# lower tier (open terraces), concourse with glass front, upper tier, roof, back block
	var lower := _tier(g, L, 2.0, 0.0, 22, 0.85, 0.42, seat_mat)
	var upper := _tier(g, L * 0.92, 24.0, 15.0, 16, 0.9, 0.62, seat_mat)
	for set in [[lower, L], [upper, L * 0.92]]:
		for r in set[0]:
			var xx: float = -float(set[1]) / 2.0 + 0.3
			while xx < float(set[1]) / 2.0 - 0.3:
				if rng.randf() < 0.62: spots.append([Vector3(xx, (r as Vector2).y, (r as Vector2).x), true])
				xx += 0.55
	_crowd(g, spots)
	# concourse: glass curtain wall between the tiers
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.32, 0.45, 0.55)
	glass.metallic = 0.6; glass.roughness = 0.08
	var gm := MeshInstance3D.new()
	var gb := BoxMesh.new(); gb.size = Vector3(L, 5.8, 0.3)
	gm.mesh = gb; gm.material_override = glass
	gm.position = Vector3(0, 12.2, 21.0)
	g.add_child(gm)
	_box(Vector3(L, 0.6, 3.5), Transform3D(Basis(), Vector3(0, 9.4, 20.5)), concrete, g)
	_box(Vector3(L, 0.6, 4.0), Transform3D(Basis(), Vector3(0, 15.1, 22.0)), concrete, g)
	var mx := -L / 2.0
	while mx <= L / 2.0:
		_box(Vector3(0.25, 5.8, 0.45), Transform3D(Basis(), Vector3(mx, 12.2, 20.8)), Color("e9e9e9"), g)
		mx += 6.0
	# back block with windows
	_box(Vector3(L, 34.0, 10.0), Transform3D(Basis(), Vector3(0, 17.0, 43.5)), concrete.darkened(0.1), g)
	for row in 4:
		var wb := MeshInstance3D.new()
		var wm := BoxMesh.new(); wm.size = Vector3(L - 8.0, 2.0, 0.2)
		wb.mesh = wm; wb.material_override = glass
		wb.position = Vector3(0, 6.0 + row * 7.0, 48.6)
		g.add_child(wb)
	# cantilevered roof over both tiers, sloping down towards the track, with a white fascia and the course name
	var roof := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-6.0)), Vector3(0, 33.0, 24.0))
	_box(Vector3(L + 8.0, 0.8, 46.0), roof, Color("eef0f2"), g)
	_box(Vector3(L + 8.0, 2.6, 0.6), Transform3D(Basis(), Vector3(0, 30.4, 1.2)), Color("f6f7f8"), g)
	var cx := -L / 2.0
	while cx <= L / 2.0:
		_box(Vector3(0.9, 34.0, 0.9), Transform3D(Basis(), Vector3(cx, 17.0, 38.0)), Color("e4e4e4"), g)
		cx += 24.0
	for side in [-1.0, 1.0]:
		_box(Vector3(10.0, 36.0, 48.0), Transform3D(Basis(), Vector3(side * (L / 2.0 + 5.0), 18.0, 24.0)), concrete.darkened(0.05), g)
	var lab := Label3D.new()
	lab.text = race.course.short.to_upper() + " RACECOURSE"
	lab.font_size = 256
	lab.pixel_size = 0.0085
	lab.modulate = Color("1f5130")
	lab.outline_size = 0
	lab.position = Vector3(0, 30.4, 0.85)
	lab.rotation.y = PI
	lab.double_sided = false
	g.add_child(lab)
	_stand = { "s0": s0, "s1": s1 }
	_build_paddock(g, L)


# ---------------- paddock (behind the stand, like Tokyo's) ----------------
## Oval walking ring: two straights of length 2*PA joined by half circles of radius PR (centre line).
## Horses walk on the ring led by their grooms; the lawn in the middle; flowers, hedge and rail outside;
## spectators on stepped terraces all round; a big results screen at one end.
const PA := 24.0
const PR := 17.0
var paddock: Node3D                          # local frame: x along the ring, z across, y up; centre at the origin

## point on the ring at fraction t (0..1, anticlockwise seen from above), off = metres outwards from the centre line
static func ring_point(t: float, off: float) -> Vector3:
	var P := 4.0 * PA + 2.0 * PI * PR
	var d := fposmod(t, 1.0) * P
	var r := PR + off
	if d < 2.0 * PA: return Vector3(-PA + d, 0.0, -r)
	d -= 2.0 * PA
	if d < PI * PR:
		var a := -PI / 2.0 + d / PR
		return Vector3(PA + cos(a) * r, 0.0, sin(a) * r)
	d -= PI * PR
	if d < 2.0 * PA: return Vector3(PA - d, 0.0, r)
	d -= 2.0 * PA
	var b := PI / 2.0 + d / PR
	return Vector3(-PA + cos(b) * r, 0.0, sin(b) * r)

static func ring_length() -> float:
	return 4.0 * PA + 2.0 * PI * PR

## flat band between two offsets (a ring strip), at height y
func _ring_band(parent: Node3D, o0: float, o1: float, y: float, mat: Material, n := 160) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		var t0 := float(k) / n; var t1 := float(k + 1) / n
		var q := [ring_point(t0, o0), ring_point(t0, o1), ring_point(t1, o1), ring_point(t1, o0)]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q[i].x, q[i].z) * 0.25)
			st.add_vertex(q[i] + Vector3(0, y, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)

## vertical wall around the ring at offset o, from y0 to y1
func _ring_wall(parent: Node3D, o: float, y0: float, y1: float, mat: Material, n := 160) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		var a := ring_point(float(k) / n, o); var b := ring_point(float(k + 1) / n, o)
		var q := [a + Vector3(0, y0, 0), b + Vector3(0, y0, 0), b + Vector3(0, y1, 0), a + Vector3(0, y1, 0)]
		for i in [0, 1, 2, 0, 2, 3]: st.add_vertex(q[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_paddock(g: Node3D, L: float) -> void:
	var pk := Node3D.new()
	pk.name = "Paddock"
	pk.position = Vector3(0, 0.05, 48.5 + 10.0 + PR + 16.0)
	g.add_child(pk)
	paddock = pk
	# ground: a concrete plaza under everything
	_box(Vector3(2.0 * (PA + PR) + 60.0, 0.2, 2.0 * PR + 56.0), Transform3D(Basis(), Vector3(0, -0.12, 0)), Color("c8c4ba"), pk)
	# lawn in the middle
	var lawn := ShaderMaterial.new()
	var lsh := Shader.new()
	lsh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float band = step(0.5, fract(wp.x / 6.0));
	ALBEDO = mix(vec3(0.24, 0.48, 0.2), vec3(0.29, 0.55, 0.24), band) * (0.93 + 0.1 * hash(floor(wp.xz * 3.0)));
	ROUGHNESS = 0.9;
}
"""
	lawn.shader = lsh
	_ring_band(pk, -PR, -3.2, 0.03, lawn)
	_box(Vector3(2.0 * PA, 0.06, 0.01), Transform3D(Basis(), Vector3(0, 0.03, 0)), Color("4f8a3a"), pk)
	var lab := Label3D.new()
	lab.text = race.course.short.to_upper().split(" ")[0] + " RACE COURSE"
	lab.font_size = 220; lab.pixel_size = 0.016
	lab.modulate = Color(1, 1, 1, 0.92); lab.outline_size = 0
	lab.rotation = Vector3(-PI / 2.0, PI, 0)                  # reads the right way up from the stand side
	lab.position = Vector3(0, 0.08, 2.0)
	pk.add_child(lab)
	# walking ring (rubber, tan) with a green band on each side, flowers, hedge, rail
	_ring_band(pk, -3.2, -2.6, 0.04, _mat(Color("2f7b5e")))
	_ring_band(pk, -2.6, 2.8, 0.04, _mat(Color("d9ad7c")))
	_ring_band(pk, 2.8, 3.8, 0.04, _mat(Color("2f7b5e")))
	var cols := [Color("f2c94c"), Color("e2558f"), Color("d83a3a"), Color("f2c94c")]
	for k in 4: _ring_band(pk, 3.8 + k * 0.45, 4.25 + k * 0.45, 0.12, _flower_mat(cols[k]), 200)
	_ring_wall(pk, 5.7, 0.0, 0.9, _mat(Color("2c5a26")))
	_ring_band(pk, 5.7, 6.4, 0.9, _mat(Color("2c5a26")))
	_ring_wall(pk, 6.6, 0.0, 1.1, _mat(Color("6e6a62")))
	# advertising/banner boards on the outer wall
	var banner := ShaderMaterial.new()
	var bs := Shader.new()
	bs.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float hash(float x) { return fract(sin(x * 91.7) * 4375.85); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float k = floor((wp.x + wp.z) / 2.4);
	float h = hash(k);
	vec3 c = h < 0.2 ? vec3(0.85, 0.15, 0.2) : (h < 0.4 ? vec3(0.1, 0.3, 0.7) : (h < 0.6 ? vec3(0.95, 0.95, 0.92) : (h < 0.8 ? vec3(0.15, 0.55, 0.3) : vec3(0.95, 0.75, 0.15))));
	ALBEDO = c;
	ROUGHNESS = 0.6;
}
"""
	banner.shader = bs
	_ring_wall(pk, 6.62, 0.15, 1.0, banner)
	# terraces: 7 steps rising outwards, crowd standing on them
	var spots: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var conc := _mat(Color("d5d1c8"))
	for k in 7:
		var o0 := 7.0 + k * 1.0
		var y := 0.25 + k * 0.42
		_ring_wall(pk, o0, y - 0.42, y, conc)
		_ring_band(pk, o0, o0 + 1.0, y, conc)
		var n := int(ring_length() / 0.62)
		for i in n:
			if rng.randf() < 0.78 - k * 0.05:
				var pnt := ring_point(float(i) / n + rng.randf_range(-0.002, 0.002), o0 + 0.5 + rng.randf_range(-0.2, 0.2))
				spots.append([pnt + Vector3(0, y, 0), false, pnt])
	_crowd_facing(pk, spots)
	_ring_wall(pk, 14.0, 0.0, 3.5, conc)
	# big results/odds screen at the far end (like Tokyo's paddock screen)
	var sx := PA + PR + 18.0
	_box(Vector3(1.2, 9.0, 1.2), Transform3D(Basis(), Vector3(sx, 4.5, -6.0)), Color("8d939b"), pk)
	_box(Vector3(1.2, 9.0, 1.2), Transform3D(Basis(), Vector3(sx, 4.5, 6.0)), Color("8d939b"), pk)
	_box(Vector3(1.4, 11.0, 24.0), Transform3D(Basis(), Vector3(sx, 13.0, 0)), Color("e05a1e"), pk)
	_box(Vector3(0.2, 9.4, 21.0), Transform3D(Basis(), Vector3(sx - 0.72, 13.0, 0)), Color("1a1f2a"), pk)
	for r in 8:
		_box(Vector3(0.05, 0.5, 18.0), Transform3D(Basis(), Vector3(sx - 0.84, 9.4 + r * 1.05, 0)), Color("f4c430") if r % 3 == 0 else Color("cfe3ff"), pk)
	# footbridge and steps at the stand end, trees at the far end
	_box(Vector3(2.0 * PA + 30.0, 1.2, 4.0), Transform3D(Basis(), Vector3(0, 7.0, -(PR + 15.0))), Color("bfc4c9"), pk)
	for x in range(-int(PA) - 10, int(PA) + 11, 12):
		_box(Vector3(0.6, 7.0, 0.6), Transform3D(Basis(), Vector3(x, 3.5, -(PR + 15.0))), Color("9aa0a6"), pk)

## spectators that face the paddock centre (spot[2] = their point on the ring)
func _crowd_facing(parent: Node3D, spots: Array) -> void:
	if spots.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var shirts := [Color("f4f4f2"), Color("1d1f24"), Color("2e4a7d"), Color("b23a3a"), Color("d9b54a"), Color("3b6b45"), Color("8a8f98"), Color("e07a2f"), Color("c9d6e6"), Color("f1e3c6")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _person_mesh()
	mm.instance_count = spots.size()
	mm.visible_instance_count = int(ceil(spots.size() * clampf(float(Settings.get_v("crowd")), 0.1, 1.0)))
	for k in spots.size():
		var p: Vector3 = spots[k][0]
		var look := Vector3(-p.x * 0.3, 0, -p.z)
		var ang := atan2(look.x, look.z) + rng.randf_range(-0.4, 0.4)
		var hs := rng.randf_range(0.92, 1.08)
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, ang).scaled(Vector3(hs, hs, hs)), p))
		mm.set_instance_color(k, shirts[rng.randi() % shirts.size()].darkened(rng.randf_range(0.0, 0.25)))
		mm.set_instance_custom_data(k, Color(rng.randf(), rng.randf_range(0.1, 0.4), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = crowd_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


# ---------------- lake, trees ----------------
func _build_lake() -> void:
	if T.straight: return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 0.1; cm.radial_segments = 48
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.42, 0.62)
	m.roughness = 0.08
	m.metallic = 0.25
	mi.material_override = m
	mi.scale = Vector3(_lake_a * 1.05, 1.0, _lake_b * 1.05)
	mi.position = Vector3(0, water_level, 0)
	root.add_child(mi)

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var xs: Array = []
	var W: float = T.width
	var tries := 0
	while xs.size() < 520 and tries < 8000:
		tries += 1
		var x := rng.randf_range(_bounds.position.x + 20.0, _bounds.end.x - 20.0)
		var y := rng.randf_range(_bounds.position.y + 20.0, _bounds.end.y - 20.0)
		var so := s_off(x, y)
		var ok: bool = so.y > W + 90.0 or (not T.straight and so.y < -45.0 and so.y > -T.r * 0.62)
		if not ok: continue
		if _in_stand_zone(so): continue
		if not T.straight:
			var e := (x / _lake_a) * (x / _lake_a) + (y / _lake_b) * (y / _lake_b)
			if e < 1.3: continue
			if screen_zone.has_point(Vector2(x, y)): continue
		if race.chute.has("L"):
			var a := RaceEngine.race_xy(race, -60.0, W / 2.0)
			var b := RaceEngine.race_xy(race, race.chute.L, W / 2.0)
			var ab := b - a
			var t := clampf((Vector2(x, y) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if (Vector2(x, y) - (a + ab * t)).length() < W + 30.0: continue
		xs.append([Vector3(x, height_at(x, y), -y), rng.randf_range(0.7, 1.35), rng.randf(), rng.randf_range(0.0, TAU)])
	# broadleaf trees: three overlapping leafy crowns; conifers: stacked cones. Per-tree colour variation.
	var crown := SphereMesh.new()
	crown.radius = 1.0; crown.height = 1.7; crown.radial_segments = 10; crown.rings = 6
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.bottom_radius = 1.0; cone.height = 1.0; cone.radial_segments = 9; cone.rings = 1
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22; trunk.bottom_radius = 0.38; trunk.height = 1.0; trunk.radial_segments = 6; trunk.rings = 1
	var leaf: Array = []
	var con: Array = []
	var trk: Array = []
	for t in xs:
		var p: Vector3 = t[0]
		var sc: float = t[1]
		var kind: float = t[2]
		var rot := Basis(Vector3.UP, t[3])
		var tint := Color.from_hsv(lerpf(0.24, 0.32, fposmod(kind * 7.3, 1.0)), lerpf(0.45, 0.7, kind), lerpf(0.22, 0.38, fposmod(kind * 3.1, 1.0)))
		if kind < 0.72:
			trk.append([Transform3D(rot.scaled(Vector3(sc, 3.4 * sc, sc)), p + Vector3(0, 1.7 * sc, 0)), Color("5a4532")])
			for c in [[Vector3(0, 5.6, 0), 3.4], [Vector3(1.6, 4.6, 0.6), 2.5], [Vector3(-1.4, 4.9, -0.9), 2.7], [Vector3(0.2, 7.0, 0.3), 2.2]]:
				var r: float = c[1] * sc
				leaf.append([Transform3D(rot.scaled(Vector3(r, r * 0.85, r)), p + rot * (c[0] * sc)), tint.lightened(0.06 * fposmod(r, 1.0))])
		else:
			trk.append([Transform3D(rot.scaled(Vector3(sc * 0.7, 2.0 * sc, sc * 0.7)), p + Vector3(0, 1.0 * sc, 0)), Color("4b3a2a")])
			for k in 3:
				var hgt := (6.5 - k * 1.6) * sc
				con.append([Transform3D(rot.scaled(Vector3((2.6 - k * 0.65) * sc, hgt, (2.6 - k * 0.65) * sc)), p + Vector3(0, (2.0 + k * 2.6) * sc + hgt / 2.0, 0)), tint.darkened(0.25)])
	for set in [[leaf, crown], [con, cone], [trk, trunk]]:
		var items: Array = set[0]
		if items.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = set[1]
		mm.instance_count = items.size()
		for k in items.size():
			mm.set_instance_transform(k, items[k][0]); mm.set_instance_color(k, items[k][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if set[1] == crown: leaf_mm = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.95
		mmi.material_override = m
		root.add_child(mmi)


# ---------------- infield: Turf Vision, flower beds, hedges ----------------
var screen_mat: StandardMaterial3D        # race_3d puts the live picture on it
var screen_zone := Rect2()                 # 2D area kept clear of trees
var screen_xf := Transform3D()

func _in_stand_zone(so: Vector2) -> bool:
	if _stand.is_empty(): return false
	return so.x > _stand.s0 - 40.0 and so.x < _stand.s1 + 40.0 and so.y > T.width and so.y < T.width + 190.0

func _build_infield() -> void:
	var W: float = T.width
	var lp := Callable(self, "loop3")
	var inner_off := -30.0 if (T.surface != "dirt" and not T.straight) else -8.0     # inside any inner course
	# Turf Vision: giant screen in the infield opposite the stand, facing it (JRA Tokyo: about 66 x 11 m)
	if not T.straight:
		var ss: float = clampf(T.finish - 90.0, 40.0, T.S - 40.0)
		var fr := _frame(lp, ss, inner_off - 25.0)
		fr.origin.y = RaceEngine.elevation(ss) - 0.2
		var g := Node3D.new()
		g.name = "TurfVision"
		g.transform = fr
		root.add_child(g)
		var sw := minf(56.0, T.S * 0.22)
		var sh := sw / 5.6
		for x in [-sw * 0.3, sw * 0.3]:
			_box(Vector3(1.2, 7.0, 1.2), Transform3D(Basis(), Vector3(x, 3.5, -0.6)), Color("8d939b"), g)
		_box(Vector3(sw + 1.6, sh + 1.6, 1.0), Transform3D(Basis(), Vector3(0, 7.0 + sh / 2.0, -0.6)), Color("23272d"), g)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(sw, sh)
		q.mesh = qm
		screen_mat = StandardMaterial3D.new()
		screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		screen_mat.albedo_color = Color(0.08, 0.12, 0.2)
		q.material_override = screen_mat
		q.position = Vector3(0, 7.0 + sh / 2.0, -0.08)
		g.add_child(q)
		var lab := Label3D.new()
		lab.text = "TURF VISION"
		lab.font_size = 200; lab.pixel_size = 0.012
		lab.modulate = Color("e9f0ff"); lab.outline_size = 0
		lab.position = Vector3(0, 7.0 + sh + 1.6, -0.05)
		g.add_child(lab)
		screen_xf = g.global_transform if g.is_inside_tree() else fr
		var c2 := RaceEngine.xy(ss, inner_off - 25.0)
		screen_zone = Rect2(c2 - Vector2(sw, sw) * 0.7, Vector2(sw, sw) * 1.4)
		# flower beds in front of the screen
		var cols := [Color("d8364a"), Color("f2c94c"), Color("f4f1ea"), Color("9b5de5")]
		for k in 4:
			_ribbon(lp, ss - sw * 0.45, ss + sw * 0.45, 2.0, inner_off - 4.0 - k * 1.6, inner_off - 5.2 - k * 1.6, 0.06, _flower_mat(cols[k]), 1)
	# low hedge outside the outer rail, broken where the stand and apron are
	var hedge := StandardMaterial3D.new()
	hedge.albedo_color = Color("2c4f24"); hedge.roughness = 1.0
	var off := W + (34.0 if T.surface == "dirt" else 0.0) + 4.0
	var t0 := -60.0 if T.straight else 0.0
	var t1 := _loop_end()
	var segs: Array = []
	if _stand.is_empty(): segs = [[t0, t1]]
	else: segs = [[t0, _stand.s0 - 30.0], [_stand.s1 + 30.0, t1]]
	for sg in segs:
		if sg[1] - sg[0] < 10.0: continue
		_rail(lp, sg[0], sg[1], off + 0.7, hedge, [], 0.5, 0.65, 0.0)

func _flower_mat(c: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 col : source_color;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float h = hash(floor(wp.xz * 5.0));
	ALBEDO = mix(vec3(0.16, 0.3, 0.12), col, step(0.35, h)) * (0.85 + 0.25 * hash(floor(wp.xz * 9.0)));
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", c)
	return m

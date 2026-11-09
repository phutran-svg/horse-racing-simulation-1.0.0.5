class_name HorseLook
## The new horse (ChatGPT's Meshy master, 43-bone rig) and its appearance.
##
## The coat & marking system was authored procedurally in Blender (horse_master_walk_trot_gallop.blend). Procedural
## Blender nodes do not export, so each look was baked once from that file into the shared UV layout:
##   coats/      six full coats (black, bay, dark bay, gray, white, chestnut) — dark points, muzzle, mottling included
##   marks/head_*   ten face markings as colour+alpha overlays (white hair, pink-white skin where they reach the nose)
##   marks/legs_*   four leg heights (coronet, pastern, sock, stocking) as overlays, all four legs
##   marks/leg_regions  one channel per leg (LF R, RF G, LH B, RH A) so each leg gets its own height
##   face_detail    normal-map strength (weakens the old blaze ridge baked into the source normals)
## One shader combines them per horse. Greys blend birth colour → gray → white with age (Markings.grey_level).
## Coat and markings come from the horse's saved data (Markings.of); no race RNG is used.

const DIR := "res://assets/models/horse43/"
const MODEL := DIR + "horse43.glb"
const HEIGHT := 2.32                 # metres to the ear tips (≈1.63 m at the withers), same as the old horse
const ANIM := { "walk": "Walk_Smooth_Loop", "trot": "Trot_Smoothed_Original", "gallop": "Gallop_Power_Smooth" }
## the owner's improved trot (horse_shared_original_trot.blend): frames 1–38.5 at 60 fps; its last pose differs from
## the first by up to 0.35 rad in a few leg bones, so the end eases into the start pose over the last 0.1 s
const TROT_LEN := 37.5 / 60.0
const TROT_BLEND := 0.1
static var _trot_fixed := false
const SADDLE_BONE := "Bone_005"       # mid-back
## game face id -> baked overlay
const FACE_TEX := { "star": "star", "stripe": "stripe", "star_stripe": "star_stripe", "snip": "snip", "star_snip": "star_snip",
	"blaze": "blaze", "blaze_snip": "irregular_blaze", "bald": "blaze", "interrupted_stripe": "interrupted_stripe",
	"irregular_blaze": "irregular_blaze", "star_stripe_snip": "star_stripe_snip", "star_streak": "kitasan_inspired_star_streak" }
const LEG_TEX := ["", "coronet", "pastern", "sock", "stocking"]
const COAT_TEX := { "bay": "bay", "dark bay": "dark_bay", "dark_bay": "dark_bay", "chestnut": "chestnut", "black": "black", "grey": "gray", "gray": "gray", "white": "white" }

static var _scene: PackedScene
static var _shader: Shader
static var _tex := {}
static var _scale := 0.0

static func scene() -> PackedScene:
	if _scene == null: _scene = load(MODEL)
	return _scene

static func tex(path: String) -> Texture2D:
	if not _tex.has(path): _tex[path] = load(DIR + path)
	return _tex[path]

## uniform scale that makes the model HEIGHT tall: measured once from the skeleton's rest pose (the poll bone sits
## a little below the ear tips, hence 1.04)
static func model_scale(model: Node3D) -> float:
	if _scale > 0.0: return _scale
	var sk := skeleton(model)
	var top := 0.0
	if sk != null:
		var xf := _xf_to(model, sk)
		for b in sk.get_bone_count(): top = maxf(top, (xf * sk.get_bone_global_rest(b).origin).y)
	_scale = HEIGHT / maxf(0.1, top * 1.04)
	return _scale

static func _xf_to(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D: xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf

## a model ready to use: scaled, every mesh given this horse's coat, animations set to loop
static func make(h: Dictionary) -> Node3D:
	var model: Node3D = scene().instantiate()
	var s := model_scale(model)
	model.scale = Vector3.ONE * s
	var mat := material(h)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	var ap: AnimationPlayer = anim_player(model)
	if ap != null:
		for a in ap.get_animation_list():
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if not _trot_fixed:          # imported clips are shared resources: fix the trot once
			_trot_fixed = true
			_close_loop(ap.get_animation(anim_name(ap, "trot")), TROT_LEN, TROT_BLEND)
	return model

## make a clip loop seamlessly: length = one cycle, the last `blend` seconds ease each track back to its first key
static func _close_loop(a: Animation, length: float, blend: float) -> void:
	if a == null: return
	a.length = length
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		var n := a.track_get_key_count(t)
		if n < 2: continue
		var v0 = a.track_get_key_value(t, 0)
		for k in n:
			var tm := a.track_get_key_time(t, k)
			if tm > length + 1e-4: continue
			var w := smoothstep(length - blend, length, tm)
			if w <= 0.0: continue
			var v = a.track_get_key_value(t, k)
			if ty == Animation.TYPE_ROTATION_3D: a.track_set_key_value(t, k, (v as Quaternion).slerp(v0, w))
			elif ty == Animation.TYPE_POSITION_3D or ty == Animation.TYPE_SCALE_3D: a.track_set_key_value(t, k, (v as Vector3).lerp(v0, w))
		# keys past the cycle end are dropped
		for k in range(n - 1, -1, -1):
			if a.track_get_key_time(t, k) > length + 1e-4: a.track_remove_key(t, k)

static func anim_player(model: Node) -> AnimationPlayer:
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	return aps[0] if not aps.is_empty() else null

static func skeleton(model: Node) -> Skeleton3D:
	var s := model.find_children("*", "Skeleton3D", true, false)
	return s[0] if not s.is_empty() else null

static func anim_name(ap: AnimationPlayer, gait: String) -> String:
	var want: String = ANIM.get(gait, "")
	var stem := "_".join(want.split("_").slice(0, 2))      # Godot drops a "_Loop" suffix on import (and loops the clip)
	for a in ap.get_animation_list():
		if String(a) == want or String(a).begins_with(stem): return a
	return ap.get_animation_list()[0] if not ap.get_animation_list().is_empty() else ""

static func material(h: Dictionary) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform sampler2D coat_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D coat_b : source_color, filter_linear_mipmap, repeat_disable;   // grey: dappled gray
uniform sampler2D coat_c : source_color, filter_linear_mipmap, repeat_disable;   // grey: white
uniform float grey = -1.0;          // < 0 not grey; 0 dark youngster … 1 nearly white
uniform sampler2D head_ov : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_head = false;
uniform sampler2D leg1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leg2 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leg3 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leg4 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D regions : filter_linear_mipmap, repeat_disable;
uniform ivec4 legs = ivec4(0);      // LF RF LH RH: 0 none, 1 coronet, 2 pastern, 3 sock, 4 stocking
uniform sampler2D nmap : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : filter_linear_mipmap;
uniform sampler2D face_detail : filter_linear_mipmap;
uniform float wet = 0.0;            // rain: darker, glossier coat
vec4 leg_ov(int lv, vec2 uv) {
	if (lv == 1) return texture(leg1, uv);
	if (lv == 2) return texture(leg2, uv);
	if (lv == 3) return texture(leg3, uv);
	return texture(leg4, uv);
}
void fragment() {
	vec3 c = texture(coat_a, UV).rgb;
	if (grey >= 0.0) {
		c = mix(c, texture(coat_b, UV).rgb, smoothstep(0.0, 0.45, grey));
		c = mix(c, texture(coat_c, UV).rgb, smoothstep(0.45, 1.0, grey));
	}
	if (has_head) { vec4 o = texture(head_ov, UV); c = mix(c, o.rgb, o.a); }
	vec4 rg = texture(regions, UV);
	for (int k = 0; k < 4; k++) {
		int lv = legs[k];
		if (lv > 0) { vec4 o = leg_ov(lv, UV); c = mix(c, o.rgb, o.a * rg[k]); }
	}
	float r = max(texture(rough_tex, UV).g, 0.42);
	c *= mix(1.0, 0.72, wet);
	ALBEDO = c;
	ROUGHNESS = mix(r, 0.3, wet);
	SPECULAR = mix(0.4, 0.6, wet);
	NORMAL_MAP = texture(nmap, UV).rgb;
	NORMAL_MAP_DEPTH = clamp(texture(face_detail, UV).r, 0.25, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	var coat := String(h.get("coat", "bay"))
	var gl := -1.0
	if coat == "grey":
		gl = Markings.grey_level(h) if h.has("age") else 0.5
		m.set_shader_parameter("coat_a", tex("coats/dark_bay.jpg"))      # greys are born coloured
		m.set_shader_parameter("coat_b", tex("coats/gray.jpg"))
		m.set_shader_parameter("coat_c", tex("coats/white.jpg"))
	else:
		m.set_shader_parameter("coat_a", tex("coats/%s.jpg" % COAT_TEX.get(coat, "bay")))
	m.set_shader_parameter("grey", gl)
	var mk: Dictionary = Markings.of(h) if h.has("id") else h.get("marks", { "face": "none", "legs": [0, 0, 0, 0] })
	var ft: String = FACE_TEX.get(String(mk.get("face", "none")), "")
	m.set_shader_parameter("has_head", ft != "")
	if ft != "": m.set_shader_parameter("head_ov", tex("marks/head_%s.png" % ft))
	var lv: Array = mk.get("legs", [0, 0, 0, 0])
	m.set_shader_parameter("legs", Vector4i(int(lv[0]), int(lv[1]), int(lv[2]), int(lv[3])))
	for k in 4:
		m.set_shader_parameter("leg%d" % (k + 1), tex("marks/legs_%s.png" % LEG_TEX[k + 1]))
	m.set_shader_parameter("regions", tex("marks/leg_regions.png"))
	m.set_shader_parameter("nmap", tex("normal.png"))
	m.set_shader_parameter("rough_tex", tex("roughness_metal.jpg"))
	m.set_shader_parameter("face_detail", tex("face_detail.png"))
	return m

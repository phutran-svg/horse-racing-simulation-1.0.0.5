class_name JockeyLook
extends RefCounted
## The rider and the owners' silks (Step 7 art from ChatGPT).
##
## Rider: assets/models/jockey — a Mixamo-rigged jockey with a riding crop and five clips made to sit on the
## horse43 model at the same origin and scale: Ride, Push (hands-and-heels drive), Crop_Right (one stroke every
## two strides) and the two transitions. Every clip is one gallop stride (0.5 s; the crop clip two), so the rider
## is driven from the horse's gallop phase and blends between clips at the same phase (no foot-skate, no seam).
## The clips start at frame 1 (1/60 s) and end on a closing frame equal to the first.
##
## Silks: assets/jockey_silks — 40 UV-mapped outfit textures (25 Japan, 5 USA, 5 Europe, 5 Hong Kong): stylised,
## unofficial reconstructions of real owners' registered colours. Owners without a catalogue design get their game
## colours painted on the shirt and cap (masks + fabric shading). In JRA races the cap is the bracket colour.

const MODEL := "res://assets/models/jockey/jockey_race_animations.glb"
const DIR := "res://assets/jockey_silks/"
const SHADER := preload("res://race3d/jockey_silk.gdshader")
const FRAME0 := 1.0 / 60.0          # clips start at Blender frame 1
const STRIDE := 0.5                 # clip length = one gallop stride
const RIDE := "Jockey_Race_Ride"
const PUSH := "Jockey_Race_Push"
const CROP := "Jockey_Race_Crop_Right"
const HEAD_BONE := "Bone_021"                     # horse43 head
const BIT := Vector3(0.095, 2.04, 1.42)            # bit ring (near side; x mirrored) in the horse mesh's bind space
## the rein lies over the sides of the neck on its way back to the hands: [neck bone, m up, m out from the centre line]
const REIN_PATH := [["Bone_023", 0.10, 0.16]]

## catalogue silks for the game's owners (by name, so older saves find them too)
const OWNER_SILK := {
	"Sunday Racing": "jp_sunday", "Silk Racing": "jp_silk", "Carrot Farm": "jp_carrot", "Shadai Race Horse": "jp_shadai",
	"G1 Racing": "jp_g1", "Tokyo Horse Racing": "jp_tokyo", "Lord Horse Club": "jp_lord", "Win Racing Club": "jp_win",
	"Hiroo Racing": "jp_hiroo", "Danox": "jp_danox", "Kaneko Makoto Holdings": "jp_kaneko",
	"North Hills": "jp_north_hills", "Hajime Satomi": "jp_satomi", "DMM Dream Club": "jp_dmm", "Thoroughbred Club Ruffian": "jp_ruffian",
	"Normandy Thoroughbred Racing": "jp_normandy", "Ono Shoji": "jp_kitasan", "Symboli Stud": "jp_symboli",
	"Masatsugu Takezono": "jp_tm", "Eishindo": "jp_eishindo", "Susumu Fujita": "jp_fujita", "Ryotokuji Kenji Holdings": "jp_tesoro",
}
## overseas raiders: catalogue silks by training region (Godolphin and Shadwell race from Dubai too)
const REGION_SILKS := {
	"EUR": ["eu_godolphin", "eu_juddmonte", "eu_coolmore_tabor", "eu_aga_khan", "eu_shadwell"],
	"USA": ["us_winstar", "us_spendthrift", "us_klaravich", "us_stonestreet", "us_calumet"],
	"HK": ["hk_golden_sixty", "hk_romantic_warrior", "hk_beauty", "hk_ka_ying", "hk_california"],
	"MEA": ["eu_godolphin", "eu_shadwell"],
}

static var _book := {}
static var _scene: PackedScene
static var _mats := {}
static var _tex := {}

static func catalog() -> Dictionary:
	if _book.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog.json"))
		if j is Dictionary:
			for e in j.get("entries", []): _book[String(e.id)] = e
	return _book

static func entry(id: String) -> Dictionary:
	return catalog().get(id, {})

static func ids(region := "") -> Array:
	var out: Array = []
	for id in catalog():
		if region == "" or String(catalog()[id].region) == region: out.append(id)
	return out

## catalogue silk for an owner record ("" = none: use its game colours)
static func owner_silk(o: Dictionary) -> String:
	if o.is_empty(): return ""
	if o.has("silkId"): return String(o.silkId)
	var nm := String(o.get("name", ""))
	return String(OWNER_SILK.get(nm, ""))

## the catalogue silk a runner wears ("" = paint its game silks instead)
static func silk_for(h: Dictionary) -> String:
	if h.has("silkId"): return String(h.silkId)
	var hid := int(h.get("id", 0))
	if h.get("foreign") != null:
		var l: Array = REGION_SILKS.get(String(h.foreign), [])
		return "" if l.is_empty() else String(l[absi(hid * 2654435761) % l.size()])
	if Game.mode == "career":
		if Career.W.has("stable") and Career.W.stable.has(hid) and String(h.get("c", {}).get("owner", "")) == "": return ""
		return owner_silk(Owners.of(h))
	var jp := ids("JP")                                    # quick races: a Japanese owner's colours
	return String(jp[absi(hid * 2654435761 + 7) % jp.size()]) if not jp.is_empty() else ""

## the catalogue design in the game's silk vocabulary (2D previews, TV graphics)
static func game_silks(id: String) -> Dictionary:
	var e := entry(id)
	if e.is_empty(): return {}
	var g = e.get("existing_game_parameters")
	if g is Dictionary and g.has("body"): return g.duplicate()
	var body_ok := Silks.BODY.any(func(b): return b[0] == String(e.pattern))
	var sl_ok := Silks.SLEEVE.any(func(b): return b[0] == String(e.spattern))
	return { "body": String(e.body), "pattern": String(e.pattern) if body_ok else "plain", "pcol": String(e.pcol),
		"sleeve": String(e.sleeve), "spattern": String(e.spattern) if sl_ok else "plain", "scol": String(e.scol) }

## 2D silk for race graphics: ChatGPT's flat jacket (ui/shirts) with the cap layer on top — the JRA bracket cap
## (ui/jra_caps, 1–8) in Japan, the owner's own cap (ui/cap_layers) when bracket is 0. Owners without a catalogue
## design get the game's generated jacket with the same cap rule. 256×222, cached.
static var _ui := {}
static func ui_icon(id: String, sd: Dictionary, bracket: int) -> Texture2D:
	var key := "%s|%d|%s" % [id, bracket, str(sd) if id == "" else ""]
	if _ui.has(key): return _ui[key]
	var tex: Texture2D = null
	var shirt := DIR + "ui/shirts/%s.png" % id
	if id != "" and ResourceLoader.exists(shirt):
		var img: Image = (load(shirt) as Texture2D).get_image()
		if img.is_compressed(): img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var cp := DIR + ("ui/jra_caps/bracket_%d.png" % bracket if bracket >= 1 and bracket <= 8 else "ui/cap_layers/%s.png" % id)
		if ResourceLoader.exists(cp):
			var cap: Image = (load(cp) as Texture2D).get_image()
			if cap.is_compressed(): cap.decompress()
			cap.convert(Image.FORMAT_RGBA8)
			img.blend_rect(cap, Rect2i(Vector2i.ZERO, cap.get_size()), Vector2i.ZERO)
		tex = ImageTexture.create_from_image(img)
	else:
		var cap_hex: String = Silks.CAPS[bracket - 1] if bracket >= 1 and bracket <= 8 else String(sd.get("sleeve", sd.get("body", "#f4f4f2")))
		tex = Silks.preview(sd, 128, 111, cap_hex)
	_ui[key] = tex
	return tex

## jacket-only picture path for rich text ([img]) — "" when the owner has no catalogue design
static func shirt_path(id: String) -> String:
	var p := DIR + "ui/shirts/%s.png" % id
	return p if id != "" and ResourceLoader.exists(p) else ""

static func _load(p: String) -> Resource:
	if not _tex.has(p): _tex[p] = HorseLook._fetch(p)
	return _tex[p]

## start loading the rider and the shared textures in the background (menus call this with HorseLook.warm_up)
static func warm_up() -> void:
	for f in [MODEL, DIR + "textures/shared_normal.png", DIR + "textures/shared_packed_pbr.png", DIR + "textures/fabric_shading.png",
			DIR + "textures/cap_mask.png", DIR + "textures/shirt_tint_mask.png", DIR + "textures/base_albedo.jpg"]:
		if ResourceLoader.exists(f) and not HorseLook._warm.has(f) and ResourceLoader.load_threaded_request(f, "", true) == OK:
			HorseLook._warm[f] = true

static func make() -> Node3D:
	if _scene == null: _scene = HorseLook._fetch(MODEL)
	return _scene.instantiate()

## body material: catalogue silk `id`, else the game silks `sd` painted on; `bracket` 1–8 = JRA cap colour, 0 = owner's cap
static func material(id: String, sd: Dictionary, bracket: int, cap_hex := "") -> ShaderMaterial:
	var key := "%s|%s|%d|%s" % [id, str(sd) if id == "" else "", bracket, cap_hex]
	if _mats.has(key): return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var t := DIR + "textures/"
	var e := entry(id)
	m.set_shader_parameter("albedo_tex", _load(DIR + String(e.albedo)) if not e.is_empty() else _load(t + "base_albedo.jpg"))
	m.set_shader_parameter("normal_tex", _load(t + "shared_normal.png"))
	m.set_shader_parameter("pbr_tex", _load(t + "shared_packed_pbr.png"))
	m.set_shader_parameter("shade_tex", _load(t + "fabric_shading.png"))
	m.set_shader_parameter("shirt_mask", _load(t + "shirt_tint_mask.png"))
	m.set_shader_parameter("cap_mask", _load(t + "cap_mask.png"))
	if e.is_empty():
		m.set_shader_parameter("tint_shirt", 1.0)
		m.set_shader_parameter("shirt_col", Color(String(sd.get("body", "#f4f4f2"))))
	if bracket >= 1 and bracket <= 8:
		m.set_shader_parameter("cap_tex", _load(t + "jra_cap_%d.png" % bracket))
		m.set_shader_parameter("use_cap_tex", 1.0)
	elif e.is_empty():                                      # overseas race, game silks: the owner's cap colour
		m.set_shader_parameter("tint_cap", 1.0)
		m.set_shader_parameter("cap_col", Color(cap_hex if cap_hex != "" else String(sd.get("sleeve", sd.get("body", "#f4f4f2")))))
	_mats[key] = m
	return m

## Drives one rider from the horse's gallop phase: ride / push / crop weights eased towards the race state.
class Rider:
	extends RefCounted
	var root: Node3D
	var tree: AnimationTree
	var body: MeshInstance3D
	var w_push := 0.0
	var w_crop := 0.0
	var skel: Skeleton3D
	var _hand := PackedInt32Array()     # left / right grip bones (middle finger base)
	var reins: Array = []               # [bit side, MeshInstance3D] for the near and off side
	var _last_p := 0.0
	var _cycle := 0          # stride count (the crop clip spans two strides)

	func _init(parent: Node3D) -> void:
		root = JockeyLook.make()
		parent.add_child(root)
		body = root.find_child("Jockey_Body", true, false) as MeshInstance3D
		skel = root.find_children("*", "Skeleton3D", true, false)[0]
		_hand = PackedInt32Array([skel.find_bone("mixamorig_LeftHandMiddle1"), skel.find_bone("mixamorig_RightHandMiddle1")])
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var bt := AnimationNodeBlendTree.new()
		var x := 0.0
		for nm in [["ride", JockeyLook.RIDE], ["push", JockeyLook.PUSH], ["crop", JockeyLook.CROP]]:
			var an := AnimationNodeAnimation.new(); an.animation = nm[1]
			bt.add_node(nm[0], an, Vector2(x, 0))
			var sk := AnimationNodeTimeSeek.new()
			bt.add_node(nm[0] + "_t", sk, Vector2(x + 200, 0))
			bt.connect_node(nm[0] + "_t", 0, nm[0])
			x += 400
		bt.add_node("rp", AnimationNodeBlend2.new(), Vector2(1400, 0))
		bt.connect_node("rp", 0, "ride_t"); bt.connect_node("rp", 1, "push_t")
		bt.add_node("c", AnimationNodeBlend2.new(), Vector2(1700, 0))
		bt.connect_node("c", 0, "rp"); bt.connect_node("c", 1, "crop_t")
		bt.connect_node("output", 0, "c")
		tree = AnimationTree.new()
		tree.tree_root = bt
		root.add_child(tree)
		tree.anim_player = tree.get_path_to(ap)
		tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		tree.active = true

	## reins (not in the rider export): a thin strap from each bit ring to the hands, rebuilt every frame from both
	## skeletons. While the crop is up the jockey holds both reins in the left hand.
	func add_reins(horse_skel: Skeleton3D, head_bone: String, parent: Node3D) -> void:
		var hb := horse_skel.find_bone(head_bone)
		if hb < 0 or _hand[0] < 0 or _hand[1] < 0: return
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("2a1a10"); mat.roughness = 0.7
		var mesh := BoxMesh.new(); mesh.size = Vector3(0.022, 0.006, 1.0)       # a flat leather strap, stretched along z
		# bit point given in the horse mesh's bind space -> head-bone space through the skin's bind pose
		var inv := horse_skel.get_bone_global_rest(hb).affine_inverse()
		for hm in parent.find_children("*", "MeshInstance3D", true, false):
			var sk: Skin = (hm as MeshInstance3D).skin
			if sk == null: continue
			var found := false
			for i in sk.get_bind_count():
				if sk.get_bind_name(i) == head_bone: inv = sk.get_bind_pose(i); found = true
			if found: break
		var nb := PackedInt32Array()
		for e in JockeyLook.REIN_PATH: nb.append(horse_skel.find_bone(e[0]))
		for side in [-1.0, 1.0]:
			var segs: Array = []
			for j in nb.size() + 1:                       # bit -> along the neck -> hand
				var mi := MeshInstance3D.new()
				mi.mesh = mesh; mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(mi)
				segs.append(mi)
			reins.append({ "skel": horse_skel, "bone": hb, "bit": inv * (JockeyLook.BIT * Vector3(side, 1, 1)), "segs": segs,
				"neck": nb, "side": side })

	func _update_reins() -> void:
		if not skel.is_inside_tree(): return
		for k in reins.size():
			var r: Dictionary = reins[k]
			var hs: Skeleton3D = r.skel
			var a: Vector3 = hs.global_transform * (hs.get_bone_global_pose(r.bone) * (r.bit as Vector3))
			var hand_l := skel.global_transform * skel.get_bone_global_pose(_hand[0]).origin
			var hand_r := skel.global_transform * skel.get_bone_global_pose(_hand[1]).origin
			# off-side rein (x < 0) to the right hand, near-side to the left; crop up = both in the left hand
			var b: Vector3 = hand_r.lerp(hand_l, w_crop) if k == 0 else hand_l
			# the rein runs over the side of the neck (a straight line would cut through it)
			var nk: PackedInt32Array = r.neck
			var gx := hs.global_transform
			var prev := a
			for j in nk.size():
				var e: Array = JockeyLook.REIN_PATH[j]
				var w: Vector3 = gx * hs.get_bone_global_pose(nk[j]).origin + gx.basis.y.normalized() * float(e[1]) \
					+ gx.basis.x.normalized() * float(e[2]) * float(r.side)
				_strap(r.segs[j], prev, w)
				prev = w
			_strap(r.segs[nk.size()], prev, b)

	static func _strap(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
		var d := b - a
		if d.length() < 0.01: return
		var z := d.normalized()
		var x := z.cross(Vector3.UP).normalized() if absf(z.y) < 0.99 else Vector3.RIGHT
		mi.global_transform = Transform3D(Basis(x, z.cross(x), z * d.length()), (a + b) * 0.5)

	func set_silks(m: Material) -> void:
		if body != null: body.material_override = m

	## p: horse gallop phase 0..1; mode 0 ride, 1 push, 2 crop; dt: frame time (for easing)
	func update(p: float, mode: int, dt: float) -> void:
		if p < _last_p - 0.5: _cycle += 1
		_last_p = p
		w_push = move_toward(w_push, 1.0 if mode >= 1 else 0.0, dt / 0.35)
		# the crop clip starts and ends at the push pose; only switch it on or off at the start of its two strides
		var want_crop := mode == 2
		if want_crop != (w_crop > 0.5) and (_cycle % 2 == 0) and p < 0.15: w_crop = 0.51 if want_crop else 0.49
		w_crop = move_toward(w_crop, 1.0 if w_crop > 0.5 else 0.0, dt / 0.12)
		var t := JockeyLook.FRAME0 + p * JockeyLook.STRIDE
		tree.set("parameters/ride_t/seek_request", t)
		tree.set("parameters/push_t/seek_request", t)
		tree.set("parameters/crop_t/seek_request", JockeyLook.FRAME0 + (float(_cycle % 2) + p) * JockeyLook.STRIDE)
		tree.set("parameters/rp/blend_amount", w_push)
		tree.set("parameters/c/blend_amount", w_crop)
		tree.advance(0.0)
		if not reins.is_empty(): _update_reins()

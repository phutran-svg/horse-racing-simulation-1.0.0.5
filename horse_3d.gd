class_name Horse3D
extends Node3D
## One runner in 3D: the toon horse model with its coat, a racing saddle and numbered saddle cloth (JRA gate
## colour), the jockey (JockeyLook: owner's silks, JRA bracket cap; ride / push / crop clips locked to the stride)
## and the gallop/trot/walk animation timed from the engine (gallop cycles per second = stride frequency).

const SADDLE_BONE := HorseLook.SADDLE_BONE
const SADDLE_LIFT := 0.24       # back surface above the mid-back bone (m)
const SADDLE_Z := 0.0
const WALK_STRIDE := 1.75       # metres per walk cycle (1.3 s clip)
const TROT_STRIDE := 2.4        # metres per trot cycle (0.625 s clip)

var ap: AnimationPlayer
var skel: Skeleton3D
var model: Node3D
var anim := ""
var gait := ""
var number_label: Label3D
var _phase := 0.0
var _saddle := Vector3.ZERO      # top of the back under the saddle, in this node's space
var _to_skel := Transform3D.IDENTITY
var rider: JockeyLook.Rider
var ride_mode := 0               # 0 sitting, 1 pushing, 2 using the crop (set by the race scene each frame)

## the new 43-bone horse (HorseLook): walk, trot and gallop clips, the baked coat & marking system
func setup(h: Dictionary, number: int, phase: float) -> void:
	model = HorseLook.make(h)
	add_child(model)
	_phase = phase
	ap = HorseLook.anim_player(model)
	skel = HorseLook.skeleton(model)
	_to_skel = model.transform * HorseLook._xf_to(model, skel)
	var bi := skel.find_bone(SADDLE_BONE)
	_saddle = (_to_skel * skel.get_bone_global_rest(bi)).origin
	var sd: Dictionary = h.get("silks", Silks.default_for(String(h.get("color", "#ffffff"))))
	_add_saddle(UiTheme.silk(number - 1), number, String(h.get("name", "")))
	rider = JockeyLook.Rider.new(model)            # same origin and scale as the horse (made together in Blender)
	rider.add_reins(skel, JockeyLook.HEAD_BONE, self)
	rider.set_silks(JockeyLook.material(String(h.get("silkId", "")), sd, int(h.get("bracket", 0)), String(h.get("ownCap", ""))))
	_set_gait("gallop")
	ap.seek(_phase * ap.get_animation(anim).length, true); ap.speed_scale = 0.0
	_ride()

func _set_gait(g: String) -> void:
	if g == gait: return
	gait = g
	var nm := HorseLook.anim_name(ap, g)
	if nm == anim: return
	var pos := 0.0
	if anim != "": pos = ap.current_animation_position / maxf(0.01, ap.get_animation(anim).length)
	anim = nm
	ap.play(anim, 0.25)                  # short blend between gaits
	ap.seek(pos * ap.get_animation(anim).length, false)

## nodes attached to the saddle bone; positions given in model space (horse faces +Z, ground at y = 0)
func _add_saddle(cloth: Color, number: int, hname := "") -> void:
	var bi := skel.find_bone(SADDLE_BONE)
	var att := BoneAttachment3D.new()
	att.bone_name = SADDLE_BONE
	skel.add_child(att)
	# points below are in the old horse's frame (saddle top at y 1.52, z -0.12); move them onto this horse's back
	var inv := (_to_skel * skel.get_bone_global_rest(bi)).affine_inverse() \
		* Transform3D(Basis.IDENTITY, Vector3(0, _saddle.y + SADDLE_LIFT - 1.52, _saddle.z + SADDLE_Z + 0.12))
	var put := func(mesh: Mesh, pos: Vector3, rot: Vector3, color: Color) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		mi.material_override = m
		mi.transform = inv * Transform3D(Basis.from_euler(rot), pos)
		att.add_child(mi)
		return mi
	var box := func(sz: Vector3) -> BoxMesh:
		var b := BoxMesh.new(); b.size = sz; return b
	if HorseLook.add_saddle(model) != null:
		# number and name on the saddle's side panels (measured from the fitted saddle: the panel's outer face leans
		# in ~27° and sits about 0.33 m out at 1.07 m), carried by the saddle bone
		var bone_xf := _to_skel * skel.get_bone_global_rest(bi)
		for side in [-1.0, 1.0]:
			var a := 0.47
			var n := Vector3(cos(a) * side, sin(a), 0.0)
			var up := Vector3(-sin(a) * side, cos(a), 0.0)
			var b := Basis(up.cross(n), up, n)
			for t in [[str(number), 64, 0.0023, Vector3(0.362 * side, 1.42, -0.35)], [hname, 32, 0.00085, Vector3(0.33 * side, 1.505, -0.35)]]:
				if String(t[0]) == "": continue
				var lab := Label3D.new()
				lab.text = String(t[0])
				lab.font_size = int(t[1])
				lab.pixel_size = float(t[2])
				lab.modulate = Color(0.97, 0.97, 0.95)
				lab.outline_size = 0
				lab.double_sided = false
				lab.transform = bone_xf.affine_inverse() * Transform3D(b, t[3] + n * 0.006)
				att.add_child(lab)
	else:                                                   # fallback: the old box saddle and cloth
		for side in [-1.0, 1.0]:
			put.call(box.call(Vector3(0.03, 0.34, 0.58)), Vector3(0.345 * side, 1.40, -0.12), Vector3(0, 0, -0.12 * side), cloth)
		put.call(box.call(Vector3(0.46, 0.04, 0.6)), Vector3(0, 1.52, -0.12), Vector3.ZERO, cloth)
		put.call(box.call(Vector3(0.3, 0.07, 0.36)), Vector3(0, 1.56, -0.08), Vector3.ZERO, Color("3a2a1e"))
	number_label = Label3D.new()
	number_label.text = str(number)
	number_label.font_size = 128
	number_label.pixel_size = 0.012
	number_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number_label.no_depth_test = true
	number_label.fixed_size = false
	number_label.outline_size = 18
	number_label.modulate = cloth if cloth.get_luminance() > 0.2 else Color.WHITE
	number_label.position = Vector3(0, 3.4, 0)
	number_label.visible = false
	add_child(number_label)

## v (m/s), sf (strides/s); in_gate = still behind the doors. Only a gallop clip exists for this model:
## standing still = clip paused; slower paces play the gallop slowly (pre-race canter is off-camera).
var _frozen := false

## whole-scene pause: legs stop where they are and carry on from there
func freeze(on: bool) -> void:
	_frozen = on
	if ap != null and on: ap.speed_scale = 0.0

## the rider follows the horse's stride phase (its clips are one gallop stride long)
func _ride() -> void:
	if rider == null or ap == null or anim == "": return
	var p := fposmod(ap.current_animation_position / maxf(0.01, ap.get_animation(anim).length), 1.0)
	rider.update(p, ride_mode if gait == "gallop" else 0, get_process_delta_time())

## v (m/s), sf (strides/s); in_gate = still behind the doors. Walk below 4 m/s, trot to 8 m/s, gallop above;
## the gallop clip is one stride, so its speed is the stride frequency from the engine.
func animate(v: float, sf: float, in_gate: bool) -> void:
	if _frozen: return
	_ride()
	if in_gate or v < 0.3:
		_set_gait("walk")
		ap.speed_scale = 0.0
		return
	if v < 4.0:
		_set_gait("walk"); ap.speed_scale = clampf(v / WALK_STRIDE * 1.3, 0.3, 2.0)
	elif v < 8.0:
		_set_gait("trot"); ap.speed_scale = clampf(v / TROT_STRIDE * HorseLook.TROT_LEN, 0.4, 2.0)
	else:
		_set_gait("gallop")
		ap.speed_scale = clampf((sf if sf > 0.0 else v / 15.0 * 2.3) * 0.5, 0.5, 2.0)   # clip = 0.5 s = one stride

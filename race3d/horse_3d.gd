class_name Horse3D
extends Node3D
## One runner in 3D: the toon horse model with its coat, a racing saddle and numbered saddle cloth (JRA gate
## colour), a simple jockey in the runner's silks (placeholder until a jockey model is added), and the
## gallop/trot/walk animation timed from the engine (gallop cycles per second = stride frequency).

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
	_add_saddle_and_jockey(UiTheme.silk(number - 1), number, sd, Color(String(h.get("cap", sd.body))))
	_set_gait("gallop")
	ap.seek(_phase * ap.get_animation(anim).length, true); ap.speed_scale = 0.0

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
func _add_saddle_and_jockey(cloth: Color, number: int, sd: Dictionary, capc: Color) -> void:
	var silk := Color(sd.body)
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
	# saddle cloth (both sides) with the number, racing saddle on top
	for side in [-1.0, 1.0]:
		put.call(box.call(Vector3(0.03, 0.34, 0.58)), Vector3(0.345 * side, 1.40, -0.12), Vector3(0, 0, -0.12 * side), cloth)
		var lab := Label3D.new()
		lab.text = str(number)
		lab.font_size = 96
		lab.pixel_size = 0.0032
		lab.modulate = UiTheme.on_silk(cloth)
		lab.outline_size = 0
		lab.transform = inv * Transform3D(Basis.from_euler(Vector3(0, PI / 2.0 * side, -0.12 * side)), Vector3(0.365 * side, 1.38, -0.27))
		att.add_child(lab)
	put.call(box.call(Vector3(0.46, 0.04, 0.6)), Vector3(0, 1.52, -0.12), Vector3.ZERO, cloth)
	put.call(box.call(Vector3(0.3, 0.07, 0.36)), Vector3(0, 1.56, -0.08), Vector3.ZERO, Color("3a2a1e"))
	# jockey in the racing crouch: limbs as capsules between joint points (model space, horse faces +Z)
	var seg := func(a: Vector3, b: Vector3, r: float, color: Color, tex: Texture2D = null) -> void:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = a.distance_to(b) + 2.0 * r
		c.radial_segments = 10
		c.rings = 2
		var y := (b - a).normalized()
		var x := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
		x = (x - y * x.dot(y)).normalized()
		var mi := MeshInstance3D.new()
		mi.mesh = c
		var m := StandardMaterial3D.new()
		m.albedo_color = color if tex == null else Color.WHITE
		if tex != null: m.albedo_texture = tex
		m.roughness = 0.6
		mi.material_override = m
		mi.transform = inv * Transform3D(Basis(x, y, x.cross(y)), (a + b) / 2.0)
		att.add_child(mi)
	var hips := Vector3(0, 1.82, -0.14)
	var shoulders := Vector3(0, 1.98, 0.30)
	seg.call(shoulders, hips, 0.15, silk, Silks.body_texture(sd))                            # body in the owner's silks
	var head := SphereMesh.new()
	head.radius = 0.095; head.height = 0.19
	var cap := SphereMesh.new()
	cap.radius = 0.11; cap.height = 0.16; cap.is_hemisphere = true
	put.call(head, Vector3(0, 2.07, 0.44), Vector3.ZERO, Color("e0b896"))
	put.call(cap, Vector3(0, 2.1, 0.43), Vector3(-0.2, 0, 0), capc)                         # cap: gate bracket colour (JRA)
	for side in [-1.0, 1.0]:
		seg.call(shoulders + Vector3(0.14 * side, -0.02, 0), Vector3(0.1 * side, 1.74, 0.62), 0.055, silk, Silks.sleeve_texture(sd))   # arms to the reins
		seg.call(hips + Vector3(0.12 * side, 0, 0), Vector3(0.21 * side, 1.73, 0.17), 0.075, Color("f2f2f2"))     # thighs (breeches)
		seg.call(Vector3(0.21 * side, 1.73, 0.17), Vector3(0.23 * side, 1.47, 0.0), 0.06, Color("1d1d1d"))        # boots in the irons
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

## v (m/s), sf (strides/s); in_gate = still behind the doors. Walk below 4 m/s, trot to 8 m/s, gallop above;
## the gallop clip is one stride, so its speed is the stride frequency from the engine.
func animate(v: float, sf: float, in_gate: bool) -> void:
	if _frozen: return
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

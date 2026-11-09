class_name HorsePortrait
extends SubViewportContainer
## Live 3D portrait of one horse for its profile: the Hyper3D model standing square, in the horse's own coat,
## white markings and (for greys) the shade for its age. Turns slowly; drag to rotate it.

var vp: SubViewport
var pivot: Node3D
var _drag := false
var _idle := 0.0

func setup(h: Dictionary, size := Vector2i(230, 170)) -> HorsePortrait:
	stretch = true
	custom_minimum_size = Vector2(size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag to turn the horse"
	vp = SubViewport.new()
	vp.size = size * 2                      # supersampled, then scaled down
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.93, 0.96)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, 40, 0); key.light_energy = 1.15; key.shadow_enabled = true
	vp.add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-15, -140, 0); rim.light_energy = 0.45
	vp.add_child(rim)
	# a soft round patch of ground so the horse stands on something
	var g := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 1.05; cm.bottom_radius = 1.05; cm.height = 0.02; cm.radial_segments = 48
	g.mesh = cm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("cfe0c9")
	g.material_override = gm
	g.scale = Vector3(0.75, 1, 1.25)
	vp.add_child(g)
	pivot = Node3D.new()
	vp.add_child(pivot)
	var model := HorseLook.make(h)
	# foals and yearlings are smaller than horses in training
	var age := int(h.get("age", 3))
	var k: float = { 0: 0.62, 1: 0.82, 2: 0.96 }.get(age, 1.0)
	model.scale *= k
	model.position = Vector3(0, 0, -0.1 * k)
	pivot.add_child(model)
	var ap := HorseLook.anim_player(model)
	if ap != null:          # standing: the first frame of the walk, held
		ap.play(HorseLook.anim_name(ap, "walk")); ap.seek(0.0, true); ap.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(4.9, 1.75 * k + 0.35, 3.9), Vector3(0, 1.08 * k, 0.15))
	pivot.rotation.y = -0.35
	return self

func _process(delta: float) -> void:
	if pivot == null or not is_visible_in_tree(): return
	_idle += delta
	if not _drag and _idle > 1.5: pivot.rotation.y += delta * 0.25

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		_idle = 0.0
	elif e is InputEventMouseMotion and _drag:
		pivot.rotation.y += e.relative.x * 0.012
		_idle = 0.0

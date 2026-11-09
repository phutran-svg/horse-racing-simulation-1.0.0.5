class_name WeatherFX
extends Node3D
## Weather and time of day for the 3D race. References: JRA broadcasts of the Arima Kinen (Nakayama, late December,
## 15:25 — low golden winter sun, long shadows, the stand's shadow over the course, bare trees, crisp air),
## the Tokyo Yushun (late May, ~15:40 — high bright sun, vivid saturated turf, short shadows, light summer haze) and
## the Shuka Sho (Kyoto, October, ~15:40 — warm autumn sun from the side, long shadows, green turf, distant haze).
##
##  • the sun is placed from the date and post time (Weather.sun) with the stands facing north, as at most JRA courses,
##    so winter races are lit from behind the stand and its shadow falls on the track
##  • light colour, strength and shadow softness follow the sun's height and the cloud
##  • sky: procedural sky with a cloud layer (scattered → overcast), warm horizon at low sun
##  • haze: aerial perspective and fog by season and weather; rain closes the distance in
##  • turf by season (winter: overseeded but dry-tipped; summer: deep vivid green); wet tracks darken and shine,
##    the dirt gets puddles that reflect the sky
##  • rain / snow particles around the camera; trees bare or turning by season

var env: Environment
var sun_light: DirectionalLight3D
var tb: TrackBuilder
var cam: Camera3D
var cond := "fine"
var week := 20
var hour := 15.67
var precip: CPUParticles3D
var wet := 0.0
var cover := 0.2

func setup(environment: Environment, sun: DirectionalLight3D, builder: TrackBuilder, camera: Camera3D, opts: Dictionary) -> void:
	env = environment; sun_light = sun; tb = builder; cam = camera
	var o := Weather.complete(opts)
	cond = String(o.weather); week = int(o.week); hour = float(o.hour)
	var going := String(o.get("going", "firm"))
	wet = { "firm": 0.0, "yielding": 0.4, "soft": 0.7, "heavy": 1.0 }.get(going, 0.0)
	if cond in ["rain", "snow"]: wet = maxf(wet, 0.75)
	elif cond in ["light_rain", "light_snow"]: wet = maxf(wet, 0.45)
	cover = { "fine": 0.22, "cloudy": 0.85, "light_rain": 0.95, "rain": 1.0, "light_snow": 0.95, "snow": 1.0 }.get(cond, 0.2)
	_light()
	_sky()
	_surfaces()
	_trees()
	_precip()

func _stand_frame() -> Array:
	# south = towards the grandstand (stands face north); east = up × south
	var T: Dictionary = tb.T
	var south := Vector3(0, 0, 1)
	if tb.race != null:
		var d := float(tb.race.opts.dist)        # the winning post
		var a := tb.race3(d, T.width * 0.5, 0.0)
		var b := tb.race3(d, T.width + 30.0, 0.0)
		south = Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	return [south, Vector3.UP.cross(south).normalized()]

func _light() -> void:
	var s := Weather.sun(week, hour)
	var el := maxf(s.x, 3.0)
	var az := deg_to_rad(s.y)
	var fr := _stand_frame()
	var south: Vector3 = fr[0]; var east: Vector3 = fr[1]
	var north := -south
	var to_sun := (north * cos(az) + east * sin(az)) * cos(deg_to_rad(el)) + Vector3.UP * sin(deg_to_rad(el))
	sun_light.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.98 else Vector3.FORWARD)
	# colour: deep gold near the horizon, warm white high up (AgX tonemapping keeps it from looking orange)
	var k := smoothstep(4.0, 45.0, el)
	var col := Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.76, 0.52), smoothstep(4.0, 16.0, el)).lerp(Color(1.0, 0.96, 0.9), smoothstep(16.0, 48.0, el))
	var clear := 1.0 - smoothstep(0.3, 1.0, cover)
	sun_light.light_color = col.lerp(Color(0.86, 0.9, 0.96), 1.0 - clear)
	sun_light.light_energy = lerpf(1.25, 1.6, k) * lerpf(0.16, 1.0, clear)
	sun_light.light_angular_distance = lerpf(0.6, 12.0, 1.0 - clear)     # overcast: soft, almost no shadow edge
	sun_light.shadow_opacity = lerpf(0.35, 1.0, clear)
	sun_light.directional_shadow_max_distance = 380.0
	# ambient: blue sky fill on fine days, flat grey under cloud; warmer at low sun
	env.ambient_light_energy = lerpf(0.55, 0.95, 1.0 - clear) * lerpf(0.85, 1.0, k)
	env.ambient_light_color = Color(0.78, 0.84, 0.95).lerp(Color(0.85, 0.86, 0.88), 1.0 - clear).lerp(Color(0.95, 0.82, 0.7), (1.0 - k) * 0.5 * clear)
	if clear > 0.5: env.ambient_light_energy *= lerpf(0.7, 1.0, k)      # low sun: deeper shadows, like the winter broadcasts
	env.ambient_light_sky_contribution = lerpf(0.6, 0.3, 1.0 - clear)
	env.tonemap_exposure = lerpf(1.02, 1.2, 1.0 - clear)
	env.adjustment_saturation = lerpf(1.12 if Weather.season(week) == "summer" else 1.06, 0.82, 1.0 - clear)
	env.adjustment_contrast = lerpf(1.08, 0.96, 1.0 - clear)
	env.glow_intensity = lerpf(0.35, 0.12, 1.0 - clear)
	# haze: summer humid, winter crisp but golden at low sun; rain/snow pulls the distance in
	var season := Weather.season(week)
	var haze: float = { "summer": 0.0009, "spring": 0.0007, "autumn": 0.0006, "winter": 0.00045 }.get(season, 0.0006)
	var fogc := Color(0.74, 0.8, 0.88)
	if el < 20.0 and clear > 0.5: fogc = fogc.lerp(Color(0.95, 0.82, 0.66), (1.0 - smoothstep(5.0, 20.0, el)) * 0.6)
	match cond:
		"cloudy": haze *= 1.6; fogc = Color(0.72, 0.75, 0.78)
		"light_rain": haze = 0.0016; fogc = Color(0.6, 0.63, 0.66)
		"rain": haze = 0.0028; fogc = Color(0.56, 0.59, 0.62)
		"light_snow": haze = 0.0018; fogc = Color(0.78, 0.8, 0.84)
		"snow": haze = 0.0032; fogc = Color(0.8, 0.82, 0.86)
	env.fog_enabled = true
	env.fog_density = haze
	env.fog_light_color = fogc
	env.fog_aerial_perspective = lerpf(0.45, 0.15, 1.0 - clear)
	env.fog_sky_affect = lerpf(0.0, 0.6, 1.0 - clear)
	env.ssr_enabled = wet > 0.4          # puddles and wet dirt reflect
	env.ssr_max_steps = 48

func _sky() -> void:
	var sm := env.sky.sky_material as ProceduralSkyMaterial
	if sm == null: return
	var s := Weather.sun(week, hour)
	var low := 1.0 - smoothstep(4.0, 25.0, s.x)
	var clear := 1.0 - smoothstep(0.3, 1.0, cover)
	var top := Color(0.2, 0.4, 0.78).lerp(Color(0.32, 0.45, 0.7), low * 0.4)
	var hor := Color(0.66, 0.77, 0.88).lerp(Color(0.95, 0.8, 0.62), low * 0.7)
	var grey_top := Color(0.5, 0.53, 0.58) if cond in ["cloudy", "light_snow", "snow"] else Color(0.38, 0.41, 0.45)
	var grey_hor := Color(0.7, 0.72, 0.75) if cond in ["cloudy", "light_snow", "snow"] else Color(0.55, 0.58, 0.61)
	sm.sky_top_color = grey_top.lerp(top, clear)
	sm.sky_horizon_color = grey_hor.lerp(hor, clear)
	sm.ground_horizon_color = sm.sky_horizon_color.darkened(0.15)
	sm.sun_angle_max = lerpf(30.0, 8.0, low)
	sm.sun_curve = 0.1
	sm.sky_energy_multiplier = lerpf(0.75, 1.0, clear)
	# cloud layer: tileable noise on the sky dome; scattered cumulus on fine days, a lid of stratus when overcast
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = 5
	n.frequency = 0.004 if cover < 0.5 else 0.0025
	n.seed = week * 17 + int(hour * 10)
	var tex := NoiseTexture2D.new()
	tex.width = 1024; tex.height = 512
	tex.seamless = true
	tex.noise = n
	var g := Gradient.new()
	var thr := lerpf(0.62, 0.05, cover)              # how much of the dome is cloud
	g.set_offset(0, 0.0); g.set_color(0, Color(0, 0, 0, 1))
	g.set_offset(1, 1.0); g.set_color(1, Color(1, 1, 1, 1))
	g.add_point(thr, Color(0, 0, 0, 1))
	g.add_point(minf(1.0, thr + 0.18), Color(1, 1, 1, 1))
	tex.color_ramp = g
	sm.sky_cover = tex
	var cc := Color(1.0, 0.98, 0.95) if clear > 0.5 else (Color(0.62, 0.64, 0.68) if cond in ["rain", "light_rain"] else Color(0.86, 0.87, 0.9))
	if low > 0.4 and clear > 0.5: cc = cc.lerp(Color(1.0, 0.82, 0.62), low * 0.6)
	cc.a = lerpf(0.75, 1.0, cover)
	sm.sky_cover_modulate = cc

func _surfaces() -> void:
	var season := Weather.season(week)
	var turf := TrackBuilder.surface_material(false)
	var dirt := TrackBuilder.surface_material(true)
	# turf colour by season (JRA overseeds with Italian ryegrass, so winter turf stays green but paler and dry-tipped)
	var tc: Array = { "summer": ["24601f", "317428", "7d7a4e"], "spring": ["2d6727", "3b7a31", "7d7a4e"],
		"autumn": ["2f6526", "3d752e", "86794a"], "winter": ["4a6a2c", "5a7a36", "8f8255"] }[season]
	turf.set_shader_parameter("c1", Color(tc[0])); turf.set_shader_parameter("c2", Color(tc[1])); turf.set_shader_parameter("wear", Color(tc[2]))
	turf.set_shader_parameter("wet", wet)
	dirt.set_shader_parameter("wet", wet)
	turf.set_shader_parameter("snow", 0.45 if cond == "snow" else (0.2 if cond == "light_snow" else 0.0))
	dirt.set_shader_parameter("snow", 0.0)

func _trees() -> void:
	if tb.leaf_mm == null: return
	var season := Weather.season(week)
	var mm: MultiMesh = tb.leaf_mm
	if not tb.has_meta("leaf0"):        # keep the summer trees, so a cached course can change season between races
		var xf: Array = []; var cs: Array = []
		for k in mm.instance_count: xf.append(mm.get_instance_transform(k)); cs.append(mm.get_instance_color(k))
		tb.set_meta("leaf0", [xf, cs])
	var orig: Array = tb.get_meta("leaf0")
	for k in mm.instance_count:
		mm.set_instance_transform(k, orig[0][k]); mm.set_instance_color(k, orig[1][k])
	for k in mm.instance_count:
		var c := mm.get_instance_color(k)
		var r := fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)
		match season:
			"winter":
				if r < 0.55:      # deciduous crowns bare: hide; the evergreens stay
					mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), mm.get_instance_transform(k).origin))
				else: c = c.lerp(Color("4d4a2c"), 0.35)
			"autumn":
				if week >= 44 and r < 0.4: c = c.lerp([Color("b8732a"), Color("c99a2e"), Color("9a4a22")][int(r * 30.0) % 3], 0.75)
			"summer": c = c.darkened(0.05)
		mm.set_instance_color(k, c)

func _precip() -> void:
	if not cond in ["light_rain", "rain", "light_snow", "snow"]: return
	var snow := cond.ends_with("snow")
	# CPU particles: same look on every renderer (the Compatibility renderer and old GPUs included)
	precip = CPUParticles3D.new()
	precip.amount = int({ "light_rain": 2500, "rain": 6000, "light_snow": 2000, "snow": 5000 }[cond] * [0.4, 0.7, 1.0][int(Settings.get_v("quality"))])
	precip.lifetime = 1.6 if not snow else 6.0
	precip.preprocess = precip.lifetime
	precip.local_coords = false
	precip.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	precip.emission_box_extents = Vector3(30, 1, 30)
	precip.direction = Vector3(0.12, -1, 0.05)
	precip.spread = 3.0 if not snow else 25.0
	precip.initial_velocity_min = 14.0 if not snow else 0.6
	precip.initial_velocity_max = 17.0 if not snow else 1.2
	precip.gravity = Vector3(0, -9.8, 0) if not snow else Vector3(0.3, -1.1, 0.1)
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.8) if not snow else Vector2(0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if not snow else BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_color = Color(0.85, 0.88, 0.93, 0.45 if cond == "rain" else 0.32) if not snow else Color(1, 1, 1, 0.9)
	q.material = m
	precip.mesh = q
	add_child(precip)
	_screen_layer(snow)

var _veil: ShaderMaterial
var _clock := 0.0

## rain/snow seen through the lens at any distance: a full-screen layer of streaks or flakes under the TV graphics.
## Long lenses (narrow field of view) compress the depth of falling rain, so the layer gets stronger as the lens tightens.
func _screen_layer(snow: bool) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 0                       # the HUD is on layer 1
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float clock = 0.0;
uniform float amount = 0.5;      // 0..1
uniform float snow = 0.0;
uniform float zoom = 1.0;        // 1 wide … 3 long lens
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float layer_rain(vec2 uv, float scale, float speed, float seed) {
	vec2 g = uv * vec2(scale, scale * 0.12);
	g.x += g.y * 0.9;                                    // slant (wind)
	g.y += clock * speed;
	vec2 id = floor(g); vec2 f = fract(g);
	float r = h(id + seed);
	if (r > amount * 0.55) return 0.0;
	float x = abs(f.x - (0.25 + 0.5 * h(id * 1.7 + seed)));
	float streak = smoothstep(0.06, 0.0, x) * smoothstep(0.0, 0.25, f.y) * smoothstep(1.0, 0.6, f.y);
	return streak;
}
float layer_snow(vec2 uv, float scale, float speed, float seed) {
	vec2 g = uv * scale;
	g.y -= clock * speed;
	g.x += sin(clock * 0.7 + g.y * 0.8 + seed) * 0.35;
	vec2 id = floor(g); vec2 f = fract(g);
	if (h(id + seed) > amount * 0.6) return 0.0;
	vec2 c = vec2(h(id * 2.3 + seed), h(id * 5.1 + seed)) * 0.6 + 0.2;
	return smoothstep(0.09, 0.0, length(f - c));
}
void fragment() {
	vec2 uv = UV * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float a = 0.0;
	if (snow > 0.5) {
		a += layer_snow(uv, 9.0 * zoom, 0.35, 1.0) * 0.9;
		a += layer_snow(uv, 16.0 * zoom, 0.22, 7.0) * 0.6;
		a += layer_snow(uv, 30.0 * zoom, 0.12, 3.0) * 0.4;
		COLOR = vec4(1.0, 1.0, 1.0, clamp(a, 0.0, 0.85));
	} else {
		a += layer_rain(uv, 70.0, 2.2, 1.0) * 0.32;
		a += layer_rain(uv, 120.0, 2.9, 5.0) * 0.22;
		a += layer_rain(uv, 200.0, 3.6, 9.0) * 0.14 * zoom;
		a *= mix(0.55, 1.0, (zoom - 1.0) * 0.5);       // wide shots already show the real drops near the camera
		COLOR = vec4(0.86, 0.89, 0.94, clamp(a, 0.0, 0.5));
	}
}
"""
	_veil = ShaderMaterial.new()
	_veil.shader = sh
	_veil.set_shader_parameter("snow", 1.0 if snow else 0.0)
	_veil.set_shader_parameter("amount", { "light_rain": 0.45, "rain": 1.0, "light_snow": 0.5, "snow": 1.0 }[cond])
	cr.material = _veil
	cl.add_child(cr)

## keep the rain/snow box over the camera (it is a world-space system, so motion through it looks right)
func follow(delta: float) -> void:
	if precip == null or cam == null: return
	if _veil != null:
		_clock += delta
		_veil.set_shader_parameter("clock", _clock)
		_veil.set_shader_parameter("zoom", clampf(45.0 / maxf(cam.fov, 8.0), 1.0, 3.0))
	precip.global_position = cam.global_position + Vector3(0, 16.0 if not cond.ends_with("snow") else 9.0, 0) - cam.global_transform.basis.z * 14.0

func freeze(on: bool) -> void:
	if precip != null: precip.speed_scale = 0.0 if on else 1.0

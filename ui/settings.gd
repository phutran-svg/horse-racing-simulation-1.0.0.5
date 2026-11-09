class_name Settings
## Step 6E — player settings, kept between sessions in user://settings.cfg.
## Applied at start (window, frame rate, volume) and read by the 3D scenes (quality, shadows, crowd, weather).

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"quality": 1,          # 0 Low · 1 Medium · 2 High (render resolution, anti-aliasing, effects)
	"shadows": true,
	"crowd": 1.0,          # share of spectators drawn (0.25 … 1)
	"fps": 60,             # frame-rate cap (0 = no cap)
	"vsync": true,
	"fullscreen": false,
	"master": 0.8,         # volumes 0 … 1
	"effects": 1.0,        # hooves, gates, fanfares
	"crowd_vol": 1.0,      # crowd noise and cheering
	"race_names": "both",  # TV graphics: both / en / jp
	"autosave": true,      # weekly autosave (3 rotating)
	"skip_news": true,     # skip-ahead stops for news about your horses
}
const QUALITY := ["Low", "Medium", "High"]
static var S := {}

static func get_v(k: String) -> Variant:
	if S.is_empty(): load_s()
	return S.get(k, DEFAULTS.get(k))

static func set_v(k: String, v: Variant) -> void:
	if S.is_empty(): load_s()
	S[k] = v

static func load_s() -> void:
	S = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			if cf.has_section_key("game", k): S[k] = cf.get_value("game", k)

static func save_s() -> void:
	var cf := ConfigFile.new()
	for k in S: cf.set_value("game", k, S[k])
	cf.save(PATH)

## window, frame rate, master volume (call at start and after changes)
static func apply() -> void:
	Engine.max_fps = int(get_v("fps"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_v("vsync") else DisplayServer.VSYNC_DISABLED)
	if not DisplayServer.get_name().begins_with("headless"):
		var fs: bool = get_v("fullscreen")
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (fs or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(get_v("master")))))

## 3D viewport quality: render scale, anti-aliasing and screen-space effects
static func apply_3d(vp: Viewport, env: Environment = null) -> void:
	var q := int(get_v("quality"))
	vp.scaling_3d_scale = [0.67, 0.85, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	if env != null and q == 0:
		env.ssao_enabled = false
		env.ssr_enabled = false
		env.glow_enabled = false
		env.volumetric_fog_enabled = false

## sound effect volume in dB for a player's base level
static func fx_db(base_db: float, crowd := false) -> float:
	var v := float(get_v("crowd_vol" if crowd else "effects"))
	return base_db + linear_to_db(maxf(0.0001, v))

# ---------------------------------------------------------------- the dialog
static func open_dialog(parent: Node) -> void:
	if S.is_empty(): load_s()
	var dlg := AcceptDialog.new()
	dlg.title = "Settings"
	dlg.ok_button_text = "Done"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 520)
	dlg.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	var head := func(t: String) -> void:
		var l := UiTheme.label(t, 15, UiTheme.ACC)
		v.add_child(l)
	var row := func(t: String, ctl: Control, tip := "") -> void:
		var h := HBoxContainer.new()
		var l := UiTheme.label(t, 13)
		l.custom_minimum_size.x = 230
		h.add_child(l)
		if not (ctl is CheckBox): ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tip != "": ctl.tooltip_text = tip
		h.add_child(ctl)
		if ctl is HSlider:     # the value beside a slider
			var pl := UiTheme.label("%d%%" % int(round((ctl as HSlider).value * 100.0)), 12, UiTheme.DIM)
			pl.custom_minimum_size.x = 44
			(ctl as HSlider).value_changed.connect(func(x): pl.text = "%d%%" % int(round(x * 100.0)))
			h.add_child(pl)
		v.add_child(h)
	var opt := func(key: String, items: Array, values: Array) -> OptionButton:
		var ob := OptionButton.new()
		for it in items: ob.add_item(it)
		var cur = get_v(key)
		ob.select(maxi(0, values.find(cur)))
		ob.item_selected.connect(func(i): set_v(key, values[i]); save_s(); apply())
		return ob
	var chk := func(key: String) -> CheckBox:
		var cb := CheckBox.new()
		cb.button_pressed = bool(get_v(key))
		cb.toggled.connect(func(b): set_v(key, b); save_s(); apply())
		return cb
	var slider := func(key: String, lo: float, hi: float) -> HSlider:
		var s := HSlider.new()
		s.min_value = lo; s.max_value = hi; s.step = 0.05
		s.value = float(get_v(key))
		s.custom_minimum_size.x = 220
		s.value_changed.connect(func(x): set_v(key, x); save_s(); apply())
		return s
	head.call("Graphics")
	row.call("Quality", opt.call("quality", QUALITY, [0, 1, 2]), "Render resolution, anti-aliasing and screen effects in the 3D race, paddock and sale ring.")
	row.call("Shadows", chk.call("shadows"))
	row.call("Crowd size", slider.call("crowd", 0.25, 1.0), "Share of spectators drawn in the stands (fewer = faster).")
	row.call("Frame-rate cap", opt.call("fps", ["30", "60", "120", "No cap"], [30, 60, 120, 0]))
	row.call("V-Sync", chk.call("vsync"))
	row.call("Full screen", chk.call("fullscreen"))
	head.call("Sound")
	row.call("Master volume", slider.call("master", 0.0, 1.0))
	row.call("Race sounds", slider.call("effects", 0.0, 1.0), "Hooves, starting gate and fanfares.")
	row.call("Crowd noise", slider.call("crowd_vol", 0.0, 1.0))
	head.call("Text")
	row.call("Race names on TV graphics", opt.call("race_names", ["English and Japanese", "English", "Japanese"], ["both", "en", "jp"]))
	head.call("Game")
	row.call("Autosave every week", chk.call("autosave"), "Keeps the last 3 weeks as auto_1 … auto_3.")
	row.call("Skip-ahead stops for news", chk.call("skip_news"), "Injuries, offers, caution and retirements of your horses.")
	v.add_child(UiTheme.dim_label("Changes apply at once; the 3D settings take effect the next time a 3D view opens.", 11))
	head.call("Help")
	var br := Button.new()
	br.text = "Create a bug report…"
	br.tooltip_text = "Puts the game logs, your settings and the current career in one zip to send for help."
	br.pressed.connect(func(): BugReport.open_dialog(parent))
	v.add_child(br)
	parent.add_child(dlg)
	dlg.popup_centered()

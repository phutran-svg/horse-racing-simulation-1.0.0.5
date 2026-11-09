extends SceneTree
## Step 4A screenshots: wizard steps, then a career of each kind (Career, Finances, Market, My Stable).
## arg: role (owner/breeder/trainer/young) weeks
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "c_" + name + ".png")
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var who := a[0] if a.size() > 0 else "owner"
	var weeks := int(a[1]) if a.size() > 1 else 30
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	if who == "wizard":
		m.show_menu(); await shot("menu")
		m.wiz = { "country": "JPN" }; m.wiz_step = 0; m._wizard(); await shot("wiz0")
		m.wiz["role"] = "trainer"; m.wiz_step = 1; m._wizard(); await shot("wiz1")
		m.wiz_step = 2; m._wizard(); await shot("wiz2")
		m.wiz_step = 3; m._wizard(); await shot("wiz3")
		quit(); return
	var o := { "role": who, "bg": "pro", "diff": "normal", "name": "Trinh", "stable_name": "Sakura " + { "owner": "Racing", "breeder": "Farm", "trainer": "Stable", "young": "Stable" }[who], "silk": "#ec4899", "package": 2, "center": "ritto" }
	if who == "young": o.role = "trainer"; o.bg = "young"; o.age = 20
	m.create_career(o)
	for w in weeks: Career.advance_week()
	m._show_shell("home")
	var sh = m.screen
	sh.open("career"); await shot(who + "_career")
	sh.open("finances"); await shot(who + "_fin")
	if who in ["owner", "breeder"]:
		sh.open("market"); await shot(who + "_market")
		var mk := Finance.market()
		if not mk.is_empty(): sh.open_horse(int(mk[0].id)); await shot(who + "_buy")
	if who != "young": sh.open("stable"); await shot(who + "_stable")
	sh.open("home"); await shot(who + "_home")
	quit()

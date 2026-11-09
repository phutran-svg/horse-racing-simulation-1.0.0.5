extends SceneTree
var out := "/home/claude/godot/shots/"
func shot(name: String) -> void:
	for i in 4: await process_frame
	root.get_texture().get_image().save_png(out + "m_" + name + ".png")
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var m: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(m)
	await shot("menu")
	m._wizard(); await shot("newcareer")
	m._show(QuickRaceScreen.new()); await shot("quick")
	quit()

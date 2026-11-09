extends Node3D
func _ready():
	var c := Camera3D.new(); c.position = Vector3(0, 30, 60); add_child(c); c.look_at(Vector3.ZERO); c.current = true
	var t: Node3D = ClassDB.instantiate("Terrain3D")
	t.set("free_editor_textures", false)
	t.set("vertex_spacing", 4.0)
	add_child(t)
	print("added")
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RF)
	img.fill(Color(5, 0, 0))
	t.get("data").call("import_images", [img, null, null], Vector3(-128, 0, -128), 0.0, 1.0)
	print("imported")
	for i in 5: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/home/claude/godot/shots/t3d_min.png")
	print("frames ok")
	get_tree().quit()

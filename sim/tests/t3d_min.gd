extends SceneTree
func _init():
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "a"
	await process_frame
	var t: Node3D = ClassDB.instantiate("Terrain3D")
	if mode.contains("f"): t.set("free_editor_textures", false)
	t.set("vertex_spacing", 4.0)
	print("adding")
	root.add_child(t)
	print("added")
	await process_frame
	print("frame ok")
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RF)
	img.fill(Color(1, 0, 0))
	t.get("data").call("import_images", [img, null, null], Vector3(-128, 0, -128), 0.0, 1.0)
	print("imported, regions ", t.get("data").call("get_region_count"))
	for i in 3: await process_frame
	print("done")
	quit()

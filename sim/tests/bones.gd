extends SceneTree
func _init():
	var h: Node3D = load("res://assets/models/horse/Horse.glb").instantiate()
	root.add_child(h)
	var sk: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
	print("skeleton path: ", h.get_path_to(sk), " bones ", sk.get_bone_count())
	for i in sk.get_bone_count():
		var g := sk.get_bone_global_rest(i)
		print("%2d %-16s parent %-16s pos %s" % [i, sk.get_bone_name(i), sk.get_bone_name(sk.get_bone_parent(i)) if sk.get_bone_parent(i) >= 0 else "-", (sk.global_transform * g).origin.snapped(Vector3.ONE * 0.01)])
	var ap: AnimationPlayer = h.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ap.get_animation_list(): print(a, " len ", ap.get_animation(a).length, " loop ", ap.get_animation(a).loop_mode)
	print("tree: ")
	for c in h.find_children("*", "", true, false): print("  ", h.get_path_to(c), " ", c.get_class())
	quit()

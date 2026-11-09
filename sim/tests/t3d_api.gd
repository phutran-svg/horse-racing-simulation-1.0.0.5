extends SceneTree
func _init():
	for c in ["Terrain3D", "Terrain3DData", "Terrain3DAssets", "Terrain3DTextureAsset", "Terrain3DMaterial", "Terrain3DRegion"]:
		if not ClassDB.class_exists(c): print(c, " MISSING"); continue
		var ms := []
		for m in ClassDB.class_get_method_list(c, true):
			if m.name.begins_with("_"): continue
			var args := []
			for a in m.args: args.append(a.name)
			ms.append("%s(%s)" % [m.name, ", ".join(args)])
		print("== ", c, ": ", ", ".join(ms))
		var ps := []
		for p in ClassDB.class_get_property_list(c, true): ps.append(p.name)
		print("   props: ", ", ".join(ps))
	quit()

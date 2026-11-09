extends SceneTree
## headless runner for sim_tests.tscn (quits when the suite prints its last line)
func _init() -> void:
	var sc: PackedScene = load("res://sim/tests/sim_tests.tscn")
	var n := sc.instantiate()
	root.add_child(n)
	while true:
		await process_frame
		if n.out != null and n.out.get_parsed_text().contains(" – total "): break
	quit(n.fails)

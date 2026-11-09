extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: RaceEngine.PACE_A = float(a[0])
	if a.size() > 1: RaceEngine.PACE_D = float(a[1])
	for c in [["tokyo", 1600], ["nakayama", 2000], ["nakayama_d", 1800], ["tokyo_d", 1600]]:
		for style in ["front", "mid"]:
			var st := {}
			for k in RaceEngine.STATS: st[k] = 70
			var h := { "name": "ref", "gene": "CT", "style": style, "bw": 480, "carried": 57, "jockey": 75, "form": 0, "dirt": 50, "stats": st }
			var r := RaceEngine.run_headless([h], { "course": c[0], "dist": c[1], "seed": 1, "injuries": false, "eiph": false })
			var res := RaceEngine.results(r)
			var ls: PackedStringArray = []
			for x in res.laps: ls.append("%.2f" % x)
			print(c, " ", style, " %.2f " % res.rows[0].time, " ".join(ls))
	quit()

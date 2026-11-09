extends SceneTree
## Career-world winning times by course/dist/class/going → CSV (local test tool). args: weeks seed
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var weeks := int(a[0]) if a.size() > 0 else 104
	Career.init(int(a[1]) if a.size() > 1 else 7)
	Career.force_full = a.size() > 3 and a[3] == "full"
	var f := FileAccess.open("/home/claude/godot/times_%s.csv" % (a[2] if a.size() > 2 else "base"), FileAccess.WRITE)
	f.store_line("year,week,course,surface,dist,cls,age,going,win,second,n,f3,l3")
	var t0 := Time.get_ticks_msec()
	for w in weeks:
		var done: Array = Career.advance_week()
		for r in done:
			var res: Array = r.get("result", [])
			if res.size() < 2 or res[0].time == null: continue
			var lp: Array = r.get("laps", [])
			var f3 := 0.0
			var l3 := 0.0
			if lp.size() >= 6:
				var acc := 0.0
				var m := 0.0
				var first: float = float(r.dist) - 200.0 * (lp.size() - 1)   # first lap may be short
				for i in lp.size():
					m += first if i == 0 else 200.0
					acc += lp[i]
					if f3 == 0.0 and m >= 599.0: f3 = acc * 600.0 / m if m > 600.5 else acc
				l3 = lp[-1] + lp[-2] + lp[-3]
			f.store_line("%d,%d,%s,%s,%d,%s,%s,%s,%.2f,%.2f,%d,%.2f,%.2f" % [Career.W.year, r.week, r.course, RaceEngine.COURSES[r.course].surface, r.dist, r.cls, r.age, r.going, res[0].time, res[1].time if res[1].time != null else 0.0, res.size(), f3, l3])
	print("weeks ", weeks, " ms ", Time.get_ticks_msec() - t0)
	quit()

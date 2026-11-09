extends Control
## Simulation self-test. Open res://sim/tests/sim_tests.tscn and press F6.
## Checks the GDScript port against numbers from the JavaScript version (same seeds -> same races),
## then prints a sample race, course times, breeding and career checks.

var out: RichTextLabel
var fails := 0

func _ready() -> void:
	out = RichTextLabel.new()
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	out.offset_left = 12; out.offset_top = 8; out.offset_right = -12; out.offset_bottom = -8
	out.bbcode_enabled = true
	out.scroll_following = true
	out.add_theme_font_size_override("normal_font_size", 14)
	out.add_theme_font_override("normal_font", SystemFont.new())
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	out.add_theme_font_override("mono_font", mono)
	add_child(out)
	_run()

func say(t: String) -> void:
	out.append_text(t + "\n")
	print_rich(t)

func check(ok: bool, what: String) -> void:
	if not ok: fails += 1
	say(("[color=#4caf50]PASS[/color] " if ok else "[color=#f44336]FAIL[/color] ") + what)

func frame() -> void:
	await get_tree().process_frame


# ---------------- same test fields as the JavaScript check (mkfields.js) ----------------
const STYLES := ["front", "stalker", "mid", "closer"]
const GENES := ["CC", "CT", "TT"]
# [course, dist, runners, going, seed, JS winner, JS winning time, JS steps]
const GOLDEN := [   # v0.9 reference results (rating step: stat sensitivity, pack effect, 2026-11); v0.5 matched the JavaScript version
	["tokyo", 2400, 1, "firm", 6, "H1", 161.60829908712145, 3260],
	["tokyo", 2400, 16, "firm", 11, "H3", 143.9784811696897, 2987],
	["nakayama", 2500, 16, "soft", 3, "H5", 157.05610115428823, 3324],
	["kyoto", 3200, 18, "firm", 9, "H3", 205.66318568170922, 4333],
	["hanshin", 1600, 18, "yielding", 21, "H13", 92.83400399721945, 1916],
	["tokyo_d", 1600, 16, "heavy", 4, "H2", 95.73855437263741, 1985],
	["niigata_s", 1000, 18, "firm", 8, "H7", 55.63497949955831, 1156],
	["kyoto", 1600, 18, "firm", 13, "H1", 92.70050142229775, 1933],
]

func test_horse(R: SimRng, i: int, base: float) -> Dictionary:
	var st := {}
	for k in RaceEngine.STATS: st[k] = int(SimUtil.js_round(base + (R.next() - 0.5) * 20.0))
	var bw := 470 + int(SimUtil.js_round(R.next() * 40.0))
	var jk := 60 + int(SimUtil.js_round(R.next() * 35.0))
	var dt := int(SimUtil.js_round(R.next() * 100.0))
	return { "name": "H%d" % (i + 1), "stats": st, "gene": GENES[i % 3], "style": STYLES[i % 4], "bw": bw, "carried": 57, "jockey": jk, "dirt": dt }

func ref_horse() -> Dictionary:
	var st := {}
	for k in RaceEngine.STATS: st[k] = 70
	return { "name": "Stat-70", "gene": "CT", "style": "stalker", "bw": 480, "carried": 57, "jockey": 75, "form": 0, "dirt": 50, "stats": st }

func laps_text(laps: Array) -> String:
	var a: PackedStringArray = []
	for x in laps: a.append("%.1f" % x)
	return " - ".join(a)


func _run() -> void:
	await frame()
	say("[b]Horse Racing Simulation – engine self-test (v0.6)[/b]\n")
	var t_all := Time.get_ticks_msec()

	# ---- 1. same seeds as JavaScript ----
	say("[b]1. Reference races (v0.6)[/b]")
	var R := SimRng.new(777)
	var fields: Array = []
	for g in GOLDEN:
		var field: Array = []
		for i in int(g[2]): field.append(test_horse(R, i, 70))
		fields.append(field)
	for gi in GOLDEN.size():
		var g: Array = GOLDEN[gi]
		var t0 := Time.get_ticks_msec()
		var race := RaceEngine.run_headless(fields[gi].duplicate(true), { "course": g[0], "dist": g[1], "going": g[3], "seed": g[4] })
		var res := RaceEngine.results(race)
		var w: Dictionary = res.rows[0]
		var steps := roundi(race.t / RaceEngine.DT)
		var dt := absf(float(w.time) - float(g[6]))
		# exact on Linux; other systems' maths libraries can differ in the last binary digit, so allow a hair
		check(w.name == g[5] and dt < 0.05 and absi(steps - int(g[7])) <= 2, "%-10s %d m, %2d runners: winner %s %s (ref %s %s) %s, %d ms" % [g[0], g[1], g[2], w.name, RaceEngine.fmt_time(w.time), g[5], RaceEngine.fmt_time(g[6]), "exact" if dt < 1e-6 else "diff %.4f s" % dt, Time.get_ticks_msec() - t0])
		await frame()

	# ---- 2. determinism ----
	say("\n[b]2. Determinism (same seed twice)[/b]")
	var a := RaceEngine.results(RaceEngine.run_headless(fields[1].duplicate(true), { "course": "tokyo", "dist": 2400, "seed": 11 }))
	var b := RaceEngine.results(RaceEngine.run_headless(fields[1].duplicate(true), { "course": "tokyo", "dist": 2400, "seed": 11 }))
	var same: bool = a.rows.size() == b.rows.size()
	for i in a.rows.size():
		if a.rows[i].name != b.rows[i].name or a.rows[i].time != b.rows[i].time: same = false
	check(same, "Tokyo 2400 m, 16 runners, seed 11 run twice: identical result")
	await frame()

	# ---- 3. sample race ----
	say("\n[b]3. Sample race – Tokyo turf 2400 m, firm, 16 runners[/b]")
	say("[code]Pos  Horse  Style    Gene  Time     Margin    Last 3F  Notes")
	for row in a.rows:
		var r: RaceEngine.Runner = row.r
		say("%-4s %-6s %-8s %-5s %-8s %-9s %-8s %s" % ["DNF" if row.pos < 0 else str(row.pos), row.name, r.h.style, r.h.gene, RaceEngine.fmt_time(row.time), row.margin, "%.1f" % row.last3f if row.last3f > 0 else "-", row.notes])
	say("Laps: " + laps_text(a.laps) + "[/code]")
	await frame()

	# ---- 4. course times ----
	say("\n[b]4. A stat-70 horse running alone (firm going)[/b]")
	say("[code]Course              Dist   Time     1st 200 m  1000 m   Last 3F")
	for c in [["tokyo", 1600], ["tokyo", 2000], ["tokyo", 2400], ["nakayama", 2500], ["kyoto", 3000], ["kyoto", 3200], ["hanshin", 1600], ["chukyo", 1200], ["niigata_s", 1000], ["tokyo_d", 1600], ["nakayama_d", 1800], ["kyoto_d", 1800]]:
		var rc := RaceEngine.run_headless([ref_horse()], { "course": c[0], "dist": c[1], "seed": 1, "injuries": false, "eiph": false })
		var rs := RaceEngine.results(rc)
		say("%-19s %-6d %-8s %-10s %-8s %.1f" % [RaceEngine.COURSES[c[0]].short, c[1], RaceEngine.fmt_time(rs.rows[0].time), "%.1f" % rs.laps[0], RaceEngine.fmt_time(rs.first1000), rs.raceL3F])
		await frame()
	say("[/code]")

	# ---- 5. breeding ----
	say("\n[b]5. Breeding[/b]")
	var br := SimRng.new(42)
	Breeding.seed_book(br, 1, 1)
	var s := Breeding.founder(br, "M", 70, { "retired": true })
	s.mstn = "CT"
	var d := Breeding.founder(br, "F", 70, { "retired": true })
	d.mstn = "CT"
	var cnt := { "CC": 0, "CT": 0, "TT": 0 }
	for i in 4000: cnt[Breeding.breed(s, d, br).mstn] += 1
	check(absi(cnt.CC - 1000) < 100 and absi(cnt.CT - 2000) < 130 and absi(cnt.TT - 1000) < 100, "MSTN C:T x C:T -> CC %d / CT %d / TT %d (expect about 1000 / 2000 / 1000)" % [cnt.CC, cnt.CT, cnt.TT])
	var km: Dictionary = {}
	var kf: Dictionary = {}
	while km.is_empty() or kf.is_empty():
		var k := Breeding.breed(s, d, br)
		if k.sex == "M" and km.is_empty(): km = k
		if k.sex == "F" and kf.is_empty(): kf = k
	var inbred := Breeding.breed(km, kf, br)
	check(absf(inbred.F - 0.25) < 1e-9, "Full brother x full sister: inbreeding F = %.3f (expect 0.250)" % inbred.F)
	say("Example foal: %s (%s), %s, %s, %s gene, style %s" % [inbred.name, "colt" if inbred.sex == "M" else "filly", Breeding.byline(inbred), inbred.coat, inbred.gene, inbred.style])
	await frame()

	# ---- 6. career ----
	say("\n[b]6. Career mode[/b]")
	var t0 := Time.get_ticks_msec()
	Career.init(5)
	say("New world: %d horses in the stud book, built in %d ms" % [Breeding.book.size(), Time.get_ticks_msec() - t0])
	var ys := Career.buy_yearling()
	Career.add_to_stable(ys[0].id); Career.add_to_stable(ys[1].id)
	for h in Career.active():
		if h.age == 3:
			Career.add_to_stable(h.id); break
	await frame()
	var mine_results := {}
	t0 = Time.get_ticks_msec()
	for i in 20:
		var done := Career.advance_week()
		for r in done:
			if Career.W.replays.has(r.id): mine_results[r.id] = r.result
		if i == 7: check(Career.R.state == 3084092151, "After 8 weeks the world matches the race-planning reference (RNG state %d)" % Career.R.state)
		await frame()
	check(Career.R.state == 3699185613, "After 20 weeks the world matches the race-planning reference (RNG state %d), %d ms" % [Career.R.state, Time.get_ticks_msec() - t0])
	var st := Career.stats()
	var tiers: PackedStringArray = []
	for k in Career.TIERS:
		if st.tiers.has(k): tiers.append("%s %d" % [k, st.tiers[k]])
	say("Active horses (2yo+): %d – %s" % [st.n, ", ".join(tiers)])
	for id in Career.W.stable:
		var h: Dictionary = Breeding.get_horse(id)
		say("My horse: %s, %d yo, %s, %d starts, %d wins" % [h.name, h.age, Career.tier_of(h), h.c.starts, h.c.wins])
	# add three healthy 3-4yo horses, then enter my horses every week so they run in the full physics engine
	var added := 0
	for h in Career.active():
		if added < 3 and h.age >= 3 and h.age <= 4 and h.c.out == 0 and not Career.W.stable.has(h.id):
			Career.add_to_stable(h.id); added += 1
	for i in 6:
		for id in Career.W.stable:
			for r in Career.W.races:
				if Career.eligible(Breeding.get_horse(id), r):
					Career.enter(id, r.id); break
		for r in Career.advance_week():
			if Career.W.replays.has(r.id): mine_results[r.id] = r.result
		await frame()
	for e in Career.W.log.filter(func(x): return x.mine).slice(0, 8): say("  my log: " + e.msg)
	if mine_results.is_empty():
		say("(no replay to check yet)")
	else:
		var rid: int = mine_results.keys()[0]
		var rp := RaceEngine.results(Career.replay_race(rid))
		var ok := true
		for i in rp.rows.size():
			if rp.rows[i].name != mine_results[rid][i].name: ok = false
		check(ok, "Replay of %s gives the same finishing order as the career result" % Career.W.replays[rid].name)
	# save -> load -> 3 more weeks must equal simply running 3 more weeks
	var t1 := Time.get_ticks_msec()
	var sv := Career.save_data()
	var t_save := Time.get_ticks_msec() - t1
	var cont: Array = []
	for i in 3:
		for r in Career.advance_week(): cont.append([r.id, r.result[0].id, r.result[0].time])
	var st_a := Career.R.state
	t1 = Time.get_ticks_msec()
	Career.load_data(sv)
	var t_load := Time.get_ticks_msec() - t1
	var cont2: Array = []
	for i in 3:
		for r in Career.advance_week(): cont2.append([r.id, r.result[0].id, r.result[0].time])
	check(cont == cont2 and Career.R.state == st_a, "Save (%d KB, %d ms) -> load (%d ms) -> 3 more weeks: identical to never saving" % [sv.size() / 1024, t_save, t_load])

	say("\n[b]%s[/b] – total %.1f s" % ["ALL TESTS PASSED" if fails == 0 else "%d TEST(S) FAILED" % fails, (Time.get_ticks_msec() - t_all) / 1000.0])

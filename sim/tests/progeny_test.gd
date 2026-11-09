extends SceneTree
## Progeny validation (local test tool): the world's ~400 broodmares are bred to the real stallions every season
## (AI matings); foals born in the game are followed until the end of the run, then summarised per sire.
## args: years seed
const OS_SIRES := ["Frankel", "Dubawi", "Sea The Stars", "Lope De Vega", "Night Of Thunder", "Gun Runner", "Into Mischief", "Not This Time", "Curlin"]
var EXP_SIRES := ["Kizuna", "Kitasan Black", "Lord Kanaloa", "Epiphaneia", "Drefong", "Maurice", "Gold Ship", "Rulership"]
const SIRES := ["Kizuna", "Kitasan Black", "Lord Kanaloa", "Epiphaneia", "Drefong", "Maurice", "Gold Ship", "Rulership",
	"Equinox", "Contrail", "Do Deuce", "Swarve Richard", "Saturnalia", "Real Steel", "Nadal", "Chrysoberyl", "Orfevre", "Admire Mars"]

# a retired horse's history is cut to 3 races at the next year end, so keep the first copy taken after it retired
func _fresh(snap: Dictionary, h: Dictionary) -> bool:
	var o = snap.get(int(h.id))
	return o == null or str(o.c.status) == "active"

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var years := int(a[0]) if a.size() > 0 else 8
	var seed := int(a[1]) if a.size() > 1 else 3
	var t0 := Time.get_ticks_msec()
	# exp mode: a double-size world (800 mares, race card scaled up) where half of the mares are shared out equally among
	# the 8 test stallions and the other half are bred as usual to the whole stallion roster, so the test sires' foals
	# meet a normal mix of rivals (dirt specialists, sprinters, stayers) — not only each other
	var exp := a.size() > 2 and (a[2] == "exp" or a[2] == "os")
	if a.size() > 2 and a[2] == "os": EXP_SIRES = OS_SIRES        # overseas stallions
	Career.init(seed, { "mares": 800, "crop": 600, "perWeek": 10 } if exp else {})
	var first_born := int(Career.W.year) + 1      # foals conceived in the game
	var covers := 0
	var rng := SimRng.new(seed * 31)
	var snap := {}
	var runs := {}
	for w in years * 52:
		if exp and int(Career.W.week) == Stud.SEASON_START - 1 and int(Career.W.year) < first_born + 3:
			# equal, random allocation of all broodmares to the test stallions (removes mare-quality bias)
			var ms: Array = Breeding.mares().filter(func(m): return int(m.age) <= Stud.MAX_MARE_AGE)
			for i in ms.size():
				var j := i + int(floor(rng.next() * (ms.size() - i)))
				var t = ms[i]; ms[i] = ms[j]; ms[j] = t
			Stud.force_plan = {}
			ms = ms.slice(0, ms.size() / 2)
			for i in ms.size(): Stud.force_plan[int(ms[i].id)] = int(Bloodlines.by_name[EXP_SIRES[i % EXP_SIRES.size()]].id)
			covers += ms.size()
		if int(Career.W.week) == 52:
			# the yearly prune drops retired horses that don't breed (mostly losers) — keep a copy so they still count
			for h in Breeding.book.values():
				if h.has("c") and int(h.c.get("born", 0)) >= first_born and _fresh(snap, h): snap[int(h.id)] = h.duplicate(true)
		var yr := int(Career.W.year)
		for r in Career.advance_week():          # full race log (careers keep only the last 12 runs)
			for e in r.result:
				var id := int(e.id)
				if not runs.has(id): runs[id] = []
				runs[id].append({ "y": yr, "course": r.course, "dist": r.dist, "pos": str(e.pos) })
	for h in Breeding.book.values():
		if h.has("c") and int(h.c.get("born", 0)) >= first_born and _fresh(snap, h): snap[int(h.id)] = h
	print("forced covers: ", covers)
	print("simulated %d years in %d s" % [years, (Time.get_ticks_msec() - t0) / 1000])
	var end_year := int(Career.W.year)
	# collect
	var by := {}
	var all_earn := 0.0
	var all_run := 0
	for h in snap.values():
		if not h.has("c") or h.sire == null: continue
		var born := int(h.c.get("born", 0))
		if born < first_born: continue
		var s = Breeding.get_horse(h.sire)
		if s == null: continue
		var k: String = s.name
		if not by.has(k):
			by[k] = { "foals": 0, "mares": {}, "runners": 0, "winners": 0, "wins": 0, "earn": 0.0, "tw": 0, "dw": 0, "td": 0.0, "dd": 0.0,
				"r2": 0, "w2": 0, "rating": 0.0, "nmat": 0, "temper": 0.0, "dist": 0.0, "dirt": 0.0, "mstn": { "CC": 0, "CT": 0, "TT": 0 },
				"stats": {}, "mr": 0, "mw": 0, "ndirt": 0, "g1": 0, "graded": 0, "never": 0, "age_ok": 0 }
		var b: Dictionary = by[k]
		b.foals += 1
		b.mares[int(h.dam)] = true
		b.mstn[h.mstn] += 1
		if int(h.dirt) >= 50: b.ndirt += 1
		b.temper += float(h.stats.temper); b.dist += Career.best_dist(h); b.dirt += float(h.dirt)
		for st in h.stats: b.stats[st] = float(b.stats.get(st, 0.0)) + float(h.stats[st])
		if end_year - born >= 3:            # old enough to have raced at 2 and 3
			b.age_ok += 1
			b.rating += Career.rating(h); b.nmat += 1
		var c: Dictionary = h.c
		if int(c.starts) > 0:
			b.runners += 1
			all_run += 1
			all_earn += float(c.earn)
			b.earn += float(c.earn)
			if int(c.wins) > 0: b.winners += 1
			if end_year - born >= 4:          # finished the 3-year-old season
				b.mr += 1
				if int(c.wins) > 0: b.mw += 1
			b.wins += int(c.wins)
			b.g1 += mini(1, int(c.g1)); b.graded += mini(1, int(c.graded))
			var raced2 := false
			var won2 := false
			for e in runs.get(int(h.id), []):
				var yr_age := int(e.y) - born
				if yr_age == 2:
					raced2 = true
					if str(e.pos) == "1": won2 = true
				if str(e.pos) != "1": continue
				var dirt: bool = RaceEngine.COURSES[e.course].surface == "dirt"
				if dirt: b.dw += 1; b.dd += float(e.dist)
				else: b.tw += 1; b.td += float(e.dist)
			if raced2:
				b.r2 += 1
				if won2: b.w2 += 1
		elif end_year - born >= 3 and c.status != "active": b.never += 1
	var mean_earn := all_earn / maxf(1.0, float(all_run))
	var wr := 0
	var rr := 0
	var r2 := 0
	var w2 := 0
	for k in by:
		wr += int(by[k].mw); rr += int(by[k].mr); r2 += int(by[k].r2); w2 += int(by[k].w2)
	print("WORLD (in-game foals, crops past age 3): runners %d, winners %d = %.1f%% (real JRA: about 30–35%% of runners win)" % [rr, wr, 100.0 * wr / maxf(1, rr)])
	var tw := 0
	var dw := 0
	var nd := 0
	var nf := 0
	for k in by:
		tw += int(by[k].tw); dw += int(by[k].dw); nd += int(by[k].ndirt); nf += int(by[k].foals)
	print("WORLD surface: %.0f%% of wins on turf; %.0f%% of foals are dirt types (aptitude >= 50)" % [100.0 * tw / maxf(1, tw + dw), 100.0 * nd / maxf(1, nf)])
	# earnings by best distance (are sprinters or stayers short-changed?)
	var bk := {}
	for h in snap.values():
		if not h.has("c") or int(h.c.starts) == 0: continue
		var b := clampi(int(Career.best_dist(h) / 200.0) * 200, 1000, 2600)
		if not bk.has(b): bk[b] = [0, 0.0, 0]
		bk[b][0] += 1; bk[b][1] += float(h.c.earn); bk[b][2] += 1 if int(h.c.wins) > 0 else 0
	var ks := bk.keys(); ks.sort()
	var line := "WORLD earnings index by best distance:"
	for k in ks: line += "  %d:%.2f(%d)" % [k, bk[k][1] / bk[k][0] / maxf(0.01, mean_earn), bk[k][0]]
	print(line)
	var bg := {}
	for h in snap.values():
		if not h.has("c") or int(h.c.starts) == 0: continue
		var g: String = h.gene
		if not bg.has(g): bg[g] = [0, 0.0, 0, 0.0]
		bg[g][0] += 1; bg[g][1] += float(h.c.earn); bg[g][2] += 1 if int(h.c.wins) > 0 else 0; bg[g][3] += Career.rating(h)
	line = "WORLD by MSTN gene (earnings index, winners, mean rating):"
	for g in ["CC", "CT", "TT"]:
		if bg.has(g): line += "  %s %.2f %.0f%% %.1f (%d)" % [g, bg[g][1] / bg[g][0] / maxf(0.01, mean_earn), 100.0 * bg[g][2] / bg[g][0], bg[g][3] / bg[g][0], bg[g][0]]
	print(line)
	print("WORLD 2-year-olds: runners %d, winners at 2 %d = %.1f%%" % [r2, w2, 100.0 * w2 / maxf(1, r2)])
	var f := FileAccess.open("/home/claude/godot/calib/progeny_sim_%d%s.csv" % [seed, ("_" + a[2]) if exp else ""], FileAccess.WRITE)
	f.store_line("sire,foals,mares,runners,win_horse_rate,aei,turf_win_share,turf_win_dist,dirt_win_dist,win2_rate,mature_rating,temper,best_dist,dirt_apt,CC,CT,TT,g1_horses,graded_horses,speed,stamina,burst,accel,strength,guts,agility,sound,wind")
	print("%-15s %5s %5s %5s %6s %5s %6s %6s %6s %6s %6s %6s %6s" % ["sire", "foals", "mares", "runs", "winH%", "AEI", "turf%", "Tdist", "Ddist", "2yoW%", "rate", "temp", "bdist"])
	for k in (EXP_SIRES if exp else SIRES):
		if not by.has(k): print("%-15s no foals" % k); continue
		var b: Dictionary = by[k]
		var n := float(b.foals)
		var row := [k, b.foals, b.mares.size(), b.runners, 100.0 * b.mw / maxf(1.0, b.mr), (b.earn / maxf(1.0, b.runners)) / mean_earn,
			100.0 * b.tw / maxf(1.0, b.tw + b.dw), b.td / maxf(1.0, b.tw), b.dd / maxf(1.0, b.dw), 100.0 * b.w2 / maxf(1.0, b.r2),
			b.rating / maxf(1.0, b.nmat), b.temper / n, b.dist / n, b.dirt / n, 100.0 * b.mstn.CC / n, 100.0 * b.mstn.CT / n, 100.0 * b.mstn.TT / n, b.g1, b.graded]
		for st in ["speed", "stamina", "burst", "accel", "strength", "guts", "agility", "sound", "wind"]: row.append(b.stats[st] / n)
		f.store_line(",".join(row.map(func(x): return ("%.2f" % x) if x is float else str(x))))
		print("%-15s %5d %5d %5d %6.1f %5.2f %6.1f %6.0f %6.0f %6.1f %6.1f %6.1f %6.0f" % [k, b.foals, b.mares.size(), b.runners, row[4], row[5], row[6], row[7], row[8], row[9], row[10], row[11], row[12]])
	var tm := 0
	for k in by: tm += by[k].mares.size()
	print("total in-game foals: ", by.values().reduce(func(acc, b): return acc + b.foals, 0), " from ", tm, " mare-sire pairs; mean earnings per runner ¥%.1fM" % mean_earn)
	quit()

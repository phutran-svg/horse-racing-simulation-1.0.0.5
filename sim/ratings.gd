class_name Ratings
extends RefCounted
## Official ratings in pounds, worked out the way JRA / IFHA handicappers do it:
##  - every run gets a performance rating: race level − beaten lengths × lb per length (BHA scale by distance)
##    + weight carried above/below 58 kg (2.2 lb per kg) + weight-for-age allowance (2- and 3-year-olds)
##  - the race level comes from the "yardsticks" (runners whose official marks are known: collateral form) and
##    from the winning time against a standard (time figure), blended like a handicapper would
##  - a horse's official rating for the year is its best performance, with distance category S/M/I/L/E and
##    surface (JRA "JPN Thoroughbred Ranking" / IFHA "LONGINES World's Best Racehorse Rankings")
##  - the handicap mark (for handicap weights) moves after each run towards the new performance
##  - race rating = average of the year ratings of the first four (fillies +4 lb in open races); the 3-year average
##    decides the grade (G1 115, G2 110, G3 105; 5 lb less for fillies' and 2-year-old races)
## Fillies' ratings are published on their own scale (JRA adds a flat 4 lb when ranking them with colts).

const LB_PER_KG := 2.2
const REF_KG := 58.0                 # older colts' weight-for-age in JRA (4yo+ 58 kg)
const K_TIME := 13.5                 # lb per 1 % of race time (BHA lb-per-length scale ÷ length in seconds ≈ 12.5–14.5)
const T_REF := 118.0                 # the time standard is the speed of a ~118 performance (typical JRA G1 winner)
const LEN_M := 2.4                   # one length (m)
const FILLY_ALLOW := 4.0             # JRA/IFHA fillies' and mares' allowance used for race ratings and rankings
const PUBLISH_JPN := 100.0           # JPN Thoroughbred Ranking lists horses rated 100+
const PUBLISH_WORLD := 115.0         # LONGINES World's Best Racehorse Rankings list horses rated 115+
const GRADE_PAR := { "G1": 115.0, "G2": 110.0, "G3": 105.0 }
const GRADE_TOL := 5.0               # relegation tolerance below the parameter (3-year average)
static var STD := {}                 # time standards cache: course+dist+going → seconds
static var REF_LV := 74.0            # stats of the standard horse (calibrated, see tests/rating_calib.gd)
static var LEVEL_OFF := 13.0
## distance categories rate differently against the time standard (bigger world, Step 4: sprint and mile G1s came out
## 4–8 lb above the real JRA/IFHA figures while middle distances matched)
## (tried in Step 4: lowering sprint/mile/dirt figures made the whole scale drift down year after year, so the
##  categories stay on one scale; sprint and mile G1s rate a few lb above the real figures)
const CAT_OFF := { "S": 0.0, "M": 0.0, "I": 0.0, "L": 0.0, "E": 0.0 }
static var DIRT_OFF := -24.0         # dirt is rated lower against the standard (JRA dirt G1s ≈ 115–117, domestic dirt tops ≈ 117–120)
static var WFA2 := 0.45
static var WFA3 := 1.25          # global offset (calibration)
static var BOOT_A := 100.0           # starting marks: an average racehorse ≈ 100 lb …
static var BOOT_B := 0.8             # … and lb per point of the game's ability rating (fit of year-best ratings, tests/rating_calib.gd)
static var BOOT_DIRT := -6.0

## IFHA distance category
static func cat(dist: int, surface: String = "turf") -> String:
	if dist <= 1300: return "S"
	if dist <= 1899: return "M"
	if dist <= 2100: return "I"
	if dist <= 2700: return "L"
	return "E"

## pounds per length by distance (BHA flat scale: 5f 3 lb, 6f 2.5, 7–8f 2, 9–10f 1.75, 11–13f 1.5, 14f 1.25, 15f+ 1)
static func lb_per_length(dist: int) -> float:
	if dist <= 1100: return 3.0
	if dist <= 1300: return 2.5
	if dist <= 1700: return 2.0
	if dist <= 2100: return 1.75
	if dist <= 2700: return 1.5
	if dist <= 2900: return 1.25
	return 1.0

## weight-for-age allowance in lb: how much a normal (C:T, average growth) horse of this age is still behind a
## mature one at this time of the year in the game's own age curve, so ratings of 2- and 3-year-olds compare with
## older horses (real scales give a 3yo ~8–12 lb in June at 12f; 2yos ~15–20 lb in autumn)
static func wfa(age: int, week: int) -> float:
	if age >= 4: return 0.0
	var a: float = float(age) + (week - 1) / 52.0
	var f := 1.0
	var P: Array = Career.AGE_PTS
	for i in range(1, P.size()):
		if a <= P[i][0]:
			f = P[i - 1][1] + (P[i][1] - P[i - 1][1]) * clampf((a - P[i - 1][0]) / (P[i][0] - P[i - 1][0]), 0.0, 1.0)
			break
	# 2-year-olds: their published ratings stay on a lower scale (JRA 2yo tops ≈ 115–117 vs 125+ for older horses),
	# so they get only part of the physical allowance
	return maxf(0.0, (1.0 - f) * 100.0 * K_TIME * (WFA2 if age <= 2 else WFA3))

## standard time (s) of the reference horse for this course, distance and going (quick model, no noise)
static func std_time(course: String, dist: int, going: String) -> float:
	var key := "%s%d%s" % [course, dist, going]
	if STD.has(key): return STD[key]
	var st := {}
	for k in RaceEngine.STATS: st[k] = REF_LV
	var ref := { "id": -1, "name": "std", "gene": "CT", "style": "stalker", "bw": 480, "carried": REF_KG, "jockey": 75, "form": 0,
		"dirt": 85 if RaceEngine.COURSES[course].surface == "dirt" else 15, "going": 50, "stats": st, "age": 5 }
	var t: float = Career.quick_time(ref, { "course": course, "dist": dist, "going": going, "id": 0 }, 0.0)
	STD[key] = t
	return t

## starting marks for the horses already racing when a career begins: from the horse's class (record) and ability
static func bootstrap(h: Dictionary, q: float) -> float:
	var ab := BOOT_A + BOOT_B * (Career.rating(h) * Career.age_factor(h, 52) - 66.5) + (BOOT_DIRT if int(h.get("dirt", 50)) >= 50 else 0.0)
	return roundf(ab)

## margin in the usual notation (nose · head · neck · ½ · ¾ · 1 · 1¼ … · dist.)
static func margin_text(len_b: float) -> String:
	if len_b < 0.08: return "nose"
	if len_b < 0.18: return "head"
	if len_b < 0.35: return "neck"
	if len_b < 0.62: return "1/2"
	if len_b < 0.87: return "3/4"
	if len_b >= 10.0: return "dist."
	var q := roundf(len_b * 4.0) / 4.0 if len_b < 2.5 else (roundf(len_b * 2.0) / 2.0 if len_b < 5.0 else roundf(len_b))
	var whole := int(floor(q))
	var frac := q - whole
	var f := "" if frac < 0.01 else (" 1/4" if frac < 0.3 else (" 1/2" if frac < 0.6 else " 3/4"))
	return str(whole) + f

## the official mark a handicapper would use now (null if never rated)
static func mark(h: Dictionary) -> Variant:
	var c = h.get("c")
	if c == null: return null
	return c.get("mark")

## the horse's official rating for a year: { r, cat, surf, race } or null
static func year_best(h: Dictionary, year: int) -> Variant:
	var c = h.get("c")
	if c == null: return null
	var rt = c.get("rt")
	if rt != null and int(rt.y) == year: return rt
	var rp = c.get("rtPrev")
	if rp != null and int(rp.y) == year: return rp
	return null

## best rating ever (career): used for value, stud fee and records
static func career_best(h: Dictionary) -> float:
	var c = h.get("c")
	if c == null: return 0.0
	return float(c.get("rtMax", 0.0))

## rates every finisher of a finished race. order: [{h, t, dnf}] in finishing order (winner first)
static func rate_race(r: Dictionary, order: Array) -> void:
	if order.is_empty() or order[0].dnf or order[0].t == null: return
	var tw: float = order[0].t
	var dist: int = r.dist
	var lbl := lb_per_length(dist)
	var v: float = dist / tw
	var week: int = Career.W.week
	var beaten := []
	var adj := []
	for o in order:
		if o.dnf or o.t == null:
			beaten.append(null); adj.append(0.0)
			continue
		var len_b: float = (float(o.t) - tw) * v / LEN_M
		# big margins are not taken at face value (eased horses): beyond 10 lengths only half counts
		if len_b > 10.0: len_b = 10.0 + (len_b - 10.0) * 0.5
		beaten.append(len_b * lbl)
		adj.append((float(o.h.get("carried", REF_KG)) - REF_KG) * LB_PER_KG + wfa(int(o.h.age), week))
	# time figure: winner's speed against the standard
	var ts := std_time(r.course, dist, str(r.get("going", "firm")))
	var tf := T_REF + LEVEL_OFF + float(CAT_OFF[cat(int(r.dist))]) + (DIRT_OFF if RaceEngine.COURSES[r.course].surface == "dirt" else 0.0) + K_TIME * 100.0 * (ts - tw) / ts
	# collateral form: what the yardsticks say about the winner's speed level
	var imp := []
	for i in order.size():
		if beaten[i] == null or i >= 8 or float(beaten[i]) > 8.0 * lbl: continue
		var m = mark(order[i].h)
		if m == null or int(order[i].h.c.get("nRated", 0)) < 2: continue
		imp.append(float(m) - adj[i] + float(beaten[i]))
	# class par (running average of race levels for this class and age group) keeps a lone time figure sane
	var pk := "%s|%s|%s" % [r.cls, r.age, "D" if RaceEngine.COURSES[r.course].surface == "dirt" else "T"]
	var W: Dictionary = Career.W
	if not W.has("rtPar"): W["rtPar"] = {}
	var par = W.rtPar.get(pk)
	if par != null: tf = clampf(tf, float(par[0]) - 12.0, float(par[0]) + 12.0)
	var lvl := tf
	if imp.size() > 0:
		imp.sort()
		var med: float = imp[imp.size() / 2] if imp.size() % 2 == 1 else (imp[imp.size() / 2 - 1] + imp[imp.size() / 2]) / 2.0
		var wf := 0.4 if imp.size() >= 3 else 0.2
		lvl = wf * med + (1.0 - wf) * clampf(tf, med - 8.0, med + 8.0)
	var surf := "D" if RaceEngine.COURSES[r.course].surface == "dirt" else "T"
	var ct := cat(dist)
	var year: int = Career.W.year
	r["level"] = snappedf(lvl, 0.1)
	W.rtPar[pk] = [lvl, 1] if par == null else [float(par[0]) + (lvl - float(par[0])) / minf(30.0, float(par[1]) + 1.0), int(par[1]) + 1]
	for i in order.size():
		if beaten[i] == null: continue
		var h: Dictionary = order[i].h
		var c: Dictionary = h.c
		var perf: float = lvl - float(beaten[i]) + adj[i]
		# handicappers are wary of a sudden big jump: above the horse's mark + 12 only half of the extra is credited
		var m0 = c.get("mark")
		if m0 != null and int(c.get("nRated", 0)) >= 2 and perf > float(m0) + 16.0: perf = float(m0) + 16.0 + 0.5 * (perf - float(m0) - 16.0)
		perf = roundf(perf)
		order[i]["rt"] = perf
		# year best (official rating) and career best
		var rt = c.get("rt")
		if rt != null and int(rt.y) != year:
			c["rtPrev"] = rt
			rt = null
		if rt == null or perf > float(rt.r) or (perf == float(rt.r) and ct not in str(rt.cat)):
			if rt != null and perf == float(rt.r): c["rt"] = { "y": year, "r": perf, "cat": str(rt.cat) + "," + ct, "surf": rt.surf if rt.surf == surf else "D/T", "race": rt.race + " / " + r.name }
			else: c["rt"] = { "y": year, "r": perf, "cat": ct, "surf": surf, "race": r.name }
		c["rtMax"] = maxf(float(c.get("rtMax", 0.0)), perf)
		# handicap mark: up quickly after a good run, down slowly after a poor one (handicappers drop marks
		# gradually); the first runs set it directly
		var n := int(c.get("nRated", 0))
		var m = c.get("mark")
		if m == null or n == 0: c["mark"] = perf
		else: c["mark"] = roundf(float(m) + clampf(0.4 * (perf - float(m)), -6.0, 8.0))
		c["nRated"] = n + 1
		if not c.history.is_empty() and str(c.history[0].race) == str(r.name) and int(c.history[0].y) == year: c.history[0]["rt"] = perf

## annual race rating for a finished race: average of the first four's ratings for that year (fillies +4 lb unless the
## race is for fillies and mares). Uses current year-bests, so it is final at the end of the year.
static func race_rating(top4: Array, year: int, fillies_race: bool) -> float:
	var s := 0.0
	var n := 0
	for id in top4:
		var h = Breeding.get_horse(id)
		if h == null: continue
		var yb = year_best(h, year)
		if yb == null: continue
		s += float(yb.r) + (FILLY_ALLOW if (h.sex == "F" and not fillies_race) else 0.0)
		n += 1
	return s / n if n > 0 else 0.0

## grade parameter for a race (fillies-only and 2-year-old races 5 lb lower)
static func grade_par(cls: String, fillies: bool, age: String) -> float:
	var p: float = GRADE_PAR.get(cls, 100.0)
	if fillies or age == "2": p -= 5.0
	return p

## year end: annual race ratings of graded races, 3-year grading review, JPN ranking snapshot
static func year_end(year: int) -> void:
	var W: Dictionary = Career.W
	if not W.has("raceRt"): W["raceRt"] = {}
	if not W.has("rankings"): W["rankings"] = {}
	for g in W.gradedLog:
		if int(g.y) != year or not g.has("top4"): continue
		var rr := race_rating(g.top4, year, str(g.get("sex", "")) == "F")
		if rr <= 0.0: continue
		var lst: Array = W.raceRt.get(g.name, [])
		lst = lst.filter(func(e): return int(e.y) != year)
		lst.insert(0, { "y": year, "rr": snappedf(rr, 0.25), "cls": g.cls })
		if lst.size() > 6: lst.resize(6)
		W.raceRt[g.name] = lst
	# grading review (IFHA / JRA: 3-year average of annual race ratings against the grade parameter)
	if not W.has("gradeOverride"): W["gradeOverride"] = {}
	var promoted := false
	for gr in Career.GRADED:
		var name: String = gr[0]
		var lst: Array = W.raceRt.get(name, [])
		if lst.size() < 3: continue
		var avg := (float(lst[0].rr) + float(lst[1].rr) + float(lst[2].rr)) / 3.0
		var cls: String = W.gradeOverride.get(name, gr[1])
		# classics and 2-year-old / 3-year-old races are protected (JRA designates them); the review covers open races
		if gr[5] == "2" or gr[5] == "3": continue
		var par := grade_par(cls, gr[6] == "F", gr[5])
		var low := float(lst[0].rr) < par - GRADE_TOL and float(lst[1].rr) < par - GRADE_TOL and float(lst[2].rr) < par - GRADE_TOL
		if low and cls != "G3" and gr[1] != "G1":     # JRA's own G1 programme is never downgraded (only G2/G3 move)
			var down := "G2" if cls == "G1" else "G3"
			W.gradeOverride[name] = down
			Career.log_msg("Grading review: %s is downgraded to %s (3-year race rating %.2f, needs %.0f)" % [name, down, avg, par], null)
		elif cls == "G3" and not promoted:     # JRA's G1 list is set by JRA; the review only promotes G3s to G2
			# promotion (rare, as in JRA): every one of the last 3 years at the higher grade's standard + 3 lb,
			# and the race must be among the strongest of its grade; at most one promotion a year
			var up := "G1" if cls == "G2" else "G2"
			var par_up := grade_par(up, gr[6] == "F", gr[5]) + 3.0
			var each := float(lst[0].rr) >= par_up and float(lst[1].rr) >= par_up and float(lst[2].rr) >= par_up
			if each and avg >= _grade_top(W, cls, gr[6] == "F", gr[5]):
				W.gradeOverride[name] = up
				promoted = true
				Career.log_msg("Grading review: %s is upgraded to %s (3-year race rating %.2f)" % [name, up, avg], null)
	W.rankings[str(year)] = jpn_ranking(year)
	# IFHA: LONGINES World's Best Racehorse Rankings (115+) and the Top 100 G1 races
	if not W.has("world"): W["world"] = {}
	W.world[str(year)] = { "ranking": Intl.world_ranking(year).slice(0, 120), "races": Intl.top_races(year).slice(0, 100) }

## the 3-year average a race needs to be among the top 15 % of its grade (promotion check)
static func _grade_top(W: Dictionary, cls: String, fillies: bool, age: String) -> float:
	var avgs := []
	for gr in Career.GRADED:
		if W.gradeOverride.get(gr[0], gr[1]) != cls: continue
		var lst: Array = W.raceRt.get(gr[0], [])
		if lst.size() < 3: continue
		avgs.append((float(lst[0].rr) + float(lst[1].rr) + float(lst[2].rr)) / 3.0 - grade_par(cls, gr[6] == "F", gr[5]))
	if avgs.size() < 4: return 1e9
	avgs.sort()
	return avgs[int(floor(0.85 * (avgs.size() - 1)))] + grade_par(cls, fillies, age)

## JPN Thoroughbred Ranking for a year: horses rated 100+ by age group (2yo · 3yo turf/dirt · 4yo+ turf/dirt)
static func jpn_ranking(year: int, min_r := PUBLISH_JPN) -> Dictionary:
	var groups := { "2yo": [], "3yo Turf": [], "3yo Dirt": [], "4yo+ Turf": [], "4yo+ Dirt": [] }
	for h in Breeding.book.values():
		var yb = year_best(h, year)
		if yb == null or float(yb.r) < min_r: continue
		var age: int = int(h.age) - (int(Career.W.year) - year)   # age in that year
		var g := "2yo" if age <= 2 else (("3yo " if age == 3 else "4yo+ ") + ("Dirt" if str(yb.surf) == "D" else "Turf"))
		groups[g].append({ "id": int(h.id), "name": h.name, "r": float(yb.r), "cat": yb.cat, "surf": yb.surf, "race": yb.race, "sex": h.sex, "age": age })
	for g in groups:
		groups[g] = SimUtil.stable_sort(groups[g], func(a, b): return b.r - a.r)
	return groups

## pre-race (nominated horses') ratings for a race: this year's and last year's rating with category
static func nominated(r: Dictionary) -> Array:
	var out := []
	var y: int = Career.W.year
	for id in r.get("entries", []):
		var h = Breeding.get_horse(id)
		if h == null: continue
		var cur = year_best(h, y)
		var prev = year_best(h, y - 1)
		var key := maxf(float(cur.r) if cur != null else 0.0, float(prev.r) if prev != null else 0.0) + (FILLY_ALLOW if h.sex == "F" and str(r.get("sex", "")) != "F" else 0.0)
		out.append({ "id": int(id), "name": h.name, "cur": cur, "prev": prev, "key": key })
	return SimUtil.stable_sort(out, func(a, b): return b.key - a.key)

## handicap weights for a field (JRA style): top weight from the top mark, others 1 kg per 2.2 lb below it,
## younger horses also get their weight-for-age, limits 49–59.5 kg
static func handicap_weights(field: Array) -> Dictionary:
	var marks := {}
	var top := -1e9
	for h in field:
		var m = mark(h)
		var mv := float(m) if m != null else 70.0 + (Career.rating(h) - 60.0) * 3.0
		mv -= wfa(int(h.age), Career.W.week)       # marks are at weight-for-age: take the allowance back out
		marks[int(h.id)] = mv
		top = maxf(top, mv)
	var top_kg := clampf(57.0 + (top - 110.0) / LB_PER_KG * 0.5, 56.0, 59.5)
	var out := {}
	for h in field:
		var kg := top_kg - (top - float(marks[int(h.id)])) / LB_PER_KG
		out[int(h.id)] = clampf(snappedf(kg, 0.5), 49.0, 59.5)
	return out

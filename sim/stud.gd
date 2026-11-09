class_name Stud
extends RefCounted
## Step 3 — breeding season, stallions at stud, pregnancies, foaling, young-horse development and scouting knowledge.
## Pure logic on Career.W / Breeding.book, using the world RNG (Career.R), so careers stay deterministic.
##
## Real-world basis (see the project note "step3-breeding"):
##  * JBBA breeding season 10 Feb – 30 Jun; gestation ≈ 340 days; oestrous cycle 21 days, foal heat ~9 days after foaling.
##  * Per-cycle pregnancy ≈ 55–60% (Newmarket 59.9%, Australia 54.7%, NZ first cycle 53.6%); end-of-season pregnancy ≈ 85–95%;
##    live foal rate ≈ 70–83%; pregnancy loss 12–21% (higher in older and barren mares); twins in 8–13% of pregnancies.
##  * Mare fertility falls from about age 11 (Japanese broodmare study, Fawcett et al. 2021); first foals ~15% lighter at birth.
##  * Inbreeding: +10% F_ROH ≈ 7% lower chance of ever racing and fewer starts (Hill et al. 2022; Anim Genet 2023).
##  * Stud fees in Japan ¥0.5M … ¥25M (Kitasan Black 2026), books up to ~200 mares; fee paid on a live foal (出生条件).
##  * Breeding values: accuracy grows with information (own record, progeny test); nicks have no proven genetic effect, so
##    the game only reports observed cross statistics.

const SEASON_START := 6       # week of 10 Feb
const SEASON_END := 26        # week of 30 Jun
const CYCLE := 3              # weeks between heats
const GEST := 48.9            # weeks (≈ 342 days)
const P_CYCLE := 0.58
const P_TWIN := 0.10
const P_EARLY_LOSS := 0.07    # by day ~42
const P_LATE_LOSS := 0.07     # day 42 to term (incl. twins lost)
const UNRACED_BASE := 0.09    # 2yo that never make the races (plus inbreeding)
const MAX_MARE_AGE := 20

static var _prog_cache := {}
static var force_plan := {}     # test tool: mare id -> stallion id (overrides the world breeders' choice)
static var _prog_key := -1

# ---------------------------------------------------------------- helpers
static func abs_week(y: int, w: int) -> int: return y * 52 + w
static func now() -> int: return abs_week(int(Career.W.year), int(Career.W.week))
static func week_of(a: int) -> int: return ((a - 1) % 52) + 1
static func year_of(a: int) -> int: return int((a - 1) / 52)
static func in_season(w := -1) -> bool:
	if w < 0: w = int(Career.W.week)
	return w >= SEASON_START and w <= SEASON_END
static func mine(h: Variant) -> bool: return h != null and Career.W.stable.has(int(h.id))
static func _rng() -> float: return Career.rng()

## deterministic pseudo-normal number (−3…3) per horse and key: used for the fixed "scouting error" of each estimate
static func hnoise(id: int, key: int) -> float:
	var s := 0.0
	for i in 3:
		var x := sin(float(id) * 12.9898 + float(key * 3 + i) * 78.233) * 43758.5453
		s += x - floor(x)
	return (s - 1.5) * 2.0

static func repro(m: Dictionary) -> Dictionary:
	if not m.has("repro"):
		m["repro"] = { "st": "open", "due": -1, "sire": null, "next": null, "parity": 0, "plan": null, "heat": -1, "scan": -1, "cover": -1, "tries": 0, "lossAt": -1, "foals": [], "cover_sire": null, "conceived": false, "lastFoal": -99 }
	return m.repro

## overseas stallions the player can send mares to (Frankel, Dubawi, Into Mischief …)
static func overseas() -> Array:
	return Breeding.book.values().filter(func(h): return h.has("abroad"))

static func fee_text(s: Dictionary) -> String:
	var sd := stud(s)
	return ("~" if sd.get("feeEst", false) else "") + Game.money(float(sd.fee))

static func stud(s: Dictionary) -> Dictionary:
	if not s.has("stud"):
		s["stud"] = { "fee": 1.0, "cap": 10, "book": 0, "fert": 1.0, "since": int(Career.W.get("year", 2027)), "own": false }
	return s.stud

# ---------------------------------------------------------------- lines & families
## male line: the founder at the top of the sire line; female family: the founder mare at the bottom of the dam line
static func sire_line(h: Variant) -> String:
	if h == null: return "-"
	if h.has("line"): return h.line
	var s = Breeding.get_horse(h.sire)
	var v: String
	if h.get("lineRoot", false): v = String(h.name)
	else: v = (sire_line(s) if s != null else String(h.name)) if h.sire != null else String(h.name)
	h["line"] = v
	return v

static func family(h: Variant) -> String:
	if h == null: return "-"
	if h.has("fam"): return h.fam
	var d = Breeding.get_horse(h.dam)
	var v: String = (family(d) if d != null else String(h.name)) if h.dam != null else String(h.name)
	h["fam"] = v
	return v

## ancestors of a horse: id -> list of generations (1 = parent)
static func _anc(h: Variant, g: int, depth: int, out: Dictionary) -> void:
	if h == null or g > depth: return
	for pid in [h.sire, h.dam]:
		if pid == null: continue
		var p = Breeding.get_horse(pid)
		if p == null: continue
		if not out.has(int(pid)): out[int(pid)] = []
		out[int(pid)].append(g)
		_anc(p, g + 1, depth, out)

## duplicated ancestors in a planned mating, JRA style: [{name, sire_gens, dam_gens, label "3×4", pct}] sorted by blood share
static func duplicates(sire: Dictionary, dam: Dictionary, depth := 5) -> Array:
	var a := { int(sire.id): [0] }
	var b := { int(dam.id): [0] }
	_anc(sire, 1, depth - 1, a)
	_anc(dam, 1, depth - 1, b)
	var out: Array = []
	for id in a:
		if not b.has(id): continue
		var sg: Array = []
		for g in a[id]: sg.append(int(g) + 1)
		var dg: Array = []
		for g in b[id]: dg.append(int(g) + 1)
		var pct := 0.0
		for g in sg: pct += pow(0.5, g)
		for g in dg: pct += pow(0.5, g)
		sg.sort(); dg.sort()
		var h = Breeding.get_horse(id)
		var lab := "%s×%s" % ["·".join(sg.map(func(x): return str(x))), "·".join(dg.map(func(x): return str(x)))]
		out.append({ "id": id, "name": h.name if h != null else "?", "label": lab, "pct": pct * 100.0, "sg": sg, "dg": dg })
	out.sort_custom(func(x, y): return x.pct > y.pct)
	# drop ancestors that only appear through a closer duplicated ancestor (keep the nearest few)
	return out.slice(0, 6)

# ---------------------------------------------------------------- knowledge (scouting) and estimates
## how well the stable knows a horse's real ability: 0 (no idea) … 1 (exact)
static func know(h: Dictionary) -> float:
	var c: Dictionary = h.get("c", {})
	var starts := int(c.get("starts", 0))
	if mine(h): return clampf(float(c.get("know", 0.5)) + 0.04 * starts, 0.0, 0.97)
	var age := int(h.get("age", 3))
	var base := 0.12 if age == 0 else (0.2 if age == 1 else 0.3)
	return clampf(base + 0.07 * starts, 0.0, 0.9)

## an unraced young horse is judged mostly on its pedigree: what buyers (and its own connections) see is the
## expected ability from the parents, plus a little of its own (conformation, walk, how it moves at the breeze).
## Nobody can pick a champion as a yearling — the real ability only shows once it races.
const SEEN := { 0: 0.05, 1: 0.1, 2: 0.25 }      # share of the horse's own deviation from its pedigree that shows
static var _pex := {}                            # id → expected stats from the parents (fixed for life)

static func ped_expect(h: Dictionary) -> Variant:
	var id := int(h.id)
	if _pex.has(id): return _pex[id]
	var s = Breeding.get_horse(h.get("sire"))
	var d = Breeding.get_horse(h.get("dam"))
	var out = null
	if s != null and d != null and s.has("gv") and d.has("gv"):
		out = (Breeding.predict(s, d) as Dictionary).ev
	_pex[id] = out
	return out

static func seen_share(h: Dictionary) -> float:
	var c: Dictionary = h.get("c", {})
	if int(c.get("starts", 0)) > 0 or h.get("foreign") != null: return 1.0
	if String(c.get("status", "active")) != "active" or int(h.get("age", 3)) >= 3: return 1.0
	var w: float = SEEN.get(int(h.get("age", 0)), 0.4)
	if mine(h): w += 0.05                         # you see your own young horses every day
	return w

## estimated stat (what the trainer / public believes) and the ± range
static func est(h: Dictionary, k: String) -> int:
	var v: float = float(h.stats[k]) if h.stats.has(k) else float(h.get(k, 50))
	var w := seen_share(h)
	if w < 1.0:
		var ev = ped_expect(h)
		if ev != null and (ev as Dictionary).has(k): v = float(ev[k]) + w * (v - float(ev[k]))
	var kn := know(h)
	var idx: int = Breeding.STATS.find(k) + 1
	return int(clampf(roundf(v + hnoise(int(h.id), idx) * 7.0 * (1.0 - kn)), 1.0, 100.0))

static func est_dirt(h: Dictionary) -> int:
	return int(clampf(roundf(float(h.get("dirt", 50)) + hnoise(int(h.id), 11) * 10.0 * (1.0 - know(h))), 0.0, 100.0))

## growth type and going preference as the stable sees them (0–100)
static func est_side(h: Dictionary, k: String) -> int:
	var idx := 12 if k == "grow" else 13
	return int(clampf(roundf(float(h.get(k, 50)) + hnoise(int(h.id), idx) * 12.0 * (1.0 - know(h))), 0.0, 100.0))

static func est_range(h: Dictionary) -> int:
	return int(roundf(2.0 + 13.0 * (1.0 - know(h))))

static func est_stats(h: Dictionary) -> Dictionary:
	var o := {}
	for k in Breeding.STATS: o[k] = est(h, k)
	return o

## estimated racing rating (same weights as Career.rating) from the estimated stats
static func est_rating(h: Dictionary) -> float:
	var s := est_stats(h)
	return float(s.speed) * 0.25 + float(s.stamina) * 0.2 + float(s.burst) * 0.15 + float(s.accel) * 0.1 + float(s.strength) * 0.1 + float(s.guts) * 0.1 + float(s.agility) * 0.05 + float(s.wind) * 0.05

## estimated breeding value of a trait. Accuracy grows with information: own record and the number of raced offspring
## (progeny-test accuracy r² = n·h²/4 / (1 + (n−1)·h²/4)). Low accuracy shrinks the estimate toward the breed average.
static func accuracy(h: Dictionary, k: String) -> float:
	var h2: float = Breeding.H2[k]
	var own := h2 * clampf(know(h) + 0.2, 0.0, 1.0)
	var n := float(progeny(h).runners)
	var prog := n * h2 / 4.0 / (1.0 + (n - 1.0) * h2 / 4.0) if n > 0.0 else 0.0
	var ped := 0.12
	return clampf(1.0 - (1.0 - own) * (1.0 - prog) * (1.0 - ped), 0.05, 0.97)

static func ebv(h: Dictionary, k: String) -> float:
	var gv: float = float(h.gv.get(k, Breeding.mu(k)))
	var acc := accuracy(h, k)
	var idx: int = Breeding.TRAITS.find(k) + 20
	return Breeding.mu(k) + acc * (gv - Breeding.mu(k)) + hnoise(int(h.id), idx) * Breeding.SD * sqrt(Breeding.H2[k]) * sqrt(acc * (1.0 - acc)) * 0.8

# ---------------------------------------------------------------- progeny records (sire / dam evaluation)
static func progeny(h: Dictionary) -> Dictionary:
	var key := int(Career.W.get("year", 0)) * 100 + int(Career.W.get("week", 0))
	if key != _prog_key:
		_prog_cache = {}
		_prog_key = key
		_build_progeny()
	return _prog_cache.get(int(h.id), { "foals": 0, "runners": 0, "winners": 0, "graded": 0, "g1": 0, "earn": 0.0, "aei": 0.0, "dist": 0.0, "dirt": 0.0, "best": [] })

static func _build_progeny() -> void:
	var tot := 0.0
	var nr := 0
	var acc := {}
	for h in Breeding.book.values():
		var c = h.get("c")
		if c == null: continue
		for pid in [h.sire, h.dam]:
			if pid == null: continue
			var key := int(pid)
			if not acc.has(key): acc[key] = { "foals": 0, "runners": 0, "winners": 0, "graded": 0, "g1": 0, "earn": 0.0, "aei": 0.0, "dist": 0.0, "dirt": 0.0, "dn": 0, "best": [] }
			var a: Dictionary = acc[key]
			a.foals += 1
			if int(c.get("starts", 0)) > 0:
				a.runners += 1
				a.earn += float(c.get("earn", 0.0))
				if int(c.get("wins", 0)) > 0: a.winners += 1
				if int(c.get("graded", 0)) > 0:
					a.graded += 1
					if a.best.size() < 5: a.best.append(int(h.id))
				if int(c.get("g1", 0)) > 0: a.g1 += 1
				a.dist += Career.best_dist(h); a.dn += 1
				a.dirt += float(h.get("dirt", 50))
		if int(c.get("starts", 0)) > 0 and h.get("age", 0) != null:
			tot += float(c.get("earn", 0.0)); nr += 1
	var mean := tot / maxf(1.0, float(nr))
	for k in acc:
		var a: Dictionary = acc[k]
		if a.runners > 0:
			a.aei = (a.earn / a.runners) / maxf(0.01, mean)
			a.dist /= maxf(1.0, float(a.dn)); a.dirt /= float(a.runners)
		_prog_cache[k] = a

## observed results of a cross: sire line × broodmare-sire line ("nick" statistics, information only)
static func cross_stats(line_s: String, line_bms: String) -> Dictionary:
	var o := { "runners": 0, "winners": 0, "graded": 0 }
	for h in Breeding.book.values():
		var c = h.get("c")
		if c == null or int(c.get("starts", 0)) == 0 or h.sire == null or h.dam == null: continue
		var d = Breeding.get_horse(h.dam)
		if d == null or d.sire == null: continue
		if sire_line(Breeding.get_horse(h.sire)) != line_s: continue
		if sire_line(Breeding.get_horse(d.sire)) != line_bms: continue
		o.runners += 1
		if int(c.wins) > 0: o.winners += 1
		if int(c.graded) > 0: o.graded += 1
	return o

# ---------------------------------------------------------------- stallion market
## reputation → fee (¥M) and book size; called at the start of each season and when a stallion retires to stud
static func update_market() -> void:
	var st := Breeding.stallions()
	if st.is_empty(): return
	var reps: Array = []
	for s in st:
		var c: Dictionary = s.get("c", {})
		var z := (est_rating(s) - 64.0) / 6.0
		# breeders pay for the racing record: the horse's official (career-best) rating, when it has one
		var rb := Ratings.career_best(s)
		if rb > 0.0: z = 0.4 * z + 0.6 * (rb - 112.0) / 5.0
		z += 0.8 * minf(3.0, float(c.get("g1", 0))) + 0.25 * minf(4.0, float(c.get("graded", 0)))
		var pr := progeny(s)
		if pr.runners >= 3:
			var w := float(pr.runners) / (float(pr.runners) + 15.0)
			z = (1.0 - w) * z + w * (log(maxf(0.05, pr.aei)) * 2.2 + 0.6 * pr.g1 + 0.15 * pr.graded)
		if int(s.age) >= 18: z -= 0.6
		reps.append([s, z])
	reps.sort_custom(func(a, b): return a[1] < b[1])
	var n_mares := 0
	for m in Breeding.mares():
		if int(m.age) <= MAX_MARE_AGE: n_mares += 1
	var avg := float(n_mares) / float(st.size())
	for i in reps.size():
		var s: Dictionary = reps[i][0]
		var p := (float(i) + 0.5) / float(reps.size())
		var sd := stud(s)
		if sd.get("ownFee", 0.0) > 0.0: sd.fee = sd.ownFee
		elif sd.has("realFee") and not sd.get("mkt", false):
			sd.fee = sd.realFee; sd["mkt"] = true                     # first season: the real 2026 fee
		else:
			var target := clampf(0.5 * exp(3.9 * pow(p, 1.5)), 0.5, 25.0)
			if sd.get("mkt", false): target = clampf(target, float(sd.fee) * 0.7, float(sd.fee) * 1.3)   # fees move at most ±30% a year
			sd.fee = snappedf(target, 0.1 if target < 5.0 else 0.5)
			sd["mkt"] = true
		sd.cap = int(clampf(roundf(avg * (0.45 + 1.3 * p)), 4.0, roundf(avg * 2.2)))
		sd.rep = reps[i][1]
		sd.pct = p
		if not sd.has("fert") or sd.fert == 1.0: sd.fert = clampf(1.0 + Career.gauss() * 0.08, 0.8, 1.15)

# ---------------------------------------------------------------- season
## world breeders pension old or barren mares and send unpopular stallions away (export / regional studs),
## keeping about 18 mares per stallion as in a scaled-down Japanese market
static func _cull() -> void:
	var y := int(Career.W.year)
	for m in Breeding.mares():
		if mine(m): continue
		var r := repro(m)
		var a := int(m.age)
		var pr := progeny(m)
		var poor: bool = a >= 11 and pr.runners >= 3 and pr.winners == 0
		if (a >= 15 and r.st == "barren") or (a >= 17 and _rng() < 0.35) or (poor and _rng() < 0.35) or (r.st == "barren" and int(r.get("barrenRun", 0)) >= 2):
			m.retired = false
			if m.has("c"): m.c.status = "retired"
	var st: Array = Breeding.stallions().filter(func(s): return not mine(s))
	var nm := Breeding.mares().size()
	var keep := maxi(34, int(nm / 12.0))   # Japan 2026: ~34 well-known stallions in this scaled-down world
	st.sort_custom(func(a, b): return float(stud(a).get("rep", 0.0)) < float(stud(b).get("rep", 0.0)))
	var n_all := Breeding.stallions().size()
	for s in st:
		if n_all <= keep: break
		var sd := stud(s)
		if y - int(sd.get("since", y)) < 3: continue        # new stallions get three seasons
		s.retired = false
		if s.has("c"): s.c.status = "retired"
		n_all -= 1
		if int(s.c.get("graded", 0)) > 0: Career.log_msg("%s has been exported (stud career in Japan ended)" % s.name, s)


## world mares choose stallions: better mares go to dearer stallions, books are capped
## preference of a breeder aiming at the dirt (or turf) market for a stallion, from the surface his foals lean to
## (real Japan: about half of all JRA races, and most local races, are on dirt, and dirt sires cover big books)
static func market_w(s: Dictionary, dirt_market: bool) -> float:
	var b := (float(s.gv.get("dirt", 50.0)) - 50.0) / 25.0
	return exp(clampf(1.4 * b if dirt_market else -0.8 * b, -3.0, 3.0))

static func _ai_matings() -> void:
	_cull()
	var st := Breeding.stallions()
	if st.is_empty(): return
	for s in st: stud(s).book = 0
	for m in Breeding.mares():
		if mine(m): continue
		var r := repro(m)
		r["plan"] = null
	# player bookings count first
	for m in Breeding.mares():
		if mine(m) and repro(m).plan != null:
			var s = Breeding.get_horse(repro(m).plan)
			if s != null: stud(s).book += 1
	var ms: Array = Breeding.mares().filter(func(x): return not mine(x) and int(x.age) <= MAX_MARE_AGE)
	ms = SimUtil.stable_sort(ms, func(a, b): return Game_mare_value(b) - Game_mare_value(a))
	for i in ms.size():
		var m: Dictionary = ms[i]
		if _rng() < 0.05: continue                          # rested this year
		if force_plan.has(int(m.id)):
			var fs = Breeding.get_horse(force_plan[int(m.id)])
			if fs != null:
				stud(fs).book += 1
				_ai_outcome(m, fs)
				continue
		var q := float(i) / maxf(1.0, float(ms.size()))   # 0 = best mare
		# breeders aim at the turf or the dirt market: dirt-type mares (and some others) go to dirt sires
		var dm := float(m.get("dirt", 50)) >= 55.0 or (float(m.get("dirt", 50)) >= 35.0 and _rng() < 0.5)
		var wts: Array = []
		var tot := 0.0
		for s in st:
			var sd := stud(s)
			var w := 0.0
			if sd.book < sd.cap and Breeding.kin(s, m) < 0.09:
				w = exp(float(sd.get("pct", 0.5)) * (4.0 - 4.5 * q)) * market_w(s, dm)
			wts.append(w); tot += w
		if tot <= 0.0: continue
		var u := _rng() * tot
		var pick: Dictionary = st[0]
		for j in st.size():
			u -= wts[j]
			if u <= 0.0:
				pick = st[j]
				break
		stud(pick).book += 1
		_ai_outcome(m, pick)

static func Game_mare_value(m: Dictionary) -> float:
	var c: Dictionary = m.get("c", {})
	var pr := progeny(m)
	return est_rating(m) + 6.0 * minf(2.0, float(c.get("graded", 0))) + 3.0 * float(pr.graded) + 2.0 * log(1.0 + float(pr.winners))

static func mare_age_factor(m: Dictionary) -> float:
	var a := int(m.age)
	return 1.0 if a <= 10 else (0.93 if a <= 13 else (0.84 if a <= 16 else 0.72))

static func _p_conceive(m: Dictionary, s: Dictionary, foal_heat: bool) -> float:
	var r := repro(m)
	var stf: float = 0.95 if int(r.parity) == 0 else (0.9 if r.st == "barren" else 1.0)
	return clampf(P_CYCLE * mare_age_factor(m) * float(stud(s).get("fert", 1.0)) * stf * (0.85 if foal_heat else 1.0), 0.05, 0.9)

static func _p_loss(m: Dictionary) -> float:
	var r := repro(m)
	var a := int(m.age)
	var ak := 1.0 if a <= 12 else (1.4 if a <= 15 else 1.9)
	return (P_EARLY_LOSS + P_LATE_LOSS) * ak * (1.3 if r.st == "barren" else 1.0)

## seasonal anoestrus: most mares only start cycling in March–April (earlier with lights); week of the first heat this year
static func onset(m: Dictionary, y: int) -> int:
	return clampi(int(roundf(12.5 + hnoise(int(m.id), y) * 1.6)), SEASON_START, 17)

static func _due(cover: int) -> int:
	var d := cover + int(roundf(GEST + Career.gauss() * 1.4))
	return maxi(d, abs_week(year_of(cover) + 1, 2))      # no foals before the New Year birthday

## world mares: roll the whole season at once (cover week, cycles, loss) and set the due week
static func _ai_outcome(m: Dictionary, s: Dictionary) -> void:
	var r := repro(m)
	var y := int(Career.W.year)
	var start := onset(m, y)
	var fh := false
	if r.due > 0 and year_of(r.due) == y:
		fh = _rng() < 0.5                                 # about half are covered on the foal heat
		start = maxi(SEASON_START, week_of(r.due) + (1 if fh else 4))
	var w := start
	while w <= SEASON_END:
		if _rng() < _p_conceive(m, s, fh):
			if _rng() < _p_loss(m): return                   # lost later in pregnancy: barren next year
			var due := _due(abs_week(y, w))
			var preg := { "due": due, "sire": int(s.id), "cover": abs_week(y, w) }
			if r.due > 0 and r.due >= now(): r["next"] = preg   # still carrying this year's foal
			else:
				r.due = due; r.sire = int(s.id); r.st = "in_foal"
			return
		w += CYCLE if not fh else 2
		fh = false

## player: book a stallion for a mare (this or next season). Returns "ok" or why not.
static func book(mare_id: int, stallion_id: int) -> String:
	var m = Breeding.get_horse(mare_id)
	var s = Breeding.get_horse(stallion_id)
	if m == null or s == null: return "not found"
	if not mine(m): return "not your mare"
	if int(m.age) > MAX_MARE_AGE: return "mare too old"
	var r := repro(m)
	if r.plan != null and int(r.plan) == stallion_id: return "already booked"
	var sd := stud(s)
	if s.get("c", {}).get("status", "") != "stud" and not s.has("abroad"): return "not at stud"
	if sd.book >= sd.cap and not mine(s): return "book full"
	if r.plan != null:
		var old = Breeding.get_horse(r.plan)
		if old != null: stud(old).book = maxi(0, stud(old).book - 1)
	r.plan = stallion_id
	sd.book += 1
	var y := int(Career.W.year) + (1 if int(Career.W.week) > SEASON_END else 0)
	if r.heat < 0 or r.heat < now(): r.heat = maxi(now(), abs_week(y, onset(m, y)))
	if s.has("abroad"):
		Career.log_msg("%s booked to %s in %s (fee ¥%.1fM on a live foal; shipping and boarding about ¥%.0fM)" % [m.name, s.name, s.abroad, sd.fee, Bloodlines.ABROAD_COST], m)
	else:
		Career.log_msg("%s booked to %s (fee ¥%.1fM on a live foal)" % [m.name, s.name, sd.fee], m)
	return "ok"

static func cancel(mare_id: int) -> void:
	var m = Breeding.get_horse(mare_id)
	if m == null: return
	var r := repro(m)
	if r.plan != null:
		var s = Breeding.get_horse(r.plan)
		if s != null: stud(s).book = maxi(0, stud(s).book - 1)
	r.plan = null

## mare status in words
static func mare_status(m: Dictionary) -> String:
	var r := repro(m)
	var t := ""
	if r.due > 0:
		var s = Breeding.get_horse(r.sire)
		t = "In foal to %s · due %s" % [s.name if s != null else "?", _date(r.due)]
	elif r.scan > 0: t = "Covered by %s · scan %s" % [_name(r.sire), _date(r.scan)]
	elif r.st == "barren": t = "Barren this year"
	else: t = "Open (not in foal)"
	if r.next != null: t += " · in foal again to %s" % _name(r.next.sire)
	if r.plan != null and r.due < 0 and r.scan < 0: t += " · booked to %s" % _name(r.plan)
	return t

static func _name(id: Variant) -> String:
	var h = Breeding.get_horse(id)
	return h.name if h != null else "?"

static func _date(a: int) -> String:
	return Game.date_text(year_of(a), week_of(a)).substr(4)

# ---------------------------------------------------------------- weekly tick
static func week_tick() -> void:
	var W := Career.W
	var w := int(W.week)
	var t := now()
	if w == SEASON_START:
		update_market()
		_ai_matings()
		for m in Breeding.mares():
			if mine(m):
				Career.log_msg("The breeding season is open (10 Feb – 30 Jun). %s: %s" % [m.name, mare_status(m)], m)
				if repro(m).plan == null and int(m.age) <= MAX_MARE_AGE:
					Career.log_msg("⚠ %s has no stallion booked — open Breeding › Mating planner to choose one." % m.name, m)
	# foalings
	for m in Breeding.mares():
		var r := repro(m)
		if r.due > 0 and r.due <= t:
			_foal(m)
	# player mares: covers, scans and losses
	for id in W.stable.duplicate():
		var m = Breeding.get_horse(id)
		if m == null or m.sex != "F" or not m.get("retired", false): continue
		_player_mare(m, t)
	if w == SEASON_END + 1:
		for m in Breeding.mares():
			var r := repro(m)
			if r.due < 0 and r.scan < 0:
				r.st = "barren"; r["barrenRun"] = int(r.get("barrenRun", 0)) + 1
			else: r["barrenRun"] = 0
			r.plan = null if not mine(m) else r.plan
			if mine(m) and r.due < 0:
				Career.log_msg("%s ends the season barren (not in foal)." % m.name, m)
				r.plan = null
	_young_stock(w)

static func _player_mare(m: Dictionary, t: int) -> void:
	var r := repro(m)
	var w := week_of(t)
	# late pregnancy loss
	if r.lossAt > 0 and r.lossAt <= t and r.due > 0:
		r.lossAt = -1
		Career.log_msg("%s has lost her foal (pregnancy loss)." % m.name, m)
		r.due = -1; r.sire = null; r.st = "barren"
		if in_season(w) and r.plan != null: r.heat = t + 2
	# scan result
	if r.scan > 0 and r.scan <= t:
		var s = Breeding.get_horse(r.cover_sire) if r.has("cover_sire") else null
		r.scan = -1
		if r.get("conceived", false):
			var twins := _rng() < P_TWIN
			r.due = _due(r.cover); r.sire = r.cover_sire; r.st = "in_foal"
			var lost := _rng() < _p_loss(m) * (1.4 if twins else 1.0)
			if lost: r.lossAt = r.cover + 4 + int(floor(_rng() * 30.0))
			Career.log_msg("%s scanned in foal to %s%s — due %s" % [m.name, s.name if s != null else "?", " (twins found; the vet reduced to one)" if twins else "", _date(r.due)], m)
			r.plan = null; r.tries = 0; r["shipped"] = false
		else:
			r.tries += 1
			if in_season(w): r.heat = r.cover + CYCLE
			Career.log_msg("%s is not in foal to %s%s" % [m.name, s.name if s != null else "?", " — she'll be covered again next heat" if in_season(w) and r.plan != null else ""], m)
	# cover at the next heat
	if r.plan != null and r.due < 0 and r.scan < 0 and in_season(w) and r.heat <= t and int(m.age) <= MAX_MARE_AGE:
		var s = Breeding.get_horse(r.plan)
		if s == null: r.plan = null; return
		var fh: bool = r.get("lastFoal", -99) >= t - 2
		r.cover = t; r.cover_sire = int(s.id)
		if s.has("abroad") and not r.get("shipped", false):
			r["shipped"] = true
			Career.ledger("Shipping and boarding: %s to %s (%s)" % [m.name, s.name, s.abroad], -Bloodlines.ABROAD_COST, "travel")
		r.conceived = _rng() < _p_conceive(m, s, fh)
		r.scan = t + 2
		Career.log_msg("%s covered by %s%s" % [m.name, s.name, " (foal heat)" if fh else ""], m)

static func _foal(m: Dictionary) -> void:
	var r := repro(m)
	var s = Breeding.get_horse(r.sire)
	var due: int = r.due
	r.due = -1
	if s == null:
		r.sire = null
	else:
		var foal := Career.make_horse(s, m, Career.R, int(Career.W.year))
		foal["foaled"] = week_of(due)
		var bw0 := 55.0 * (0.85 if int(r.parity) == 0 else (0.95 if int(r.parity) == 1 else 1.0)) + Career.gauss() * 4.0 + (0.6 if foal.sex == "M" else -0.6)
		foal["birthW"] = int(roundf(bw0))
		foal.c["know"] = 0.15
		r.parity = int(r.parity) + 1
		r["lastFoal"] = now()
		if not r.has("foals"): r["foals"] = []
		r.foals.append(int(foal.id))
		if mine(m):
			foal["bredBy"] = "player"
			Career.add_to_stable(int(foal.id))
			Career.log_msg("%s has foaled: a %s %s by %s (%d kg)" % [m.name, foal.coat, "colt" if foal.sex == "M" else "filly", s.name, foal.birthW], foal)
			Career.ledger("Stud fee: %s (%s)" % [s.name, m.name], -float(stud(s).fee), "stud")
		elif mine(s):
			Career.ledger("Stud fee received: %s × %s" % [s.name, m.name], float(stud(s).fee), "stud_in")
	r.sire = null
	r.st = "foaled"
	if r.next != null:
		r.due = r.next.due; r.sire = r.next.sire; r.st = "in_foal"; r.next = null
	elif mine(m) and r.plan != null and in_season():
		r.heat = now() + 1   # foal heat

## young horses: weaning, yearling, breaking-in, pre-training; the never-raced; scouting knowledge for own horses
static func _young_stock(w: int) -> void:
	for h in Career.active():
		var a := int(h.age)
		if a > 2: continue
		var c: Dictionary = h.c
		var my := mine(h)
		if a == 2 and w == 10 and c.starts == 0 and not c.get("devChecked", false):
			c["devChecked"] = true
			if _rng() < UNRACED_BASE + 0.7 * float(h.get("F", 0.0)):
				Career.retire(h, "did not make the races (developmental problems)")
				continue
		if not my: continue
		var k: float = float(c.get("know", 0.15))
		if a == 0 and w == 34: k = maxf(k, 0.22); Career.log_msg("%s has been weaned." % h.name, h)
		elif a == 1 and w == 1: k = maxf(k, 0.3); Career.log_msg("%s is now a yearling." % h.name, h)
		elif a == 1 and w == 40: k = maxf(k, 0.45); Career.log_msg("%s has been broken in and starts pre-training." % h.name, h)
		elif a == 2 and w == 12: k = maxf(k, 0.55); Career.log_msg("%s has moved to the training centre." % h.name, h)
		elif a == 2 and w > 12: k = minf(0.75, k + 0.004)
		c["know"] = k

# ---------------------------------------------------------------- player decisions
static func to_stud(h: Dictionary) -> String:
	var c: Dictionary = h.c
	if c.status != "active" and c.status != "retired": return "not available"
	if h.sex == "M":
		c.status = "stud"; h["retired"] = true
		var sd := stud(h)
		sd.since = int(Career.W.year); sd.own = mine(h)
		update_market()
		Career.log_msg("%s retires to stud (fee ¥%.1fM)" % [h.name, sd.fee], h)
	else:
		c.status = "broodmare"; h["retired"] = true
		repro(h)
		Career.log_msg("%s retires to the breeding shed" % h.name, h)
	c["retiredYear"] = Career.W.year
	return "ok"

static func set_fee(s: Dictionary, fee: float) -> void:
	stud(s)["ownFee"] = clampf(fee, 0.3, 30.0)
	stud(s).fee = stud(s).ownFee

# ---------------------------------------------------------------- planner
## everything the mating screen shows for one mare × stallion (estimates only — nobody knows the true genes)
static func plan(m: Dictionary, s: Dictionary) -> Dictionary:
	var F := Breeding.kin(s, m)
	var ev := {}
	for k in Breeding.TRAITS:
		ev[k] = (ebv(s, k) + ebv(m, k)) / 2.0 - F * (60.0 if k == "sound" else (0.0 if Breeding.SIDE.has(k) else 12.0))
	var pr := Breeding.predict(s, m)
	var rate: float = ev.speed * 0.25 + ev.stamina * 0.2 + ev.burst * 0.15 + ev.accel * 0.1 + ev.strength * 0.1 + ev.guts * 0.1 + ev.agility * 0.05 + ev.wind * 0.05
	# MSTN shifts burst / stamina (same as founders)
	var dist: float = pr.mstn.CC * 1350.0 + pr.mstn.CT * 1850.0 + pr.mstn.TT * 2400.0 + (ev.stamina - ev.burst) * 12.0
	var bms = Breeding.get_horse(m.sire)
	var cross := cross_stats(sire_line(s), sire_line(bms)) if bms != null else { "runners": 0, "winners": 0, "graded": 0 }
	var raced := clampf(1.0 - UNRACED_BASE - 0.7 * F, 0.0, 1.0)
	var acc := (accuracy(s, "speed") + accuracy(m, "speed")) / 2.0
	return { "F": F, "ev": ev, "rating": rate, "spread": 3.5 + 3.0 * (1.0 - acc), "mstn": pr.mstn, "coat": pr.coat, "dist": clampf(dist, 1000.0, 3400.0),
		"dirt": ev.dirt, "dups": duplicates(s, m), "cross": cross, "raced": raced, "fee": float(stud(s).fee), "acc": acc,
		"p_live": _p_season(m, s) }

## chance of a live foal from one season with this stallion
static func _p_season(m: Dictionary, s: Dictionary) -> float:
	var pc := _p_conceive(m, s, false)
	var cycles := 6.0
	return (1.0 - pow(1.0 - pc, cycles)) * (1.0 - _p_loss(m))

class_name Career
extends RefCounted
## Career mode v0.5 (GDScript port of career.js). Pure logic.
## A scaled JRA world (~1/10 size): weekly calendar, real class ladder (earnings-based, no relegation),
## G1/G2/G3 calendar, aging curve, training (fitness/fatigue), injuries, retirement and stud.
## Races containing the player's horses run in the full physics engine; other races use a quick model
## built from the same engine parameters (critical speed / reserve / top speed).


# ---------- calendar ----------
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
# two meetings per week in this scaled world: a main track and a second track (summer = local tracks)
const VENUES := { 1: ["nakayama", "kyoto"], 2: ["tokyo", "kokura"], 3: ["nakayama", "hanshin"], 4: ["hanshin", "fukushima"], 5: ["tokyo", "kyoto"], 6: ["tokyo", "hakodate"],
	7: ["fukushima", "chukyo"], 8: ["niigata", "sapporo"], 9: ["nakayama", "hanshin"], 10: ["tokyo", "kyoto"], 11: ["tokyo", "kyoto"], 12: ["nakayama", "hanshin"] }
const VENUE_COURSES := {
	"tokyo": { "turf": ["tokyo"], "dirt": ["tokyo_d"] }, "nakayama": { "turf": ["nakayama", "nakayama_o"], "dirt": ["nakayama_d"] }, "kyoto": { "turf": ["kyoto", "kyoto_i"], "dirt": ["kyoto_d"] },
	"hanshin": { "turf": ["hanshin", "hanshin_i"], "dirt": ["hanshin_d"] }, "niigata": { "turf": ["niigata", "niigata_i", "niigata_s"], "dirt": ["niigata_d"] }, "chukyo": { "turf": ["chukyo"], "dirt": ["chukyo_d"] },
	"fukushima": { "turf": ["fukushima"], "dirt": ["fukushima_d"] }, "kokura": { "turf": ["kokura"], "dirt": ["kokura_d"] }, "sapporo": { "turf": ["sapporo"], "dirt": ["sapporo_d"] }, "hakodate": { "turf": ["hakodate"], "dirt": ["hakodate_d"] },
}
# graded races: [name, grade, week, course, dist, age ('2','3','3+','4+'), sex ('F' or ''), handicap]
const GRADED := [
	["Nakayama Kimpai", "G3", 1, "nakayama", 2000, "4+", "", 1], ["Nikkei Shinshun Hai", "G2", 3, "kyoto", 2400, "4+", "", 0], ["AJCC", "G2", 4, "nakayama_o", 2200, "4+", "", 0],
	["Tokai S", "G2", 4, "chukyo_d", 1800, "4+", "", 0], ["Kyodo News Hai", "G3", 6, "tokyo", 1800, "3", "", 0], ["Diamond S", "G3", 7, "tokyo", 3400, "4+", "", 1],
	["February S", "G1", 8, "tokyo_d", 1600, "4+", "", 0], ["Nakayama Kinen", "G2", 9, "nakayama", 1800, "4+", "", 0], ["Tulip Sho", "G2", 9, "hanshin", 1600, "3", "F", 0],
	["Yayoi Sho", "G2", 10, "nakayama", 2000, "3", "", 0], ["Kinko Sho", "G2", 11, "chukyo", 2000, "4+", "", 0], ["Fillies Revue", "G2", 11, "hanshin_i", 1400, "3", "F", 0],
	["Spring S", "G2", 11, "nakayama", 1800, "3", "", 0], ["Hanshin Daishoten", "G2", 12, "hanshin_i", 3000, "4+", "", 0], ["Nikkei Sho", "G2", 12, "nakayama", 2500, "4+", "", 0],
	["Takamatsunomiya Kinen", "G1", 13, "chukyo", 1200, "4+", "", 0], ["Osaka Hai", "G1", 14, "hanshin_i", 2000, "4+", "", 0], ["Oka Sho", "G1", 15, "hanshin", 1600, "3", "F", 0],
	["Satsuki Sho", "G1", 16, "nakayama", 2000, "3", "", 0], ["Aoba Sho", "G2", 17, "tokyo", 2400, "3", "", 0], ["Flora S", "G2", 17, "tokyo", 2000, "3", "F", 0],
	["Antares S", "G3", 17, "hanshin_d", 1800, "4+", "", 0], ["Tenno Sho (Spring)", "G1", 18, "kyoto", 3200, "4+", "", 0], ["Kyoto Shimbun Hai", "G2", 18, "kyoto", 2200, "3", "", 0],
	["NHK Mile Cup", "G1", 19, "tokyo", 1600, "3", "", 0], ["Victoria Mile", "G1", 20, "tokyo", 1600, "4+", "F", 0], ["Yushun Himba (Oaks)", "G1", 21, "tokyo", 2400, "3", "F", 0],
	["Tokyo Yushun (Derby)", "G1", 22, "tokyo", 2400, "3", "", 0], ["Meguro Kinen", "G2", 22, "tokyo", 2500, "4+", "", 1], ["Yasuda Kinen", "G1", 23, "tokyo", 1600, "3+", "", 0],
	["Takarazuka Kinen", "G1", 25, "hanshin_i", 2200, "3+", "", 0], ["Hakodate Kinen", "G3", 28, "hakodate", 2000, "3+", "", 1], ["Procyon S", "G3", 28, "chukyo_d", 1400, "3+", "", 0],
	["Kokura Kinen", "G3", 31, "kokura", 2000, "3+", "", 1], ["Sapporo Kinen", "G2", 34, "sapporo", 2000, "3+", "", 0], ["Niigata Kinen", "G3", 35, "niigata_i", 2000, "3+", "", 1],
	["Sapporo Nisai S", "G3", 36, "sapporo", 1800, "2", "", 0], ["Centaur S", "G2", 37, "hanshin_i", 1200, "3+", "", 0], ["Rose S", "G2", 37, "hanshin", 1800, "3", "F", 0],
	["Shion S", "G2", 37, "nakayama", 2000, "3", "F", 0], ["St Lite Kinen", "G2", 38, "nakayama_o", 2200, "3", "", 0], ["Kobe Shimbun Hai", "G2", 38, "hanshin", 2400, "3", "", 0],
	["All Comers", "G2", 38, "nakayama_o", 2200, "3+", "", 0], ["Sprinters S", "G1", 39, "nakayama_o", 1200, "3+", "", 0], ["Sirius S", "G3", 39, "hanshin_d", 2000, "3+", "", 1],
	["Mainichi Okan", "G2", 41, "tokyo", 1800, "3+", "", 0], ["Kyoto Daishoten", "G2", 41, "kyoto", 2400, "3+", "", 0], ["Saudi Arabia Royal Cup", "G3", 41, "tokyo", 1600, "2", "", 0],
	["Shuka Sho", "G1", 42, "kyoto_i", 2000, "3", "F", 0], ["Kikuka Sho", "G1", 43, "kyoto", 3000, "3", "", 0], ["Tenno Sho (Autumn)", "G1", 44, "tokyo", 2000, "3+", "", 0],
	["Swan S", "G2", 44, "kyoto_i", 1400, "3+", "", 0], ["Copa Republica Argentina", "G2", 45, "tokyo", 2500, "3+", "", 1], ["Keio Hai Nisai S", "G2", 45, "tokyo", 1400, "2", "", 0],
	["Queen Elizabeth II Cup", "G1", 46, "kyoto", 2200, "3+", "F", 0], ["Tokyo Sports Hai Nisai S", "G2", 46, "tokyo", 1800, "2", "", 0], ["Musashino S", "G3", 46, "tokyo_d", 1600, "3+", "", 0],
	["Mile Championship", "G1", 47, "kyoto", 1600, "3+", "", 0], ["Japan Cup", "G1", 48, "tokyo", 2400, "3+", "", 0], ["Champions Cup", "G1", 49, "chukyo_d", 1800, "3+", "", 0],
	["Stayers S", "G2", 49, "nakayama", 3600, "3+", "", 0], ["Hanshin Juvenile Fillies", "G1", 50, "hanshin", 1600, "2", "F", 0], ["Asahi Hai Futurity S", "G1", 51, "hanshin", 1600, "2", "", 0],
	["Hanshin Cup", "G2", 51, "hanshin_i", 1400, "3+", "", 0], ["Arima Kinen", "G1", 52, "nakayama", 2500, "3+", "", 0], ["Hopeful S", "G1", 52, "nakayama", 2000, "2", "", 0],
]
const PRIZE := { "NEW": 7.0, "MDN": 5.5, "1W": 8.0, "2W": 10.5, "3W": 15.0, "OP": 24.0, "G3": 40.0, "G2": 60.0, "G1": 150.0 }      # winner, million yen
const BIG_G1 := { "Japan Cup": 500.0, "Arima Kinen": 500.0, "Tokyo Yushun (Derby)": 300.0, "Tenno Sho (Autumn)": 300.0, "Tenno Sho (Spring)": 300.0, "Takarazuka Kinen": 300.0, "Osaka Hai": 300.0 }
const PLACE_SHARE := [1.0, 0.4, 0.25, 0.15, 0.1]
const CLASS_GAIN := { "NEW": 4.0, "MDN": 4.0, "1W": 5.0, "2W": 6.0, "3W": 9.0, "OP": 10.0, "G3": 20.0, "G2": 27.0, "G1": 50.0 }   # class money added for a win (graded 2nd = half)
const CLASS_NAMES := { "NEW": "Newcomer", "MDN": "Maiden", "1W": "1-Win", "2W": "2-Win", "3W": "3-Win", "OP": "Open", "G3": "G3", "G2": "G2", "G1": "G1" }
const TIERS := ["G1 champion", "Graded winner", "Open", "3-Win", "2-Win", "1-Win", "Maiden", "Unraced", "At stud", "Broodmare", "Retired"]
const GRADE_RANK := { "G1": 0, "G2": 1, "G3": 2, "OP": 3 }
const LOAD := { "rest": 0.0, "light": 0.4, "normal": 0.7, "hard": 1.0 }
# aging curve (Takahashi 2015 shape; sprinters peak a little earlier, stayers later)
const AGE_PTS := [[2.0, 0.978], [2.4, 0.982], [3.0, 0.988], [3.2, 0.989], [3.4, 0.993], [3.75, 0.996], [3.9, 0.998], [4.5, 1.0], [5.9, 1.0], [6.9, 0.996], [7.9, 0.99], [8.9, 0.98], [10.0, 0.965]]

static var W: Dictionary = {}
static var R: SimRng = SimRng.new(1)     # world RNG (its state is W.rngState in saves)
static var QCACHE: Dictionary = {}
static var QSIG := 0.0065
const QOFF := 1.0127
const JOCKEY_REF := 70.0   # engine scale of the average ride (People adds 10 to the skill)
static var PACK := 0.38               # finishing-gap factor of the quick model (see run_race)
const CAUTION_RISK := 2.5          # in-race injury risk of a horse running while on caution
static var ENTRY_MIN := 1.2          # trainers only enter horses whose suitability score clears this
static var BUCKETS := true           # (test switch: entry-pool buckets on/off give identical fields)
static var CLS_W := { "1W": 10.0, "2W": 4.0, "3W": 1.8, "OP": 4.0 }   # condition-race weights (older horses)
static var TRANSFER_BAD := 4         # runs in a row finishing in the bottom part of the field before an AI horse leaves for local racing
static var TRANSFER_FRAC := 0.6
static var force_full := false   # test tool: run every race in the full engine


static func month_of_week(w: int) -> int:
	return mini(12, int(floor((w - 1) / 4.34)) + 1)

static func rng() -> float: return R.next()
static func gauss() -> float: return R.gauss()

static func age_factor(h: Dictionary, w: int) -> float:
	# growth type (inherited, 50 = normal): early developers are up to ~4 months "older" at 2 and peak/decline
	# earlier; late developers the reverse. Sprinters (CC) mature a little earlier, stayers (TT) later.
	var grow := (float(h.get("grow", 50)) - 50.0) / 50.0
	var a: float = float(h.age) + (w - 1) / 52.0 + (0.12 if h.gene == "CC" else (-0.12 if h.gene == "TT" else 0.0)) + 0.3 * grow
	for i in range(1, AGE_PTS.size()):
		if a <= AGE_PTS[i][0]:
			var a0: float = AGE_PTS[i - 1][0]
			var f0: float = AGE_PTS[i - 1][1]
			var a1: float = AGE_PTS[i][0]
			var f1: float = AGE_PTS[i][1]
			return f0 + (f1 - f0) * clampf((a - a0) / (a1 - a0), 0.0, 1.0)
	return 0.94

static func class_of(c: Dictionary) -> String:
	if int(c.wins) == 0: return "MDN"
	var cm: float = c.cm
	if cm <= 5.0: return "1W"
	if cm <= 10.0: return "2W"
	if cm <= 16.0: return "3W"
	return "OP"

static func tier_of(h: Dictionary) -> String:
	var c = h.get("c")
	if c == null: return "Unraced"
	if c.status == "stud": return "At stud"
	if c.status == "broodmare": return "Broodmare"
	if c.status == "retired": return "Retired"
	if c.g1 > 0: return "G1 champion"
	if c.graded > 0: return "Graded winner"
	if c.starts == 0: return "Unraced"
	return CLASS_NAMES[class_of(c)]

## best distance from the speed gene and stamina/burst balance
static func best_dist(h: Dictionary) -> float:
	return RaceEngine.best_dist(h)

static func rating(h: Dictionary) -> float:
	var s: Dictionary = h.stats
	return float(s.speed) * 0.25 + float(s.stamina) * 0.2 + float(s.burst) * 0.15 + float(s.accel) * 0.1 + float(s.strength) * 0.1 + float(s.guts) * 0.1 + float(s.agility) * 0.05 + float(s.wind) * 0.05

static func _in_stable(id: Variant) -> bool:
	return W.stable.has(int(id))


# ---------- world ----------
static func new_career(_h: Dictionary, born: int) -> Dictionary:
	return { "born": born, "starts": 0, "wins": 0, "places": 0, "earn": 0.0, "cm": 0.0, "g1": 0, "graded": 0, "bigWins": [], "status": "active", "fit": 0.7, "fat": 0.0, "out": 0, "last": -99.0, "entry": null, "train": "normal", "work": "woodchip", "history": [] }

## the funnel counters of a horse's crop: the world's crops, or the rivals' (the rest of Japan's open horses)
static func crop_rec(h: Dictionary) -> Variant:
	if h.get("foreign") != null: return null          # overseas horses are not part of any Japanese crop
	var born := int(h.get("c", {}).get("born", -1))
	if Rivals.is_rival(h):
		if not W.has("rivalCrops"): W["rivalCrops"] = {}
		if not W.rivalCrops.has(born): W.rivalCrops[born] = { "n": 0, "won": 0, "open": 0, "graded": 0, "g1": 0 }
		return W.rivalCrops[born]
	return W.crops.get(born)

static func make_horse(sire: Dictionary, dam: Dictionary, r: SimRng, born: int) -> Dictionary:
	var h := Breeding.breed(sire, dam, r)
	h["age"] = 0
	h["c"] = new_career(h, born)
	if not W.is_empty():
		if not W.has("crops"): W["crops"] = {}
		if not W.crops.has(born): W.crops[born] = { "n": 0, "won": 0, "open": 0, "graded": 0, "g1": 0 }
		W.crops[born].n += 1
	return h

static func init(seed_value := 1, opts_in := {}) -> Dictionary:
	Stud._pex = {}
	var opts := { "crop": 1100, "stallions": 22, "mares": 1560, "perWeek": 17 }   # condition races per week scaled to the crop so that ~30% of runners win a race (JRA: ~1,200 newcomer/maiden races for ~4,700 debutants, plus wins after moving to local racing)   # ~75% of mares produce a live foal each year
	opts.merge(opts_in, true)
	var sd: int = seed_value if seed_value else 1
	var r0 := SimRng.new(sd)
	Breeding.seed_book(r0, 0, 0)
	# real stud book (Step 3): historic ancestors, the stallions standing in Japan in 2026, dead sires whose foals still
	# race, and overseas stallions. Their stats are game estimates; names, years and pedigrees are real.
	Bloodlines.build(r0)
	RealPed.attach(r0)                # real parents (open-horse-data) and ~40 more stallions around the world
	# fictional second dams (born ~1995–2008) by real old sires, then the world's broodmares (fictional names, real sires)
	var anc_m: Array = []
	for i in 60:
		var a := Breeding.founder(r0, "F", 64, {})
		a["sire"] = Bloodlines.id_of(Bloodlines.weighted(r0, Bloodlines.BMS2))
		a["age"] = 19 + int(floor(r0.next() * 13.0))
		a["born"] = 2027 - int(a.age)
		a["c"] = { "status": "retired", "starts": 12, "wins": 2, "cm": 0.0, "g1": 0, "graded": 0, "earn": 0.0, "history": [], "bigWins": [] }
		anc_m.append(a)
	# the world's broodmares: real Japanese mares (with their real families) first, fictional ones for the rest
	var founders: Array = []
	for m in RealPed.mares(r0, int(opts.mares), 2009, 2020):
		m["retired"] = true
		m["age"] = 2027 - int(m.born)
		m["gen"] = 1
		m["c"] = { "status": "broodmare", "starts": 4 + int(floor(r0.next() * 12.0)), "wins": 0, "cm": 0.0, "g1": 0, "graded": 0, "earn": 0.0, "history": [], "bigWins": [] }
	var reals := Breeding.mares().size()
	var fict: Array = []
	var nf := maxi(0, int(opts.mares) - reals)
	var half := int(SimUtil.js_round(nf / 2.0))
	for i in half: fict.append(Breeding.founder(r0, "F", 63, { "retired": true }))
	for i in nf - half: fict.append(Breeding.founder(r0, "F", 62, { "retired": true }))
	founders = Breeding.mares()
	for f in fict:
		f["age"] = 7 + int(floor(r0.next() * 8.0))
		f["born"] = 2027 - int(f.age)
		var bms := ""
		for t in 6:   # the broodmare sire must have been covering the year before she was born
			bms = Bloodlines.weighted(r0, Bloodlines.BMS)
			var win = Bloodlines.DEAD_SIRES.get(bms)
			if win == null or (int(f.born) - 1 >= int(win[0]) and int(f.born) - 1 <= int(win[1])): break
		f["sire"] = Bloodlines.id_of(bms)
		f["dam"] = anc_m[int(floor(r0.next() * anc_m.size()))].id
		f["gen"] = 1
		f["c"] = { "status": "broodmare", "starts": 4 + int(floor(r0.next() * 12.0)), "wins": 0, "cm": 0.0, "g1": 0, "graded": 0, "earn": 0.0, "history": [], "bigWins": [] }
	Breeding.clear_memo()
	Bloodlines.calibrate(founders)    # real stallions' breeding values from their real progeny statistics
	W = { "crops": {}, "v": 1, "seed": sd, "year": 2027, "week": 1, "crop": int(opts.crop), "perWeek": int(opts.perWeek), "stable": [], "log": [], "gradedLog": [], "races": [], "replays": {}, "gradedReplays": {}, "rngState": sd * 7919, "nextRace": 1, "lastWeek": null }
	R = SimRng.new(sd * 7919)
	People.build(int(W.year))
	Owners.build()
	# populate ages 1-6 by breeding the founders, then give older horses a plausible past (class by ability)
	_pick_cache = {}
	for age in range(1, 7):
		# whole crops (also the horses that have since retired), so sires' records start with realistic winner rates
		var n := int(opts.crop)
		for i in n:
			var h := make_horse(pick_sire(r0, int(W.year) - age), pick_mare(r0), r0, int(W.year) - age)
			h.age = age
	_pick_cache = null
	for age in [3, 4, 5, 6]:
		# racing luck, trainers and placing blur the link between ability and record (top sires' runners win ~40–50 %)
		var key := {}
		for h in active():
			if h.age == age: key[int(h.id)] = rating(h) + r0.gauss() * 5.0
		var hs := SimUtil.stable_sort(active().filter(func(h): return h.age == age), func(a, b): return key[int(b.id)] - key[int(a.id)])
		# winners so far: ~25 % of a crop by January of its 3-year-old year, ~34 % in all (JRA: about a third of debutants win)
		var wq := 0.25 if age == 3 else 0.34
		# share of the winners still racing in JRA (the rest retired, went to stud or to local racing)
		var keep: float = { 3: 1.0, 4: 0.45, 5: 0.32, 6: 0.2 }[age]   # tuned so a new save starts with ~1,500 horses of 3+ in training
		for i in hs.size():
			var h: Dictionary = hs[i]
			var q := float(i) / hs.size() * 0.62 / wq          # rank scaled to the old 62 % winner table
			var c: Dictionary = h.c
			c.starts = 3 + int(SimUtil.js_round(r0.next() * (age * 3)))
			if q < 0.03:
				c.wins = 5; c.cm = 60.0 + r0.next() * 40.0; c.graded = 2; c.g1 = 1 if q < 0.01 else 0
			elif q < 0.1:
				c.wins = 4; c.cm = 20.0 + r0.next() * 20.0; c.graded = 1 if q < 0.05 else 0
			elif q < 0.2:
				c.wins = 3; c.cm = 11.0 + r0.next() * 5.0
			elif q < 0.36:
				c.wins = 2; c.cm = 6.0 + r0.next() * 4.0
			elif q < 0.62:
				c.wins = 1; c.cm = 4.0 + r0.next()
			c.starts = maxi(c.starts, c.wins * 2 + int(r0.next() * 3.0))
			c.earn = c.cm * 1.6 + c.starts * 1.2
			c.last = -r0.next() * 6.0
			if age >= 4 and c.wins == 0: c.status = "retired"   # winless older horses have already left JRA racing
			elif c.wins > 0 and c.graded == 0 and r0.next() > keep: c.status = "retired"
			# official marks from last season (handicappers' assessment of the existing record)
			var est := Ratings.bootstrap(h, q)
			c["mark"] = est; c["nRated"] = 3; c["rtMax"] = est
			c["rtPrev"] = { "y": int(W.year) - 1, "r": est, "cat": Ratings.cat(int(best_dist(h))), "surf": "D" if int(h.dirt) >= 50 else "T", "race": "2026 season" }
	# the rest of Japan's open-class horses (see Rivals)
	_pick_cache = {}
	for age in range(1, 7): Rivals.make_crop(int(W.year) - age, age, R)
	_pick_cache = null
	# breeding stock: parity and last year's coverings (foals due this spring)
	for m in Breeding.mares():
		Stud.repro(m).parity = clampi(int(m.age) - 4 - int(floor(r0.next() * 3.0)), 0, 12)
	Stud.update_market()
	W.year -= 1; W.week = Stud.SEASON_START
	Stud._ai_matings()
	W.year += 1; W.week = 1
	Intl.top_up(r0)                   # foreign horses for the overseas G1s
	return W

## a sire for a horse born in year `born` (covering the year before): stallions at stud then, including the
## famous sires who have since died (Deep Impact, King Kamehameha, Heart's Cry ...)
## (while a new world is populated the stallion and mare rosters don't change: their lists and weights are cached,
##  otherwise each foal would rescan the whole stud book)
static var _pick_cache = null

static func pick_sire(r: SimRng, born := -1) -> Variant:
	if _pick_cache != null:
		var dm0 := r.next() < 0.55
		var key := "%d|%s" % [born, dm0]
		if not _pick_cache.has(key): _pick_cache[key] = _sire_table(born, dm0)
		var tb: Array = _pick_cache[key]
		if tb[0].is_empty(): return null
		var u0: float = r.next() * float(tb[2])
		for i in tb[0].size():
			u0 -= float(tb[1][i])
			if u0 <= 0.0: return tb[0][i]
		return tb[0][tb[0].size() - 1]
	var st: Array = []
	for s in Breeding.stallions():
		if born < 0 or int(Stud.stud(s).get("since", 0)) <= born - 1: st.append(s)
	if born > 0:
		for h in Breeding.book.values():
			var win = h.get("coverWin")
			if win != null and born - 1 >= int(win[0]) and born - 1 <= int(win[1]): st.append(h)
	if st.is_empty(): st = Breeding.stallions()
	if st.is_empty(): return null
	var wts: Array = []
	var tot := 0.0
	var dm := r.next() < 0.55          # bred for the dirt market (see Stud.market_w)
	for s in st:
		var c = s.get("c")
		var fee := float(s.stud.fee) if s.has("stud") else 10.0
		var w := pow(maxf(1.0, rating(s) - 50.0), 2.0) * (2.0 if (c != null and c.get("g1", 0) > 0) else 1.0) * sqrt(maxf(0.5, fee)) * Stud.market_w(s, dm)
		wts.append(w)
		tot += w
	var u := r.next() * tot
	for i in st.size():
		u -= wts[i]
		if u <= 0.0: return st[i]
	return st[st.size() - 1]

static func _sire_table(born: int, dm: bool) -> Array:
	var st: Array = []
	for s in Breeding.stallions():
		if born < 0 or int(Stud.stud(s).get("since", 0)) <= born - 1: st.append(s)
	if born > 0:
		for h in Breeding.book.values():
			var win = h.get("coverWin")
			if win != null and born - 1 >= int(win[0]) and born - 1 <= int(win[1]): st.append(h)
	if st.is_empty(): st = Breeding.stallions()
	var wts: Array = []
	var tot := 0.0
	for s in st:
		var c = s.get("c")
		var fee := float(s.stud.fee) if s.has("stud") else 10.0
		var w := pow(maxf(1.0, rating(s) - 50.0), 2.0) * (2.0 if (c != null and c.get("g1", 0) > 0) else 1.0) * sqrt(maxf(0.5, fee)) * Stud.market_w(s, dm)
		wts.append(w)
		tot += w
	return [st, wts, tot]

static func pick_mare(r: SimRng) -> Variant:
	if _pick_cache != null:
		if not _pick_cache.has("mares"): _pick_cache["mares"] = Breeding.mares()
		var mm: Array = _pick_cache["mares"]
		return mm[int(floor(r.next() * mm.size()))]
	var m := Breeding.mares()
	return m[int(floor(r.next() * m.size()))]

static func active() -> Array:
	return Breeding.book.values().filter(func(h): return h.has("c") and h.c.status == "active")


# ---------- weights (JRA 2024+ simplified) ----------
static func weight_for(h: Dictionary, race: Dictionary) -> float:
	var F: bool = h.sex == "F"
	if race.age == "2": return 56.0 if (W.week >= 40 and not F) else 55.0
	if race.age == "3": return 55.0 if F else 57.0
	var w: float = 58.0 if h.age >= 5 else (58.0 if h.age == 4 else (55.0 if W.week < 30 else 56.0))   # 3yo allowance vs older horses
	if F: w -= 2.0
	return w


# ---------- race card for a week ----------
static func _race_name(short: String, cls: String, age: String) -> String:
	return "%s %s%s" % [short, CLASS_NAMES[cls], " (2yo)" if age == "2" else (" (3yo)" if age == "3" else "")]

## share of JRA condition races at each distance (approximate, 2015–2025 programme): turf is built around 1200–2000 m,
## dirt around 1200–1400 m and 1700–1800 m; marathon dirt races are very rare
const DIST_W := {
	"turf": { 1000: 1.5, 1200: 16.0, 1400: 12.0, 1500: 2.0, 1600: 18.0, 1700: 0.5, 1800: 16.0, 2000: 20.0, 2200: 6.0, 2300: 1.0, 2400: 5.0, 2500: 2.0, 2600: 3.0, 3000: 0.4, 3200: 0.2, 3400: 0.2, 3600: 0.2 },
	"dirt": { 1000: 4.0, 1150: 2.0, 1200: 20.0, 1300: 2.0, 1400: 15.0, 1600: 8.0, 1700: 14.0, 1800: 30.0, 1900: 3.0, 2000: 1.0, 2100: 2.0, 2400: 0.3, 2500: 0.2 } }

static func dist_weight(surf: String, d: int) -> float:
	var t: Dictionary = DIST_W[surf]
	if t.has(d): return t[d]
	var best := 0.5
	var bd := 1e9
	for k in t:
		if absf(k - d) < bd: bd = absf(k - d); best = t[k]
	return best

static func build_week() -> Array:
	var w: int = W.week
	var m := month_of_week(w)
	var races: Array = []
	var add := func(r: Dictionary) -> void:
		r["id"] = W.nextRace; W.nextRace += 1
		r["week"] = w; r["year"] = W.year; r["entries"] = []
		races.append(r)
	for x in Intl.races_for_week(w): add.call(x)
	for g in GRADED:
		if g[2] == w: add.call({ "name": g[0], "cls": W.get("gradeOverride", {}).get(g[0], g[1]), "course": g[3], "dist": g[4], "age": g[5], "sex": g[6], "handicap": g[7] != 0, "size": 18 if g[1] == "G1" else 16 })
	# condition races: real JRA mix ≈ newcomer 9%, maiden 26%, 1-Win 29%, 2-Win 16%, 3-Win 6%, Open/L 8%
	var older := "3+" if w >= 23 else "4+"
	var opts: Array = []
	# maiden-type races are set so that about a third of JRA debutants win a race (SPAIA, 2016 crop) and about 30% of
	# 2-year-old runners win at 2 (2025 top sires 21–36%)
	# the higher classes are kept scarce: in the JRA a horse wins its way out of each class slowly (≈40 % of winners
	# win again, ≈3 % of a crop reach open class), so 2-Win / 3-Win / open races are few for the horses in them
	if w >= 23: opts.append([["NEW", "2"], 14.0])
	if w >= 27: opts.append([["MDN", "2"], 15.0])
	if w <= 38: opts.append([["MDN", "3"], 26.0 if w < 23 else 14.0])
	if w < 23: opts.append([["1W", "3"], 5.0])
	opts.append_array([[["1W", older], CLS_W["1W"]], [["2W", older], CLS_W["2W"]], [["3W", older], CLS_W["3W"]], [["OP", older], CLS_W["OP"]]])
	var tot := 0.0
	for o in opts: tot += o[1]
	var n: int = W.perWeek + (1 if rng() < 0.5 else 0)
	for i in n:
		var u := rng() * tot
		var pk: Array = opts[0][0]
		for o in opts:
			u -= o[1]
			if u <= 0.0:
				pk = o[0]
				break
		var vs: Array = VENUES[m]
		var v: String = vs[int(floor(rng() * vs.size()))]
		var cls: String = pk[0]
		var age: String = pk[1]
		var surf := "dirt" if rng() < 0.5 else "turf"     # JRA condition races ≈ half dirt (graded races are mostly turf)
		var ids: Array = VENUE_COURSES[v][surf]
		# course and distance together, weighted so the mix of distances follows the real JRA programme
		var pairs: Array = []
		var offered := {}
		for cx in ids:
			for d in RaceEngine.COURSES[cx].distances:
				if (age == "2" and d > 2000) or ((cls == "NEW" or cls == "MDN") and d > 2400): continue
				pairs.append([cx, d]); offered[d] = int(offered.get(d, 0)) + 1
		if pairs.is_empty():
			for d in RaceEngine.COURSES[ids[0]].distances: pairs.append([ids[0], d]); offered[d] = int(offered.get(d, 0)) + 1
		var ptot := 0.0
		for pr in pairs: ptot += dist_weight(surf, pr[1]) / float(offered[pr[1]])
		var pu := rng() * ptot
		var pick: Array = pairs[pairs.size() - 1]
		for pr in pairs:
			pu -= dist_weight(surf, pr[1]) / float(offered[pr[1]])
			if pu <= 0.0:
				pick = pr
				break
		var cid: String = pick[0]
		var C: Dictionary = RaceEngine.COURSES[cid]
		var dist: int = pick[1]
		var hc := cls == "OP" and rng() < 0.3
		add.call({ "name": _race_name(C.short, cls, age), "cls": cls, "course": cid, "dist": dist, "age": age, "sex": "", "handicap": hc, "size": 16 })
	# make sure every horse in the player's stable has at least one suitable race this week
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h == null or not h.has("c") or h.c.status != "active" or h.age < 2 or h.c.get("out", 0) > 0: continue
		var has_race := false
		for r in races:
			if eligible(h, r):
				has_race = true
				break
		if has_race: continue
		var cl := class_of(h.c)
		var cls2 = "NEW" if (h.c.starts == 0 and h.age == 2) else ((null if (h.age == 2 and w < 27) else "MDN") if cl == "MDN" else cl)
		if cls2 == null or (cls2 == "NEW" and w < 23) or (cls2 == "MDN" and h.age == 3 and w > 38): continue
		var age2 := "2" if (cls2 == "NEW" or (cls2 == "MDN" and h.age == 2)) else ("3" if (cls2 == "MDN" or (h.age == 3 and w < 23)) else ("3+" if w >= 23 else "4+"))
		if age2 == "4+" and h.age < 4: continue
		var vs2: Array = VENUES[m]
		var v2: String = vs2[int(floor(rng() * vs2.size()))]
		var surf2 := "dirt" if h.dirt >= 50 else "turf"
		var best := {}
		for cid2 in VENUE_COURSES[v2][surf2]:
			for d in RaceEngine.COURSES[cid2].distances:
				if age2 == "2" and d > 2000: continue
				var dd := absf(d - best_dist(h))
				if best.is_empty() or dd < best.dd: best = { "cid": cid2, "d": d, "dd": dd }
		if not best.is_empty():
			add.call({ "name": _race_name(RaceEngine.COURSES[best.cid].short, cls2, age2), "cls": cls2, "course": best.cid, "dist": best.d, "age": age2, "sex": "", "handicap": false, "size": 16 })
	W.races = races
	return races

static func since(h: Dictionary) -> float:
	var ly = h.c.get("lastY")
	var y: int = int(ly) if ly else int(W.year)
	return (int(W.year) - y) * 52 + (float(W.week) - float(h.c.get("last", -99.0)))

static func eligible(h: Dictionary, r: Dictionary) -> bool:
	var c: Dictionary = h.c
	if c.status != "active" or c.get("out", 0) > 0: return false
	if r.sex == "F" and h.sex != "F": return false
	var a: String = r.age
	if a == "2" and h.age != 2: return false
	if a == "3" and h.age != 3: return false
	if a == "3+" and h.age < 3: return false
	if a == "4+" and h.age < 4: return false
	if h.age < 2: return false
	if Rivals.is_rival(h) and not Rivals.can_run(h, r): return false
	var ie := Intl.eligible(h, r)
	if ie >= 0: return ie == 1
	var cl := class_of(c)
	if r.cls == "NEW": return c.starts == 0
	if r.cls == "MDN": return (c.wins == 0 and c.starts > 0) or (c.wins == 0 and h.age >= 3)
	if r.cls in ["1W", "2W", "3W"]: return cl == r.cls
	if r.cls == "OP": return cl == "OP"
	if r.cls == "G3": return cl == "OP" or cl == "3W" or (h.age <= 3 and c.wins >= 1)
	return cl == "OP" or (h.age <= 3 and c.wins >= 1)   # G1/G2

static func suit(h: Dictionary, r: Dictionary) -> float:
	var bd := best_dist(h)
	var dd: float = absf(r.dist - bd) / bd
	var C: Dictionary = RaceEngine.COURSES[r.course]
	var surf: float = (float(h.dirt) - 50.0) / 50.0 if C.surface == "dirt" else (50.0 - float(h.dirt)) / 50.0
	# trainers keep horses on their preferred surface: switching costs a lot more than a distance change
	return 1.0 - dd * 2.5 + surf * 0.9


# ---------- quick result model (background races) ----------
static func quick_time(h: Dictionary, r: Dictionary, noise: float) -> float:
	RaceEngine.use_course(r.course)
	var p := RaceEngine.derive(h, { "going": r.going, "dist": r.dist })
	var Rv := p.d0 + p.gutsRes
	var v := minf(p.cs / maxf(0.3, 1.0 - Rv / r.dist), p.vmax * 0.955)
	var key := "%s%d" % [r.course, r.dist]
	if not QCACHE.has(key) and QCal.T.has(key): QCACHE[key] = QCal.T[key]   # precomputed from full-engine fields
	if not QCACHE.has(key):   # fallback: correction from a solo stat-70 horse in the full engine
		var st := {}
		for k in RaceEngine.STATS: st[k] = 70
		var ref := { "name": "ref", "gene": "CT", "style": "stalker", "bw": 480, "carried": 57, "jockey": 75, "form": 0, "dirt": 50, "stats": st }
		var t: float = RaceEngine.run_headless([ref], { "course": r.course, "dist": r.dist, "seed": 1, "injuries": false, "eiph": false }).runners[0].finishT
		RaceEngine.use_course(r.course)
		var q := RaceEngine.derive(ref, { "going": "firm", "dist": r.dist })
		var vq := minf(q.cs / maxf(0.3, 1.0 - (q.d0 + q.gutsRes) / r.dist), q.vmax * 0.955)
		QCACHE[key] = t / (r.dist / vq)
	var jk := 1.0 - 0.0011 * (float(h.get("jockey", JOCKEY_REF)) - JOCKEY_REF) / 10.0   # a 10-point better jockey ≈ 0.1 % quicker
	return r.dist / v * QCACHE[key] * QOFF * (1.0 + noise) * (1.0 + (float(h.carried) - 56.0) * 0.0012) * jk


# ---------- fitness, fatigue, training ----------
static func train_week(h: Dictionary) -> void:
	var c: Dictionary = h.c
	if c.status != "active": return
	if c.out > 0:
		c.out -= 1; c.fit += (0.5 - c.fit) * 0.06; c.fat *= 0.5
		if c.out == 0: back_from_injury(h)
		return
	var ld: float = LOAD[c.train] * (1.1 if c.work == "hill" else 1.0)
	var target := 0.55 + 0.45 * minf(1.0, ld)
	c.fit += (target - c.fit) * (0.22 if target > c.fit else 0.04)      # fast gain (≈7 weeks to most of the effect), slow detraining
	c.fat = c.fat * 0.62 + ld * 0.12
	var haz: float = 0.0015 * ld * ld * (1.6 - h.stats.sound / 100.0) * (1.0 + 2.0 * c.fat) * (1.25 if c.work == "hill" else 1.0) * (1.4 if h.age >= 7 else 1.0)
	if rng() < haz: injure(h, "training")

static func fit_factor(h: Dictionary) -> float:
	var c: Dictionary = h.c
	return (0.985 + 0.015 * clampf(c.fit, 0.0, 1.0)) * (1.0 - 0.01 * clampf(c.fat, 0.0, 2.0))

static func injure(h: Dictionary, where: String, sev := -1) -> void:
	var c: Dictionary = h.c
	var serious := rng() < 0.25 if sev < 0 else sev == 1
	c["injSev"] = "severe" if serious else "injured"
	c["sore"] = 0
	c.out = 30 + int(floor(rng() * 30.0)) if serious else 6 + int(floor(rng() * 20.0))
	if serious and (h.age >= 6 or rng() < 0.4): retire(h, "career-ending injury")
	log_msg("%s injured (%s)%s" % [h.name, where, ", out for %d weeks" % c.out if c.status == "active" else ""], h)

## injury status shown to the player and used by the trainers:
## "severe" (out, serious injury) · "injured" (out) · "caution" (back in work but still sore: can race, at a higher
## risk of breaking down) · "fit"
static func injury_level(h: Dictionary) -> String:
	var c: Dictionary = h.get("c", {})
	if int(c.get("out", 0)) > 0: return "severe" if String(c.get("injSev", "injured")) == "severe" else "injured"
	if int(c.get("sore", 0)) > 0: return "caution"
	return "fit"

static func injury_text(h: Dictionary) -> String:
	var c: Dictionary = h.get("c", {})
	match injury_level(h):
		"severe": return "Severe injury · out %d wk" % int(c.out)
		"injured": return "Injured · out %d wk" % int(c.out)
		"caution": return "Caution · sore (%d wk)" % int(c.sore)
	return "Fit"

## an injury has healed: the horse goes back into work but stays on caution for a few weeks
static func back_from_injury(h: Dictionary) -> void:
	var c: Dictionary = h.c
	var sev := String(c.get("injSev", "injured")) == "severe"
	c["sore"] = (4 + int(floor(rng() * 5.0))) if sev else (2 + int(floor(rng() * 3.0)))
	c.erase("injSev")
	if _in_stable(h.id): log_msg("%s is back in training after injury (caution for %d weeks: racing now risks a setback)." % [h.name, int(c.sore)], h)

## CPU trainers rarely run a horse that is on caution (better horse-care trainers almost never do)
static func runs_while_sore(h: Dictionary) -> bool:
	if int(h.c.get("sore", 0)) <= 0: return true
	return rng() < 0.10 - 0.07 * Training.trainer_attr(h, "care") / 100.0

## breeders keep more fillies as broodmares when the mare population runs low (keeps the crop steady at ~W.crop)
static func _mare_intake() -> float:
	var young := Breeding.mares().filter(func(m): return int(m.age) <= Stud.MAX_MARE_AGE).size()
	return 0.5 if young < W.crop * 1.36 else 0.15

static func retire(h: Dictionary, why: String) -> void:
	var c: Dictionary = h.c
	if c.status != "active": return
	var good: bool = c.g1 > 0 or (c.graded > 0 and rng() < 0.25) or (c.graded > 0 and c.earn > 300)
	if h.sex == "M" and good:
		c.status = "stud"; h["retired"] = true
		Stud.stud(h)["since"] = int(W.year)
	elif h.sex == "F" and (c.graded > 0 or (c.wins >= 2 and rng() < 0.7) or rng() < _mare_intake()) and Breeding.mares().size() < W.crop * 1.45:
		c.status = "broodmare"; h["retired"] = true
	else: c.status = "retired"
	c["retiredWhy"] = why; c["retiredYear"] = W.year
	if _in_stable(h.id) and String(c.get("owner", "")) != "":     # a horse the player trains: the owner takes it home
		W.stable.erase(int(h.id))
		log_msg("%s leaves your stable: %s's owner (%s) has retired the horse (%s)." % [h.name, "his" if h.sex == "M" else "her", c.owner, why], h)
		c["owner"] = ""
		return
	if _in_stable(h.id) or c.graded > 0:
		var to := "stallion at stud" if c.status == "stud" else ("broodmare" if c.status == "broodmare" else "retired")
		log_msg("%s retired (%s) → %s" % [h.name, why, to], h)

## money record (used by the finances in Step 4): amount in million yen, + income / − cost
## every money movement goes through here: it updates the cash balance (W.money) and the yearly totals by category
static func ledger(text: String, amount: float, cat := "other") -> void:
	if not W.has("ledger"): W["ledger"] = []
	amount = snappedf(amount, 0.001)
	W.ledger.insert(0, { "y": W.year, "w": W.week, "text": text, "amt": amount, "cat": cat })
	if W.ledger.size() > 1500: W.ledger.resize(1500)
	W["money"] = float(W.get("money", 0.0)) + amount
	if not W.has("finYear"): W["finYear"] = {}
	if not W.finYear.has(int(W.year)): W.finYear[int(W.year)] = {}
	var fy: Dictionary = W.finYear[int(W.year)]
	fy[cat] = float(fy.get(cat, 0.0)) + amount

static func log_msg(msg: String, h: Variant) -> void:
	W.log.insert(0, { "y": W.year, "w": W.week, "msg": msg, "id": h.id if h != null else null, "mine": _in_stable(h.id) if h != null else false })
	if W.log.size() > 400: W.log.resize(400)


# ---------- entries ----------
static func enter(hid: int, race_id: int) -> String:
	var h = Breeding.get_horse(hid)
	var r = null
	for x in W.races:
		if x.id == race_id: r = x
	if h == null or r == null: return "not found"
	if not eligible(h, r): return "not eligible"
	if since(h) < 2: return "needs at least 2 weeks between races"
	undeclare()          # entries re-open: the fields are declared again
	h.c.entry = race_id
	return "ok"

static func fill_fields() -> void:
	var pool := active().filter(func(h): return h.age >= 2 and h.c.out == 0)
	var used := {}
	for r in W.races:
		for h in pool:
			if h.c.entry == r.id and _in_stable(h.id):
				r.entries.append(h.id); used[h.id] = true
	var order := SimUtil.stable_sort(W.races, func(a, b): return GRADE_RANK.get(a.cls, 4) - GRADE_RANK.get(b.cls, 4))
	var g1stat := INF
	for r in W.races:
		if r.cls == "G1": g1stat = _g1_stat_bar(pool); break
	# speed: the pool split by what a horse can run in (in pool order, so every race sees its candidates in the same
	# order as before — the same random draws, the same fields)
	var by := { "NEW": [], "MDN": [], "1W": [], "2W": [], "3W": [], "OP": [], "stakes": [] }
	for h in pool:
		var cl0 := class_of(h.c)
		if int(h.c.starts) == 0: by.NEW.append(h)
		if int(h.c.wins) == 0: by.MDN.append(h)
		else: by[cl0].append(h)
		if cl0 == "OP" or cl0 == "3W" or (int(h.age) <= 3 and int(h.c.wins) >= 1) or h.get("foreign") != null: by.stakes.append(h)
	var rc := {}           # Planner.ready per horse, worked out once for the week
	for r in order:
		var graded: bool = r.cls in ["G1", "G2", "G3"]
		var cands: Array = []
		var src: Array = pool if (Intl.is_intl(r) or not BUCKETS) else (by.stakes if graded else by.get(r.cls, pool))
		for h in src:
			if used.has(h.id) or _in_stable(h.id) or not eligible(h, r): continue
			# the trainer decides: recovered from the last race, back from the farm, fit and fresh (Planner)
			# good enough for a G1: connections of a horse rated near G1 level aim for the race (they bring it back
			# from the farm a little early, and run it a bit short of a peak rather than miss the race)
			var g1q: bool = r.cls == "G1" and h.get("foreign") == null and g1_quality(h, r, g1stat)
			if h.get("foreign") == null:
				if g1q:
					if not Planner.ready_for_g1(h): continue
				elif not _ready_c(h, rc) or Planner.saving_for(h, r): continue
				if not runs_while_sore(h): continue
			var ready := 1.0
			var prestige: float = rating(h) / 10.0 + h.c.cm / 30.0 if graded else 0.0
			if g1q: prestige += G1_AIM + clampf((float(h.c.get("mark", 0.0)) - Ratings.grade_par("G1", r.sex == "F", String(r.age))) / 4.0, 0.0, 2.0)
			# stables plan campaigns: horses rated well above a race's grade aim higher (and avoid the weight
			# penalties of lesser graded races), so G2/G3 fields are not filled with G1 horses
			if graded and r.cls != "G1":
				var mk = h.c.get("mark")
				if mk != null: prestige -= 0.6 * maxf(0.0, float(mk) - (Ratings.grade_par(r.cls, false, "") + 6.0))
			if Intl.is_intl(r) or h.get("foreign") != null: prestige += Intl.entry_bonus(h, r)
			var s := _suit_c(h, r, rc) * 3.0 + ready + prestige + gauss() * 0.8
			if s > ENTRY_MIN or (graded and s > ENTRY_MIN - 2.5): cands.append({ "h": h, "s": s })
		cands = SimUtil.stable_sort(cands, func(a, b): return b.s - a.s)
		var n_jp := 0
		var n_fo := 0
		for e in r.entries:
			if Breeding.get_horse(e).get("foreign") == null: n_jp += 1
		if Intl.is_intl(r):
			# Japanese raiders first: the stables decide to travel with their best suited horses (about half of the
			# qualified ones go), then the home and foreign runners fill the field
			for x in cands:
				if n_jp >= int(r.jpMax) or r.entries.size() >= r.size: break
				if x.h.get("foreign") == null and rng() < 0.55:
					r.entries.append(x.h.id); used[x.h.id] = true; n_jp += 1
			cands = cands.filter(func(x): return not used.has(x.h.id))
		for x in cands:
			if r.entries.size() >= r.size: break
			var fo: bool = x.h.get("foreign") != null
			if Intl.is_intl(r) and not fo and n_jp >= int(r.jpMax): continue        # only a few Japanese raiders travel
			if not Intl.is_intl(r) and fo and (n_fo >= 3 or x.s < 3.5): continue      # Japan Cup: up to 3 foreign runners
			if fo: n_fo += 1
			else: n_jp += 1
			r.entries.append(x.h.id); used[x.h.id] = true
			if r.cls == "G1" and Planner.on_break(x.h): x.h.c.erase("breakUntil")
	W.races = W.races.filter(func(r): return r.entries.size() >= 5)


## suit() with the horse's best distance worked out once for the week (same numbers)
static func _suit_c(h: Dictionary, r: Dictionary, rc: Dictionary) -> float:
	var k := -1 - int(h.id)
	if not rc.has(k): rc[k] = best_dist(h)
	var bd: float = rc[k]
	var dd: float = absf(r.dist - bd) / bd
	var C: Dictionary = RaceEngine.COURSES[r.course]
	var surf: float = (float(h.dirt) - 50.0) / 50.0 if C.surface == "dirt" else (50.0 - float(h.dirt)) / 50.0
	return 1.0 - dd * 2.5 + surf * 0.9

static func _ready_c(h: Dictionary, rc: Dictionary) -> bool:
	var id := int(h.id)
	if not rc.has(id): rc[id] = Planner.ready(h)
	return rc[id]

const G1_AIM := 2.5        # entry-score boost for a horse good enough for the G1

## rated near G1 level (official mark within 8 lb of the G1 par), or an unraced/lightly raced horse whose
## ability is among the very best (top 2 % on stats), and suited to the trip and surface
static func g1_quality(h: Dictionary, r: Dictionary, stat_bar: float) -> bool:
	if suit(h, r) < 0.4: return false
	var mk = h.c.get("mark")
	if mk != null and float(mk) >= Ratings.grade_par("G1", r.sex == "F", String(r.age)) - 8.0: return true
	return rating(h) >= stat_bar

static func _g1_stat_bar(pool: Array) -> float:
	var rs: Array = []
	for h in pool:
		if int(h.age) >= 2: rs.append(rating(h))
	if rs.is_empty(): return INF
	rs.sort()
	return float(rs[int(floor(0.98 * (rs.size() - 1)))])

# ---------- race planner (the player's horses) ----------
## c.racePlan: targets in future weeks, in date order. A target is a graded race by name, or "a condition race" that
## week with a surface ("any"/"turf"/"dirt") and a distance band. When the week's fields are declared, the horse is
## entered in the target (or the best-suited matching race); the target is then dropped. Problems are logged.
static func plan_of(h: Dictionary) -> Array:
	return h.get("c", {}).get("racePlan", [])

static func plan_add(h: Dictionary, t: Dictionary) -> String:
	var c: Dictionary = h.c
	if not c.has("racePlan"): c["racePlan"] = []
	var now := int(W.year) * 52 + int(W.week)
	var at := int(t.y) * 52 + int(t.w)
	if at < now: return "that week has passed"
	for x in c.racePlan:
		if int(x.y) == int(t.y) and int(x.w) == int(t.w): return "already a target that week"
	c.racePlan.append(t)
	c.racePlan.sort_custom(func(a, b): return int(a.y) * 52 + int(a.w) < int(b.y) * 52 + int(b.w))
	return "ok"

static func plan_remove(h: Dictionary, idx: int) -> void:
	var pl: Array = plan_of(h)
	if idx >= 0 and idx < pl.size(): pl.remove_at(idx)

static func plan_text(t: Dictionary) -> String:
	if String(t.get("race", "")) != "": return String(t.race)
	var surf := String(t.get("surf", "any"))
	return "Condition race (%s%s)" % ["any surface" if surf == "any" else surf, ", %d–%d m" % [int(t.dmin), int(t.dmax)] if int(t.get("dmin", 0)) > 0 else ""]

## warnings for a target (shown when it's planned and on the plan list)
static func plan_warnings(h: Dictionary, t: Dictionary) -> Array:
	var out: Array = []
	var c: Dictionary = h.get("c", {})
	var wk := (int(t.y) - int(W.year)) * 52 + int(t.w) - int(W.week)
	if int(c.get("out", 0)) > wk: out.append("injured until then")
	elif int(c.get("sore", 0)) > wk: out.append("still on caution")
	for x in plan_of(h):
		var xw := (int(x.y) - int(W.year)) * 52 + int(x.w) - int(W.week)
		if x != t and absi(xw - wk) < 3: out.append("less than 3 weeks from another target")
	var lw := int(round(since(h)))
	if int(c.get("starts", 0)) > 0 and lw + wk < 2: out.append("too soon after the last run")
	var name := String(t.get("race", ""))
	if name != "":
		for g in GRADED:
			if g[0] != name: continue
			var age_then := int(h.age) + (1 if int(t.y) > int(W.year) else 0)
			var ag := String(g[5])
			if String(g[6]) == "F" and h.sex != "F": out.append("fillies only")
			if (ag == "2" and age_then != 2) or (ag == "3" and age_then != 3) or (ag.contains("+") and age_then < int(ag.substr(0, 1))): out.append("wrong age")
			var cl := class_of(c)
			if cl != "OP" and not (age_then <= 3 and int(c.get("wins", 0)) >= 1) and not (g[1] == "G3" and cl == "3W"): out.append("not qualified yet (needs more wins)")
	return out

static func apply_plans() -> void:
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h == null or not h.has("c") or h.c.status != "active": continue
		var pl: Array = plan_of(h)
		if pl.is_empty(): continue
		var due: Array = pl.filter(func(t): return int(t.y) * 52 + int(t.w) <= int(W.year) * 52 + int(W.week))
		for t in due: pl.erase(t)
		var t = null
		for x in due:
			if int(x.y) == int(W.year) and int(x.w) == int(W.week): t = x
		if t == null or h.c.get("entry") != null: continue
		var why := ""
		if int(h.c.get("out", 0)) > 0: why = "injured"
		elif since(h) < 2: why = "raced too recently"
		var best = null
		var best_s := -INF
		if why == "":
			for r in W.races:
				if not eligible(h, r): continue
				var surf: String = RaceEngine.COURSES[r.course].surface
				if String(t.get("race", "")) != "":
					if r.name != t.race: continue
				else:
					if String(t.get("surf", "any")) != "any" and surf != t.surf: continue
					if int(t.get("dmin", 0)) > 0 and (int(r.dist) < int(t.dmin) or int(r.dist) > int(t.dmax)): continue
				var sc := suit(h, r)
				if sc > best_s: best_s = sc; best = r
			if best == null: why = "not eligible" if String(t.get("race", "")) != "" else "no matching race"
		if best != null:
			h.c.entry = int(best.id)
			log_msg("Race plan: %s is entered in %s (%s %d m)." % [h.name, best.name, RaceEngine.COURSES[best.course].short, int(best.dist)], h)
		else:
			log_msg("Race plan: %s could not run in %s — %s." % [h.name, plan_text(t), why], h)

# ---------- run a week ----------
static func _set_going(r: Dictionary) -> void:
	# JRA 2022: 良 70% · 稍重 20% · 重 8% · 不良 2% of flat races; wetter in the rainy season (Jun–Jul) and typhoon season (Sep)
	var mo := month_of_week(W.week)
	var wet := 1.35 if mo in [6, 7, 9] else (0.8 if mo in [1, 2, 12] else 1.0)
	var gx := rng()
	r["going"] = "firm" if gx < 1.0 - 0.30 * wet else ("yielding" if gx < 1.0 - 0.10 * wet else ("soft" if gx < 1.0 - 0.02 * wet else "heavy"))
	if r.get("country", "JPN") in ["GB", "IRE", "FR"]:      # European turf is usually softer (Arc ~ half the years on soft)
		r.going = "firm" if gx < 0.42 else ("yielding" if gx < 0.72 else ("soft" if gx < 0.93 else "heavy"))

# ---------- declarations: fields, draw, weights, jockeys, body weights and odds are fixed before race day ----------
## Fix this week's fields (the race card). Called when the player opens a race card or presses Continue. If the
## player enters a horse afterwards, the week is re-declared (undeclare) so the field can be drawn again.
static func declare_week() -> void:
	if W.get("declared", "") == "%d-%d" % [W.year, W.week]: return     # (every race may have been called off: don't rebuild)
	if W.races.is_empty() or W.races[0].week != W.week or W.races[0].year != W.year: build_week()
	W["weekRaces"] = W.races.duplicate()
	apply_plans()
	fill_fields()
	for r in W.races: _declare(r)
	W["declared"] = "%d-%d" % [W.year, W.week]

static func undeclare() -> void:
	if not W.has("weekRaces") or W.get("declared", "") != "%d-%d" % [W.year, W.week]: return
	W.races = W.weekRaces.duplicate()
	for b in W.get("bets", []):     # the field changes: bets on the old card are refunded
		if int(b.y) == int(W.year) and int(b.w) == int(W.week): ledger("Bet refunded (field re-drawn): %s" % b.race, float(b.yen) / 1e6, "betting")
	W["bets"] = W.get("bets", []).filter(func(b): return not (int(b.y) == int(W.year) and int(b.w) == int(W.week)))
	for r in W.races:
		r.entries = []
		r.erase("card"); r.erase("going")
	W.erase("declared")

static func is_declared() -> bool:
	return W.get("declared", "") == "%d-%d" % [W.year, W.week]

static func _declare(r: Dictionary) -> void:
	_set_going(r)
	r["weather"] = Weather.pick(r.going, W.week, int(r.id) * 977 + W.year)
	r["hour"] = Weather.post_time(r.cls, W.week, int(r.id))
	# the draw (枠順抽選): random gate numbers
	var ids: Array = r.entries.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := int(floor(rng() * (i + 1)))
		var t = ids[i]; ids[i] = ids[j]; ids[j] = t
	r.entries = ids
	var field: Array = []
	for id in ids: field.append(Breeding.get_horse(id))
	var hw := Ratings.handicap_weights(field) if r.handicap else {}
	for h in field:
		h["carried"] = hw.get(int(h.id), weight_for(h, r)); h["ageF"] = age_factor(h, W.week); h["fitF"] = fit_factor(h) * (0.988 if int(h.c.starts) == 0 else 1.0)
		if not h.get("jockey"): h["jockey"] = 70
		h["form"] = Training.form(h)
		People.ensure_trainer(h)
	if W.has("jockeys"):
		People.assign_jockeys(r, field)
		for h in field: h.carried = float(h.carried) - float(h.get("claim", 0))
	var n := field.size()
	var card: Array = []
	var brackets: Array = []
	for k in n:
		var h: Dictionary = field[k]
		brackets.append(Silks.bracket(k + 1, n))
		var bw := race_day_bw(h)
		var prev = h.c.get("raceBw")
		card.append({ "id": int(h.id), "num": k + 1, "bk": brackets[k], "kg": float(h.carried), "j": h.get("jockeyId"), "t": h.c.get("trainer"),
			"bw": bw, "bwd": (bw - int(prev)) if prev != null else null })
	var rr := SimRng.new(int(r.id) * 7919 + int(W.year) * 31 + int(W.week))
	var mine_in := false
	for h in field:
		if _in_stable(h.id): mine_in = true
	var view := Odds.public_view(field, r, rr, Odds.SIMS if (r.cls in ["G1", "G2", "G3", "OP"] or mine_in) else Odds.SIMS_QUICK)
	var win_odds: Array = []
	for k in n:
		card[k]["p"] = snappedf(float(view.p[k]), 0.00001); card[k]["q"] = snappedf(float(view.q[k]), 0.00001)
		card[k]["odds"] = maxf(1.0, floorf(Odds.RATE.win / maxf(1e-6, float(card[k].p)) * 10.0 + 1e-6) / 10.0)
		win_odds.append([card[k].odds, k])
	win_odds.sort_custom(func(a, b): return a[0] < b[0])
	for f in n: card[win_odds[f][1]]["fav"] = f + 1
	for k in n: field[k]["odds"] = card[k].odds; field[k]["fav"] = card[k].fav
	r["card"] = card
	r["kpl"] = view.kpl

## race-day body weight (馬体重): mature weight, still growing at 2–3, heavier when unfit, a few kg of day-to-day noise
static func race_day_bw(h: Dictionary) -> int:
	var base := float(h.get("bw", 480))
	var grow := 0.93 if int(h.age) <= 2 else (0.97 if int(h.age) == 3 else 1.0)
	var unfit := (1.0 - float(h.c.get("fit", 0.8))) * 14.0
	return 2 * int(round((base * grow + unfit + gauss() * 3.0) / 2.0))     # JRA weighs in 2 kg steps

## public stakes for a declared race (rebuilt on demand from the stored public chances)
static func race_pools(r: Dictionary) -> Dictionary:
	var card: Array = r.get("card", [])
	var p: Array = []; var q: Array = []; var bk: Array = []
	for e in card: p.append(float(e.p)); q.append(float(e.q)); bk.append(int(e.bk))
	return Odds.pools({ "p": p, "q": q }, card.size(), bk)

## ---------- the player's bets (¥; the balance is in ¥M) ----------
static func place_bet(r: Dictionary, t: String, picks: Array, yen: int) -> String:
	if not is_declared() or not r.has("card"): return "betting opens when the field is declared"
	if yen < 100 or yen % 100 != 0: return "stakes are in units of ¥100"
	if not Odds.sold(t, r.card.size()): return "%s is not sold for this field" % Odds.NAMES[t]
	if picks.size() != Odds.PICKS[t]: return "pick %d" % Odds.PICKS[t]
	var seen := {}
	for x in picks:
		if seen.has(int(x)) and t != "bracket": return "pick different horses"
		seen[int(x)] = true
	if t == "bracket":
		for x in picks:
			var cnt := 0
			for e in r.card: if int(e.bk) == int(x): cnt += 1
			if cnt == 0: return "no bracket %d" % int(x)
		if int(picks[0]) == int(picks[1]):
			var cnt2 := 0
			for e in r.card: if int(e.bk) == int(picks[0]): cnt2 += 1
			if cnt2 < 2: return "bracket %d has only one runner" % int(picks[0])
	else:
		for x in picks:
			if int(x) < 1 or int(x) > r.card.size(): return "no horse %d" % int(x)
	if Finance.money() < yen / 1e6: return "not enough money"
	if not W.has("bets"): W["bets"] = []
	W.bets.append({ "rid": int(r.id), "race": r.name, "type": t, "key": Odds.key_of(t, picks), "yen": yen, "y": W.year, "w": W.week })
	ledger("Bet: %s %s on %s" % [Odds.NAMES[t], Odds.key_of(t, picks), r.name], -yen / 1e6, "betting")
	return "ok"

static func bets_for(rid: int) -> Array:
	return W.get("bets", []).filter(func(b): return int(b.rid) == rid)

## the official dividends of a race, worked out when first needed (the race card's Result tab, or a bet to settle):
## the pools of every combination are the slow part of a week, and most races are never looked at
static func payouts_of(r: Dictionary) -> Dictionary:
	if r.has("payouts"): return r.payouts
	if not r.has("card") or not r.has("result"): return {}
	var order: Array = []
	for x in r.result:
		if str(x.pos) == "DNF": continue
		for e in r.card:
			if int(e.id) == int(x.id): order.append(int(e.num))
	var bk: Array = []
	for e in r.card: bk.append(int(e.bk))
	r["payouts"] = Odds.payouts(race_pools(r), order, bk, int(r.get("kpl", 3)))
	return r.payouts

static func _settle(r: Dictionary) -> void:
	if not r.has("card"): return
	var has_bets := false
	for b in W.get("bets", []):
		if int(b.rid) == int(r.id): has_bets = true
	if not has_bets: return
	var pay := payouts_of(r)
	var keep: Array = []
	for b in W.get("bets", []):
		if int(b.rid) != int(r.id): keep.append(b); continue
		var won: int = int(pay.get(b.type, {}).get(b.key, 0))
		if won > 0:
			var back := float(won) / 100.0 * float(b.yen)
			ledger("Winning bet: %s %s on %s (¥%d per ¥100)" % [Odds.NAMES[b.type], b.key, r.name, won], back / 1e6, "betting")
			log_msg("Your %s bet %s on %s paid ¥%s" % [Odds.NAMES[b.type], b.key, r.name, _yen(back)], null)
	W["bets"] = keep

static func _yen(x: float) -> String:
	var s := str(int(x))
	var out := ""
	while s.length() > 3: out = "," + s.substr(s.length() - 3) + out; s = s.substr(0, s.length() - 3)
	return s + out

static func run_race(r: Dictionary) -> void:
	if not r.has("card"): _declare(r)     # (declare_week normally did this already)
	var field: Array = []
	for id in r.entries: field.append(Breeding.get_horse(id))
	for k in field.size():
		var h: Dictionary = field[k]
		h.carried = float(r.card[k].kg); h.c["raceBw"] = int(r.card[k].bw)
		h["injRisk"] = CAUTION_RISK if int(h.c.get("sore", 0)) > 0 else 1.0
	var mine := false
	for h in field:
		if _in_stable(h.id): mine = true
	var order: Array = []
	var graded: bool = r.cls == "G1" and String(r.get("country", "JPN")) == "JPN"
	if mine or force_full or graded:      # G1s run in the full engine so they can be replayed (G2/G3: fast model, ~1 s saved each)
		var seed := int(floor(rng() * 1e9))
		var opts := { "course": r.course, "dist": r.dist, "going": r.going, "seed": seed, "injuries": true, "eiph": true, "risk": 1,
			"weather": r.get("weather", "fine"), "hour": r.get("hour", 15.67), "week": W.week }
		var race := RaceEngine.run_headless(field, opts)
		var res := RaceEngine.results(race)
		if force_full: r["laps"] = res.laps
		for x in res.rows:
			var dnf: bool = x.pos == -1
			order.append({ "h": x.r.h, "t": null if dnf else x.time, "dnf": dnf, "inj": not x.r.injury.is_empty(), "injSer": bool(x.r.injury.get("serious", false)), "l3f": x.last3f, "margin": x.margin })
		var copies: Array = []
		for h in field:
			var cp: Dictionary = h.duplicate(true)
			cp.erase("c")
			copies.append(cp)
		var ro: Dictionary = opts.duplicate()
		ro["cls"] = r.get("cls", "")
		var rec := { "opts": ro, "field": copies, "name": r.name, "y": W.year, "w": W.week }
		if mine: W.replays[r.id] = rec
		if graded:
			if not W.has("gradedReplays"): W["gradedReplays"] = {}
			W.gradedReplays[r.id] = rec
			while W.gradedReplays.size() > 40: W.gradedReplays.erase(W.gradedReplays.keys()[0])
		if W.replays.size() > 30: W.replays.erase(W.replays.keys()[0])
	else:
		for h in field:
			var t := quick_time(h, r, gauss() * QSIG)
			order.append({ "h": h, "t": t, "t0": quick_time(h, r, 0.0), "dnf": false, "inj": false })
		order = SimUtil.stable_sort(order, func(a, b): return a.t - b.t)
		# horses race as a pack: the pace is set by the field and the ones behind save energy in the slipstream, so
		# finishing gaps are smaller than the gaps between solo time-trials (pack factor, calibrated to JRA margins)
		var tw: float = order[0].t
		for o in order: o.t = tw + (float(o.t) - tw) * PACK
		var fav: Dictionary = order[0]
		for o in order:
			if o.t0 < fav.t0: fav = o
		W["favN"] = W.get("favN", 0) + 1
		if is_same(fav, order[0]): W["favW"] = W.get("favW", 0) + 1
		for o in order:
			if rng() < 0.012 * exp(1.6 * (0.5 - o.h.stats.sound / 100.0)):
				o.inj = true
				if rng() < 0.3: o.dnf = true
		order = SimUtil.stable_sort(order, func(a, b):
			var d := int(a.dnf) - int(b.dnf)
			return float(d) if d != 0 else a.t - b.t)
	var result: Array = []
	for i in order.size():
		var o: Dictionary = order[i]
		result.append({ "id": o.h.id, "name": o.h.name, "pos": "DNF" if o.dnf else i + 1, "time": null if o.dnf else o.t, "margin": o.get("margin") })
	r["result"] = result
	var prize: float = r.get("prize", BIG_G1.get(r.name, PRIZE[r.cls]))
	if Intl.is_intl(r):
		for o in order:
			if _in_stable(o.h.id) and Finance.owns(o.h): ledger("Travel, quarantine and staff: %s to %s" % [o.h.name, r.name], -float(Intl.TRAVEL_COST.get(r.country, 15.0)), "travel")
	graded = r.cls in ["G1", "G2", "G3"]
	for i in order.size():
		var o: Dictionary = order[i]
		var h: Dictionary = o.h
		var c: Dictionary = h.c
		var kc = crop_rec(h)      # progeny funnel of the crop (see sim/tests/funnel.gd)
		if kc != null and int(c.starts) == 0: kc["deb"] = int(kc.get("deb", 0)) + 1
		c.starts += 1; c.last = W.week; c["lastY"] = W.year; c.fat += 0.35 + r.dist / 8000.0; c.fit = minf(1.0, c.fit + 0.02)
		if not _in_stable(h.id) and h.get("foreign") == null: Planner.after_race(h, r, -1 if o.dnf else i + 1, order.size())
		var pos := 99 if o.dnf else i + 1
		if pos <= 5: c.earn += prize * PLACE_SHARE[pos - 1]
		if pos <= 3: c.places += 1
		if W.has("player") and (_in_stable(h.id) or h.has("bredBy") or W.player.get("care", []).has(int(h.id))):
			Finance.race_payout(r, h, pos, order.size(), prize)
		c.history.insert(0, { "y": W.year, "w": W.week, "race": r.name, "cls": r.cls, "course": r.course, "dist": r.dist, "pos": "DNF" if o.dnf else pos, "of": order.size(),
			"time": SimUtil.js_round(o.t * 10.0) / 10.0 if o.t else null, "j": h.get("jockeyId"), "tr": c.get("trainer"), "kg": h.get("carried") })
		if W.has("jockeys"): People.ride(h.get("jockeyId"), c.get("trainer"), pos, prize * PLACE_SHARE[pos - 1] if pos <= 5 else 0.0)
		Owners.record(h, pos, prize * PLACE_SHARE[pos - 1] if pos <= 5 else 0.0, r)
		if c.history.size() > 12: c.history.resize(12)
		if pos == 1:
			var k = kc
			if k != null:
				if c.wins == 0: k.won += 1
				if r.cls == "G1" and c.g1 == 0: k.g1 += 1
				if (r.cls == "G2" or r.cls == "G3") and c.graded == 0: k.graded += 1
			c.wins += 1; c.cm += CLASS_GAIN[r.cls]
			if r.cls == "G1":
				c.g1 += 1; c.bigWins.append("%s %d" % [r.name, W.year])
				if kc != null and c.g1 == 2: kc["elite"] = int(kc.get("elite", 0)) + 1
				if kc != null and c.g1 == 5: kc["legend"] = int(kc.get("legend", 0)) + 1
			if r.cls == "G2" or r.cls == "G3":
				c.graded += 1; c.bigWins.append("%s %d" % [r.name, W.year])
		if pos == 2 and graded: c.cm += CLASS_GAIN[r.cls] / 2.0
		if kc != null and not c.get("wasOpen", false) and class_of(c) == "OP":
			c["wasOpen"] = true; kc["open"] = int(kc.get("open", 0)) + 1
			var via := "%s-%s" % [r.cls, "win" if pos == 1 else "2nd"]
			kc[via] = int(kc.get(via, 0)) + 1
		# horses that keep finishing well beaten are moved to local (NAR) racing — the usual JRA path for a horse that
		# cannot earn in its class (the player decides for own horses)
		if pos <= 5: c["bad"] = 0
		elif pos > order.size() * TRANSFER_FRAC: c["bad"] = int(c.get("bad", 0)) + 1
		if int(c.get("bad", 0)) >= TRANSFER_BAD and not _in_stable(h.id) and c.status == "active" and not (r.cls in ["G1", "G2", "G3", "OP"]):
			retire(h, "moved to local (NAR) racing")
		if o.inj: injure(h, r.name, 1 if bool(o.get("injSer", false)) else (1 if rng() < 0.1 else 0))
		c.entry = null
	Ratings.rate_race(r, order)
	for i in order.size():
		result[i]["rt"] = order[i].get("rt"); result[i]["kg"] = order[i].h.get("carried")
		if result[i].get("margin") == null and i > 0 and order[i].t != null and order[i - 1].t != null:
			result[i]["margin"] = Ratings.margin_text((float(order[i].t) - float(order[i - 1].t)) * float(r.dist) / float(order[0].t) / Ratings.LEN_M)
	_settle(r)
	if graded:
		var top3: Array = []
		var top4: Array = []
		for x in result.slice(0, 3): top3.append(x.name)
		for x in result.slice(0, 4): top4.append(int(x.id))
		W.gradedLog.insert(0, { "rid": r.id, "y": W.year, "w": W.week, "name": r.name, "cls": r.cls, "course": r.course, "dist": r.dist, "top3": top3, "top4": top4,
			"sex": r.get("sex", ""), "age": r.age, "time": result[0].time, "level": r.get("level", 0.0) })
	if W.gradedLog.size() > 200: W.gradedLog.resize(200)
	if mine:
		for i in order.size():
			var o: Dictionary = order[i]
			if _in_stable(o.h.id):
				log_msg("%s finished %s/%d in %s (%s %d m)" % [o.h.name, "DNF" if o.dnf else str(i + 1), order.size(), r.name, RaceEngine.COURSES[r.course].short, r.dist], o.h)

## progress of the week being simulated (read by the UI while advance_week runs on a worker thread)
static var PROGRESS := { "stage": "", "f": 0.0 }

static func _stage(t: String, f: float) -> void:
	PROGRESS["stage"] = t
	PROGRESS["f"] = f

static func advance_week() -> Array:
	_stage("Declaring fields and race cards", 0.02)
	declare_week()
	var nr: int = W.races.size()
	for i in nr:
		_stage("Racing: %s" % W.races[i].name, 0.25 + 0.45 * float(i) / maxf(1.0, nr))
		run_race(W.races[i])
	var done: Array = W.races
	W.lastWeek = { "y": W.year, "w": W.week, "races": done }
	_stage("Training", 0.72)
	for h in active():
		Training.week(h)          # the player's plan for own horses, the trainer's plan for the rest
	# end of September: winless 3yo can no longer race in maiden races
	if W.week == 39:
		for h in active():
			if h.age == 3 and h.c.wins == 0: retire(h, "no win by the end of maiden races")
	var month0 := month_of_week(W.week)
	if W.has("player"):
		Profile.week_tick()
		if W.week == 52 or month_of_week(W.week + 1) != month0: Finance.settle_month(month0)   # month end (December: before the new year)
	W.week += 1
	if W.week > 52:
		_stage("New year: retirements, ratings, new crop", 0.78)
		new_year()
	if W.has("player"):
		Profile.licence_check()
		Profile.breeder_spring_sales()
	_stage("Breeding, foals and scouting", 0.85)
	Stud.week_tick()
	_stage("Sales", 0.95)
	Auction.week_tick()
	W.races = []
	build_week()
	_stage("Done", 1.0)
	return done

static func auto_train(h: Dictionary) -> void:
	var c: Dictionary = h.c
	c.train = "light" if c.fat > 0.6 else "normal"
	c.work = "hill" if rng() < 0.5 else "woodchip"

static func new_year() -> void:
	# retirements at year end
	Intl.year_end(R)
	for h in active():
		var c: Dictionary = h.c
		var cl := class_of(c)
		if (_in_stable(h.id) and String(c.get("owner", "")) == "") or h.has("foreign"): continue   # the player decides for own horses (owners decide for horses a player trains)
		if h.age >= 8: retire(h, "age")
		elif c.g1 > 0 and h.sex == "M" and h.age >= 4 and rng() < 0.6: retire(h, "to stud after G1 success")
		elif h.sex == "F" and h.age >= 5 and rng() < 0.6: retire(h, "to the breeding shed")
		elif h.age >= 5 and (cl == "MDN" or cl == "1W") and rng() < 0.6: retire(h, "not competitive")
		elif h.age >= 6 and cl != "OP" and rng() < 0.5: retire(h, "age and class")
		elif h.age >= 4 and h.stats.speed < 50 and rng() < 0.7: retire(h, "not fast enough")
	# stallions/mares age out
	for h in Breeding.book.values():
		if h.get("retired", false) and h.age >= (22 if h.sex == "M" else 20):
			h.retired = false
			if h.has("c"): h.c.status = "retired"
	Ratings.year_end(W.year)          # race ratings, grading review, JPN Thoroughbred Ranking
	if W.has("player"): Profile.year_end()
	People.year_end(int(W.year))
	W.year += 1; W.week = 1
	for h in Breeding.book.values():
		if h.get("age") != null: h.age += 1
	Rivals.year_end()
	_pick_cache = {}
	Rivals.make_crop(int(W.year) - 1, 1, R)          # last year's crop: the rest of Japan's best yearlings
	_pick_cache = null
	# foals are born during the spring (Stud.week_tick), from last season's coverings
	prune()
	Intl.top_up(R)

## keep: active horses, stud/broodmares, player's horses and their ancestors (3 generations); drop the rest
static func prune() -> void:
	var keep := {}
	var add := func(self_ref: Callable, id: Variant, depth: int) -> void:
		var h = Breeding.get_horse(id)
		if h == null or depth > 5: return
		keep[int(h.id)] = true
		self_ref.call(self_ref, h.sire, depth + 1)
		self_ref.call(self_ref, h.dam, depth + 1)
	for h in Breeding.book.values():
		var c = h.get("c")
		if h.get("retired", false) or (c != null and c.status == "active") or _in_stable(h.id) or (c != null and c.get("g1", 0) > 0) or h.get("real", false): add.call(add, h.id, 0)
		var rp = h.get("repro")
		if rp != null:   # sires of foals still to be born
			for sid in [rp.get("sire"), rp.get("plan"), rp.next.sire if rp.get("next") != null else null]:
				if sid != null: add.call(add, sid, 0)
	for h in Breeding.book.values():
		var c = h.get("c")
		if c != null and c.status != "active" and not _in_stable(h.id):
			c.history = c.history.slice(0, 3) if c.get("history") else []
	for id in Breeding.book.keys():
		if not keep.has(int(id)): Breeding.forget(Breeding.book[id])
	Breeding.clear_memo()


# ---------- player ----------
static func add_to_stable(hid: int) -> void:
	var h = Breeding.get_horse(hid)
	if h == null: return
	if h.get("age") == null: h["age"] = 0
	if not W.stable.has(hid): W.stable.append(hid)
	if not h.has("c"): h["c"] = new_career(h, W.year - h.age)

static func buy_yearling() -> Array:
	return active().filter(func(h): return h.age == 1 and not _in_stable(h.id))

static func retire_horse(id: int, why := "owner's decision") -> void:
	retire(Breeding.get_horse(id), why)

static func stats() -> Dictionary:
	var act := active().filter(func(h): return h.age >= 2)
	var t := {}
	for h in act:
		var k := tier_of(h)
		t[k] = t.get(k, 0) + 1
	return { "n": act.size(), "tiers": t, "total": Breeding.book.size() }

## Re-run a stored race (same seed + same horses = identical race).
## stored replay (the player's races, plus recent graded races)
static func replay_of(race_id: int) -> Variant:
	if W.replays.has(race_id): return W.replays[race_id]
	return W.get("gradedReplays", {}).get(race_id)

static func replay_race(race_id: int) -> RaceEngine.Race:
	var rp = replay_of(race_id)
	if rp == null: return null
	return RaceEngine.run_headless(rp.field.duplicate(true), rp.opts)

## Exact save (Godot binary, compressed). Use save_json() only to exchange saves with the JavaScript version:
## Godot's JSON reader can change the last binary digit of some numbers.
static func save_data() -> PackedByteArray:
	W.rngState = R.state
	var raw := var_to_bytes({ "v": 1, "W": W, "book": { "nextId": Breeding.next_id, "book": Breeding.book } })   # full precision
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return out

static func load_data(data: PackedByteArray) -> Dictionary:
	var raw := data.slice(4).decompress(data.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	var o: Dictionary = bytes_to_var(raw)
	W = o.W
	R = SimRng.new(int(W.rngState))
	Breeding.book = o.book.book
	Breeding.next_id = int(o.book.nextId)
	Breeding.clear_memo()
	Breeding.names = {}
	Stud._pex = {}
	QCACHE = {}
	return W

static func save_to_file(path := "user://career.sav") -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_buffer(save_data())
	f.close()
	return OK

static func load_from_file(path := "user://career.sav") -> bool:
	if not FileAccess.file_exists(path): return false
	load_data(FileAccess.get_file_as_bytes(path))
	return true

## JSON save in the same layout as the JavaScript version (for import/export).
static func save_json() -> String:
	W.rngState = R.state
	return JSON.stringify({ "W": W, "book": Breeding.export_book() }, "", false, true)

static func load_json(json: String) -> Dictionary:
	var o: Dictionary = JSON.parse_string(json)
	W = SimUtil.json_ints(o.W)
	W.crops = SimUtil.int_keys(W.crops)
	if W.has("rivalCrops"): W.rivalCrops = SimUtil.int_keys(W.rivalCrops)
	W.replays = SimUtil.int_keys(W.replays)
	if W.has("gradedReplays"): W.gradedReplays = SimUtil.int_keys(W.gradedReplays)
	R = SimRng.new(int(W.rngState) & 0xFFFFFFFF)
	Breeding.import_book(o.book)
	Stud._pex = {}
	return W

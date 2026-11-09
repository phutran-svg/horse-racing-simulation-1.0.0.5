class_name Breeding
extends RefCounted
## Breeding & pedigree v0.5 (GDScript port of breed.js). Pure logic.
##  * MSTN g.66493737 C/T: one allele from each parent (Mendelian) -> C:C / C:T / T:T (Hill et al. 2010)
##  * Each stat = genetic (breeding) value + environment. Offspring breeding value = mid-parent value
##    + Mendelian sampling noise (half the additive variance, reduced by parental inbreeding).
##  * Coat colour: Extension (E/e), Agouti (A/a), Grey (G dominant).
##  * Inbreeding coefficient F (Wright) from the pedigree; inbreeding depression lowers stats, mostly soundness.
## Horses are Dictionaries with the same keys as the JavaScript version (save files stay compatible).

const STATS := ["speed", "stamina", "accel", "strength", "burst", "guts", "agility", "temper", "sound", "wind"]
const TRAITS := ["speed", "stamina", "accel", "strength", "burst", "guts", "agility", "temper", "sound", "wind", "dirt", "grow", "going"]
## heritabilities. Surface preference is strongly inherited (dirt sires get dirt horses); growth type (early/late) and
## going preference (firm/soft ground) moderately (game estimates; no published h² for these in Japan)
const H2 := { "speed": 0.35, "stamina": 0.3, "accel": 0.3, "strength": 0.3, "burst": 0.3, "guts": 0.2, "agility": 0.2, "temper": 0.25, "sound": 0.15, "wind": 0.2, "dirt": 0.5, "grow": 0.35, "going": 0.3 }
## traits kept outside `stats` (0–100, centre 50): dirt aptitude, growth type (100 = very early), going (100 = loves soft ground)
const SIDE := { "dirt": [50.0, 22.0], "grow": [50.0, 16.0], "going": [50.0, 16.0] }
static func mu(k: String) -> float: return float(SIDE[k][0]) if SIDE.has(k) else MU
const MU := 60.0
const SD := 12.0
static var SPEED_FLOOR := 45.0   # no JRA racehorse is slower than this on the Speed scale (maiden-level ~50)
const PERF := { "speed": true, "stamina": true, "accel": true, "strength": true, "burst": true, "guts": true, "agility": true, "wind": true }
const NA := ["Sakura", "Kaze", "Hoshi", "Tsuki", "Golden", "Silver", "Thunder", "Mirai", "Hayate", "Ryu", "Kumo", "Sora", "Yume", "Hikari", "Storm", "Crest", "Fuji", "Royal", "Lucky", "Swift", "Aoi", "Kin", "Shiro", "Kuro", "Tenku", "Gekko", "Raijin", "Asahi",
	"Amber", "Blue", "Crimson", "Daring", "Eternal", "Fairy", "Gallant", "Grand", "Happy", "Iron", "Jade", "Midnight", "Noble", "Ocean", "Pearl", "Quiet", "Rising", "Scarlet",
	"Shining", "Sunny", "True", "Velvet", "Wild", "Yamato", "Zen", "Akatsuki", "Benten", "Chikara", "Daichi", "Fubuki", "Haru", "Inazuma", "Kagerou", "Midori", "Natsu", "Orion", "Rin", "Sakigake", "Tamamo", "Umi"]
const NB := ["Arrow", "Dancer", "Spirit", "Flash", "Legend", "Crown", "Wind", "Dream", "Blaze", "Comet", "Rose", "King", "Queen", "Ace", "Bolt", "Ray", "Hope", "Tiger", "Falcon", "Glory", "Sonata", "Halo", "Emperor", "Lady", "Bravo", "Miracle",
	"Arc", "Breeze", "Cascade", "Diva", "Echo", "Fortune", "Garden", "Harmony", "Impact", "Jewel", "Knight", "Lancer", "Melody", "Nova", "Opera", "Prince", "Quest", "Rhapsody", "Saga",
	"Tempest", "Unity", "Victory", "Waltz", "Zephyr", "Boy", "Girl", "Heart", "Hero", "Star", "Moon", "Sun", "Road", "Ridge", "Ruler", "Vow", "Wing"]
const COAT_RGB := { "chestnut": "#a0522d", "bay": "#7a4a26", "dark bay": "#4a2a16", "black": "#211b17", "grey": "#b9b5ae" }

static var book: Dictionary = {}     # id (int) -> horse
static var next_id := 1
static var memo: Dictionary = {}
static var names: Dictionary = {}    # used as a set


static func _pick(rng: SimRng, s: Array) -> String:
	return s[int(floor(rng.next() * s.size()))]

static func unique_name(rng: SimRng) -> String:
	if names.is_empty() and not book.is_empty():
		for h in book.values(): names[h.name] = true
	for i in 60:
		var n := _pick(rng, NA) + " " + _pick(rng, NB)
		if not names.has(n):
			names[n] = true
			return n
	for suf in [" II", " III", " IV", " V"]:
		var n2: String = _pick(rng, NA) + " " + _pick(rng, NB) + suf
		if not names.has(n2):
			names[n2] = true
			return n2
	var n3 := _pick(rng, NA) + " " + _pick(rng, NB) + " " + str(next_id)
	names[n3] = true
	return n3

static func coat_of(c: Dictionary) -> String:
	if String(c.G).contains("G"): return "grey"
	if c.E == "ee": return "chestnut"
	if c.A == "aa": return "black"
	return "dark bay" if c.dark else "bay"

## two alleles, the dominant (big) one first
static func _sort_g(a: String, b: String, big: String) -> String:
	if b == big and a != big: return b + a
	return a + b

static func gene_label(m: String) -> String:
	if m == "CC": return "CC"
	if m == "TT": return "TT"
	return "CT"

## running style follows the gene and temperament, with plenty of noise
static func style_for(rng: SimRng, h: Dictionary) -> String:
	var w: Array = { "CC": [0.15, 0.34, 0.32, 0.19], "CT": [0.09, 0.28, 0.36, 0.27], "TT": [0.06, 0.24, 0.36, 0.34] }[h.gene].duplicate()
	if float(h.stats.temper) < 45.0:
		w[0] += 0.05; w[3] += 0.05
	var tot := 0.0
	for x in w: tot += x
	var u := rng.next() * tot
	var st := ["front", "stalker", "mid", "closer"]
	for i in 4:
		u -= w[i]
		if u <= 0.0: return st[i]
	return "mid"

const _TO_M := { "Lady": "Lord", "Queen": "King", "Diva": "Hero", "Girl": "Boy" }
const _TO_F := { "King": "Queen", "Prince": "Princess", "Emperor": "Empress", "Boy": "Girl", "Knight": "Lady", "Lord": "Lady" }
## colts don't get "Lady"/"Queen" names and fillies don't get "King"/"Boy"
static func _sex_name(h: Dictionary) -> void:
	var parts: PackedStringArray = String(h.name).split(" ")
	if parts.size() < 2: return
	var mp: Dictionary = _TO_M if h.sex == "M" else _TO_F
	if not mp.has(parts[1]): return
	names.erase(h.name)
	parts[1] = mp[parts[1]]
	var n := " ".join(parts)
	if names.has(n): n += " II"
	names[n] = true
	h.name = n

static func _finish(h: Dictionary, rng: SimRng) -> Dictionary:
	_sex_name(h)
	h["gene"] = gene_label(h.mstn)
	h["coat"] = coat_of(h.coatG)
	h["coatColor"] = COAT_RGB[h.coat]
	h["carried"] = 55 if h.sex == "F" else 57
	if not h.get("style"): h["style"] = style_for(rng, h)
	return h

static func founder(rng: SimRng, sex: String, quality: float, extra: Dictionary = {}) -> Dictionary:
	var id := next_id
	next_id += 1
	var h := { "id": id, "name": unique_name(rng), "sex": sex, "sire": null, "dam": null, "born": 0, "gen": 0, "F": 0, "gv": {}, "stats": {}, "jockey": 75, "form": 0 }
	h["bw"] = int(SimUtil.js_round((460.0 if sex == "F" else 490.0) + rng.gauss() * 18.0))
	var m1 := "C" if rng.next() < 0.47 else "T"
	var m2 := "C" if rng.next() < 0.47 else "T"
	var ms := m1 + m2
	h["mstn"] = "CT" if ms == "TC" else ms
	var e1 := "E" if rng.next() < 0.5 else "e"
	var e2 := "E" if rng.next() < 0.5 else "e"
	var a1 := "A" if rng.next() < 0.62 else "a"
	var a2 := "A" if rng.next() < 0.62 else "a"
	var gg := "Gg" if rng.next() < 0.03 else "gg"
	var dark := rng.next() < 0.35
	h["coatG"] = { "E": _sort_g(e1, e2, "E"), "A": _sort_g(a1, a2, "A"), "G": gg, "dark": dark }
	var qShared := rng.gauss() * SD * 0.55            # general class of the horse (shared by performance traits)
	for k in TRAITS:
		var q: float = SIDE[k][0] if SIDE.has(k) else quality
		var sd: float = SIDE[k][1] if SIDE.has(k) else SD * 0.6
		var p := q + rng.gauss() * sd + (qShared if PERF.has(k) else 0.0)
		if k == "burst" or k == "strength": p += 4.0 if h.mstn == "CC" else (-3.0 if h.mstn == "TT" else 0.0)
		if k == "stamina": p += 4.0 if h.mstn == "TT" else (-4.0 if h.mstn == "CC" else 0.0)
		if k == "dirt": p += 8.0 if h.mstn == "CC" else 0.0
		p = clampf(SimUtil.js_round(p), 1.0, 100.0)
		if k == "speed": p = maxf(SPEED_FLOOR, p)
		h.stats[k] = int(p)
		var h2: float = H2[k]
		h.gv[k] = mu(k) + h2 * (p - mu(k)) + rng.gauss() * SD * sqrt(h2 * (1.0 - h2))   # best guess of the genetic value behind the phenotype
	for k in SIDE:
		h[k] = h.stats[k]
		h.stats.erase(k)
	h.merge(extra, true)
	book[id] = _finish(h, rng)
	return h


# ---- kinship / inbreeding (Wright), recursive with memo ----
static func get_horse(id: Variant) -> Variant:
	if id == null: return null
	return book.get(int(id))

static func kin(a: Variant, b: Variant) -> float:
	if a == null or b == null: return 0.0
	if a.id == b.id: return 0.5 * (1.0 + inb(a))
	var x: Dictionary = a
	var y: Dictionary = b
	if int(x.id) < int(y.id):            # expand the younger one
		x = b; y = a
	var key := "%d:%d" % [x.id, y.id]
	if memo.has(key): return memo[key]
	var v := 0.5 * (kin(get_horse(x.sire), y) + kin(get_horse(x.dam), y))
	memo[key] = v
	return v

static func inb(h: Dictionary) -> float:
	if h.sire == null: return 0.0
	return kin(get_horse(h.sire), get_horse(h.dam))

static func breed(sire: Dictionary, dam: Dictionary, rng: SimRng, opts: Dictionary = {}) -> Dictionary:
	assert(sire.sex == "M" and dam.sex == "F", "Need a stallion (M) and a mare (F)")
	var id := next_id
	next_id += 1
	var F := kin(sire, dam)
	var nm: String = opts.name if opts.get("name") else unique_name(rng)
	var h := { "id": id, "name": nm, "sex": "M" if rng.next() < 0.5 else "F", "sire": sire.id, "dam": dam.id, "born": maxi(int(sire.born), int(dam.born)) + 1,
		"gen": maxi(int(sire.gen), int(dam.gen)) + 1, "F": F, "gv": {}, "stats": {}, "jockey": 75, "form": 0 }
	h["bw"] = int(SimUtil.js_round((460.0 if h.sex == "F" else 490.0) + ((float(sire.bw) - 490.0) + (float(dam.bw) - 460.0)) * 0.25 + rng.gauss() * 15.0))
	var sm: String = sire.mstn[int(floor(rng.next() * 2.0))]
	var dm: String = dam.mstn[int(floor(rng.next() * 2.0))]
	h["mstn"] = sm + dm if sm <= dm else dm + sm      # 'CC','CT','TT'
	var cg := {}
	for gk in ["E", "A", "G"]:
		var xa: String = sire.coatG[gk][int(floor(rng.next() * 2.0))]
		var ya: String = dam.coatG[gk][int(floor(rng.next() * 2.0))]
		cg[gk] = _sort_g(xa, ya, gk)
	cg["dark"] = rng.next() < 0.35
	h["coatG"] = cg
	Markings.inherit(h, sire, dam)       # white markings: mid-parent value + noise (hash-based, no RNG used)
	var Fp := (float(sire.F) + float(dam.F)) / 2.0
	var mShared := rng.gauss() * SD * sqrt(0.3 / 2.0 * (1.0 - Fp)) * 0.7      # shared Mendelian + environment (general class)
	var eShared := rng.gauss() * SD * 0.35
	for k in TRAITS:
		var h2: float = H2[k]
		var sdA := SD * sqrt(h2)
		var sh := 1.0 if PERF.has(k) else 0.0
		var gv := (float(sire.gv.get(k, mu(k))) + float(dam.gv.get(k, mu(k)))) / 2.0 + rng.gauss() * sdA * sqrt(0.5 * (1.0 - Fp)) * (0.7 if sh > 0.0 else 1.0) + sh * mShared   # Mendelian sampling
		h.gv[k] = gv
		var p := gv + rng.gauss() * SD * sqrt(1.0 - h2) * (0.8 if sh > 0.0 else 1.0) + sh * eShared                                                       # environment
		p -= F * (60.0 if k == "sound" else (0.0 if SIDE.has(k) else 12.0))   # inbreeding depression (soundness: fewer starts, Anim Genet 2023)
		p = clampf(SimUtil.js_round(p), 1.0, 100.0)
		if k == "speed": p = maxf(SPEED_FLOOR, p)
		if SIDE.has(k): h[k] = int(p)
		else: h.stats[k] = int(p)
	book[id] = _finish(h, rng)
	return h

## Expected outcome of a mating: MSTN genotype odds, coat odds, inbreeding F, expected genetic values.
static func predict(sire: Dictionary, dam: Dictionary) -> Dictionary:
	var pr := { "CC": 0.0, "CT": 0.0, "TT": 0.0 }
	for a in sire.mstn:
		for b in dam.mstn:
			pr[a + b if a <= b else b + a] += 0.25
	var coat := {}
	for e1 in sire.coatG.E:
		for e2 in dam.coatG.E:
			for a1 in sire.coatG.A:
				for a2 in dam.coatG.A:
					for g1 in sire.coatG.G:
						for g2 in dam.coatG.G:
							var c := "grey" if (g1 + g2).contains("G") else ("chestnut" if e1 + e2 == "ee" else ("black" if a1 + a2 == "aa" else "bay"))
							coat[c] = coat.get(c, 0.0) + 1.0 / 64.0
	var F := kin(sire, dam)
	var ev := {}
	for k in TRAITS:
		ev[k] = (float(sire.gv.get(k, mu(k))) + float(dam.gv.get(k, mu(k)))) / 2.0 - F * (60.0 if k == "sound" else (0.0 if SIDE.has(k) else 12.0))
	return { "mstn": pr, "coat": coat, "F": F, "ev": ev }

static func pedigree(h: Variant, depth := 3) -> Variant:
	if h == null or depth < 0: return null
	return { "h": h, "sire": pedigree(get_horse(h.sire), depth - 1), "dam": pedigree(get_horse(h.dam), depth - 1) }

static func byline(h: Dictionary) -> String:
	var s = get_horse(h.sire)
	var d = get_horse(h.dam)
	var ds = get_horse(d.sire) if d != null else null
	if s == null and d == null: return "foundation horse"
	if d != null and d.get("anon", false):
		return "by %s out of a %s mare" % [s.name if s != null else "unknown", ds.name if ds != null else "unknown"]
	return "by %s out of %s%s" % [s.name if s != null else "unknown", d.name if d != null else "unknown", " (by %s)" % ds.name if ds != null else ""]

## take a horse out of the stud book and free its name (a loaded save rebuilds the name set from the book, so the
## running game must forget names the same way — otherwise new foals' names, and the draws behind them, differ)
static func forget(h: Dictionary) -> void:
	book.erase(h.id)
	names.erase(h.name)

static func reset() -> void:
	book = {}
	next_id = 1
	memo = {}
	names = {}

static func seed_book(rng: SimRng, n_stallions := 10, n_mares := 16) -> void:
	reset()
	for i in n_stallions: founder(rng, "M", 74, { "retired": true })
	for i in n_mares: founder(rng, "F", 64, { "retired": true })

static func stallions() -> Array:
	return book.values().filter(func(h): return h.sex == "M" and h.get("retired", false))

static func mares() -> Array:
	return book.values().filter(func(h): return h.sex == "F" and h.get("retired", false))

static func clear_memo() -> void:
	memo = {}

## Round every non-integer number to 0.1 (keeps saves small, same as the JavaScript version).
static func _round01(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f): return int(f)
		return SimUtil.js_round(f * 10.0) / 10.0
	if v is Array:
		var o := []
		for x in v: o.append(_round01(x))
		return o
	if v is Dictionary:
		var d := {}
		for k in v: d[k] = _round01(v[k])
		return d
	return v

static func export_book() -> Dictionary:
	return { "v": 1, "nextId": next_id, "book": _round01(book) }

static func import_book(o: Dictionary) -> void:
	assert(o.has("book"), "not a stud book")
	var b: Dictionary = SimUtil.json_ints(o.book)
	book = SimUtil.int_keys(b)
	next_id = int(o.nextId)
	memo = {}
	names = {}

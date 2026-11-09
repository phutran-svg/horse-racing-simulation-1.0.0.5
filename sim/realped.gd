class_name RealPed
## Real pedigrees (data/realped.json, built from the open-horse-data set — see data/CREDITS.md).
## * fills in the parents of every real horse in the stud book, up to five generations back
## * adds ~40 more stallions around the world (real 2026 fees; ~ = estimate)
## * gives the world real Japanese broodmares (dams of 2020–2024 JRA foals) with their real families
## Stats are game estimates made from each horse's rating (BHA-style scale) and record; names, years and parents are real.

const PATH := "res://data/realped.json"
## extra stallions: [name, fee ¥M 2026, country, estimate?] (fees: Coolmore, Darley, Juddmonte, Aga Khan, Lane's End,
## Spendthrift, Rex Stud and Australian studs; converted at about ¥195/£, ¥165/€, ¥150/$, ¥100/A$)
const EXTRA := [
	["Kingman", 24.4, "UK", false], ["Siyouni", 24.8, "France", false], ["Too Darn Hot", 19.5, "UK", false], ["Blue Point", 16.5, "Ireland", false],
	["No Nay Never", 16.5, "Ireland", false], ["Zarak", 13.2, "France", false], ["Camelot", 9.9, "Ireland", false], ["Starspangledbanner", 9.9, "Ireland", false],
	["Havana Grey", 9.8, "UK", true], ["Mehmas", 9.9, "Ireland", true], ["Showcasing", 5.9, "UK", false], ["Ghaiyyath", 3.3, "Ireland", false],
	["Justify", 30.0, "USA", false], ["Flightline", 18.8, "USA", false], ["Constitution", 16.5, "USA", false], ["Quality Road", 15.0, "USA", false],
	["Vekoma", 15.0, "USA", false], ["Omaha Beach", 11.3, "USA", false], ["Yaupon", 9.0, "USA", false], ["Tapit", 18.0, "USA", true], ["Uncle Mo", 11.0, "USA", true],
	["I Am Invincible", 22.0, "Australia", false], ["Zoustar", 22.0, "Australia", true], ["Snitzel", 19.0, "Australia", true], ["Extreme Choice", 27.5, "Australia", false],
	["Home Affairs", 8.3, "Australia", false], ["Capitalist", 4.4, "Australia", false],
	["Bricks And Mortar", 2.0, "Japan", false], ["Silver State", 4.0, "Japan", true], ["Leontes", 1.5, "Japan", true], ["Satono Diamond", 1.5, "Japan", true],
	["Fierement", 1.0, "Japan", true], ["Danon Premium", 1.5, "Japan", true], ["Thunder Snow", 2.0, "Japan", true], ["Mikki Isle", 1.0, "Japan", true],
	["Big Arthur", 1.0, "Japan", true], ["Al Ain", 1.0, "Japan", true], ["Cafe Pharoah", 3.0, "Japan", true], ["Titleholder", 2.5, "Japan", true],
	["Win Bright", 1.0, "Japan", true], ["Le Vent Se Leve", 1.0, "Japan", true],
]
const ALIAS := { "Swarve Richard": "Suave Richard" }

static var H: Dictionary = {}       # json key (name with country suffix) → record
static var MAP: Dictionary = {}     # game name → json key
static var BY_DISP: Dictionary = {}
static var MARES: Array = []
static var r0: SimRng

static func load_data() -> bool:
	if not H.is_empty(): return true
	if not FileAccess.file_exists(PATH): return false
	var o = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (o is Dictionary): return false
	H = o.horses; MAP = o.map; MARES = o.mares
	BY_DISP = {}
	for k in H: BY_DISP[String(H[k].disp).to_lower()] = k
	return true

static func key_of(name: String) -> Variant:
	if MAP.has(name) and MAP[name] != null: return MAP[name]
	var n: String = ALIAS.get(name, name)
	if BY_DISP.has(n.to_lower()): return BY_DISP[n.to_lower()]
	return null

## game class (50–95) from the data's rating
static func q_of(rec: Dictionary, sex: String) -> float:
	var r = rec.get("r")
	var scale := String(rec.get("rs", ""))
	if r == null or scale in ["Random", "Pedigree", ""]: return 64.0 if sex == "F" else 74.0
	return clampf(48.0 + (float(r) - 70.0) * 0.68, 50.0, 95.0)

static func _gene(rec: Dictionary) -> String:
	var bd = rec.get("bd")
	if bd == null: return "CT"
	return "CC" if float(bd) < 1400.0 else ("TT" if float(bd) > 2300.0 else "CT")

static func _dirt(rec: Dictionary) -> float:
	match String(rec.get("su", "")):
		"Dirt": return 82.0
		"Turf": return 35.0
		"AW", "All Weather", "Synthetic": return 55.0
	return 50.0

## make sure a real horse (json key) is in the stud book, with its parents down to `depth` generations; returns its id
static func ensure(key: Variant, depth: int, fallback_born := 1950) -> Variant:
	if key == null: return null
	var rec: Dictionary = H.get(key, { "disp": String(key), "s": "M" })
	var disp := String(rec.get("disp", key))
	var h: Dictionary
	if Bloodlines.by_name.has(disp): h = Bloodlines.by_name[disp]
	else:
		var sex := "F" if String(rec.get("s", "M")) == "F" else "M"
		var born: int = int(rec.b) if rec.get("b") != null else fallback_born
		h = Bloodlines._new(r0, disp, sex, born, null, null, q_of(rec, sex), _gene(rec), _dirt(rec))
		h["anc"] = true      # an ancestor: in the book for pedigrees only
		if rec.get("st") != null and not h.has("rec"): h["rec"] = [int(rec.st), int(rec.get("w", 0) if rec.get("w") != null else 0), 0]
		if String(rec.get("c", "")) != "": _coat(h, String(rec.c))
	if depth <= 0: return int(h.id)
	var born_h := int(h.get("born", fallback_born))
	if h.get("sire") == null and rec.get("sire") != null: h.sire = ensure(rec.sire, depth - 1, born_h - 11)
	if (h.get("dam") == null or _is_anon(h.dam)) and rec.get("dam") != null: h.dam = ensure(rec.dam, depth - 1, born_h - 9)
	return int(h.id)

static func _is_anon(id: Variant) -> bool:
	var d = Breeding.get_horse(id)
	return d != null and d.get("anon", false)

static func _coat(h: Dictionary, c: String) -> void:
	var m := { "Bay": "bay", "Brown": "dark bay", "Seal Brown": "dark bay", "Dark Bay": "dark bay", "Black": "dark bay", "Chestnut": "chestnut", "Grey": "grey", "Gray": "grey" }
	var k: String = m.get(c, "")
	if k == "" or not Bloodlines.COAT_G.has(k): return
	h.coatG = Bloodlines.COAT_G[k].duplicate(); h.coat = k; h.coatColor = Breeding.COAT_RGB[k]

## after Bloodlines.build: real parents for every real horse, plus the extra stallions
static func attach(rng: SimRng) -> Array:
	r0 = rng
	if not load_data(): return []
	for n in Bloodlines.by_name.keys():
		var k = key_of(n)
		if k != null: ensure(k, 5, int(Bloodlines.by_name[n].get("born", 1990)))
	var added: Array = []
	for e in EXTRA:
		var k = key_of(e[0])
		var existed: bool = Bloodlines.by_name.has(e[0]) or (k != null and Bloodlines.by_name.has(String(H.get(k, {}).get("disp", ""))))
		var id = ensure(k if k != null else e[0], 5, 2012)
		var s = Breeding.get_horse(id)
		if s == null: continue
		s["real"] = true
		s.erase("anc")
		s.c.status = "stud" if e[2] == "Japan" else "abroad"
		if e[2] == "Japan":
			s["retired"] = true
			var sd := Stud.stud(s)
			sd.since = 2020; sd.fee = float(e[1]); sd["realFee"] = float(e[1]); sd["feeEst"] = e[3]
		else:
			s["abroad"] = e[2]
			var sd := Stud.stud(s)
			sd.fee = float(e[1]); sd["realFee"] = float(e[1]); sd["country"] = e[2]; sd.since = 2000; sd.cap = 999; sd["feeEst"] = e[3]
		if not existed: added.append(s)
	Breeding.clear_memo()
	return added

## real Japanese broodmares for the world (born `from`–`to`), best-documented families first
static func mares(rng: SimRng, n: int, from_y: int, to_y: int) -> Array:
	r0 = rng
	if not load_data(): return []
	var cand: Array = []
	for k in MARES:
		var rec: Dictionary = H.get(k, {})
		if rec.is_empty() or rec.get("b") == null: continue
		if int(rec.b) < from_y or int(rec.b) > to_y: continue
		if Bloodlines.by_name.has(String(rec.disp)): continue
		cand.append(k)
	# shuffle with the world seed, then take n
	for i in range(cand.size() - 1, 0, -1):
		var j := int(floor(rng.next() * (i + 1)))
		var t = cand[i]; cand[i] = cand[j]; cand[j] = t
	var out: Array = []
	for k in cand.slice(0, n):
		var id = ensure(k, 5, 2014)
		var m = Breeding.get_horse(id)
		if m == null: continue
		m.erase("anc")
		m["real"] = true
		m["realMare"] = true
		out.append(m)
	return out

class_name Intl
extends RefCounted
## International racing: the main overseas G1s, the foreign horses who run in them, Japanese raiders, and the
## IFHA publications (LONGINES World's Best Racehorse Rankings, Top 100 G1 races, World's Best Race).
## Region "top" values are true ability levels; the published ratings (best run of the year) come out ~5 lb higher.
##
## Races: real dates (week of the year), venues, distances and approximate winner's prize (¥M at ~¥150/$, ¥165/€,
## ¥190/£, ¥19/HK$, ¥95/A$). "rr" is the race's typical annual race rating in recent IFHA Top-100 lists; it sets
## the strength of the foreign fields. Foreign horses are generated each year per region with ratings drawn so the
## best are at real world levels (Europe ~127, USA dirt ~125, Hong Kong ~123, Australia ~121, Middle East ~118).

# [name, week, course, dist, age, sex, winner prize ¥M, typical race rating, regions, field size, handicap, max Japanese]
const RACES := [
	["Saudi Cup", 8, "riyadh_d", 1800, "4+", "", 1500.0, 121.0, ["USA", "MEA"], 14, false, 4],
	["Dubai Golden Shaheen", 13, "meydan_d", 1200, "3+", "", 225.0, 117.0, ["USA", "MEA"], 13, false, 3],
	["Al Quoz Sprint", 13, "meydan", 1200, "3+", "", 225.0, 116.0, ["EUR", "HK", "AUS"], 14, false, 2],
	["Dubai Turf", 13, "meydan", 1800, "4+", "", 450.0, 119.0, ["EUR", "HK"], 14, false, 4],
	["Dubai Sheema Classic", 13, "meydan", 2410, "4+", "", 520.0, 123.0, ["EUR"], 12, false, 4],
	["Dubai World Cup", 13, "meydan_d", 2000, "4+", "", 1050.0, 120.0, ["USA", "MEA"], 12, false, 4],
	["FWD Champions Mile", 17, "shatin", 1600, "3+", "", 200.0, 118.0, ["HK"], 12, false, 2],
	["FWD QEII Cup", 17, "shatin", 2000, "3+", "", 290.0, 119.0, ["HK", "EUR"], 12, false, 3],
	["Prince of Wales's S", 25, "ascot", 2000, "4+", "", 135.0, 123.0, ["EUR"], 9, false, 1],
	["King George VI and Queen Elizabeth S", 30, "ascot", 2400, "3+", "", 135.0, 123.0, ["EUR"], 9, false, 1],
	["Juddmonte International", 34, "york", 2050, "3+", "", 140.0, 124.0, ["EUR"], 9, false, 1],
	["Irish Champion S", 37, "leopardstown", 2000, "3+", "", 100.0, 123.0, ["EUR"], 10, false, 1],
	["Prix de l'Arc de Triomphe", 40, "longchamp", 2400, "3+", "", 470.0, 125.0, ["EUR"], 16, false, 3],
	["Breeders' Cup Turf", 44, "keeneland", 2400, "3+", "", 310.0, 120.0, ["EUR", "USA"], 12, false, 2],
	["Breeders' Cup Classic", 44, "keeneland_d", 2000, "3+", "", 470.0, 123.0, ["USA"], 12, false, 2],
	["Melbourne Cup", 45, "flemington", 3200, "3+", "", 430.0, 116.0, ["AUS", "EUR"], 20, true, 2],
	["Hong Kong Vase", 50, "shatin", 2400, "3+", "", 220.0, 118.0, ["HK", "EUR"], 12, false, 4],
	["Hong Kong Sprint", 50, "shatin", 1200, "3+", "", 230.0, 120.0, ["HK", "AUS"], 12, false, 3],
	["Hong Kong Mile", 50, "shatin", 1600, "3+", "", 260.0, 121.0, ["HK", "EUR"], 14, false, 4],
	["Hong Kong Cup", 50, "shatin", 2000, "3+", "", 340.0, 120.0, ["HK", "EUR"], 12, false, 4],
]
# region: [surface, horses kept in training, top rating, country codes for "trained", distance mix]
const REGIONS := {
	"EUR": ["turf", 64, 122.0, ["GB", "IRE", "FR"], [1200, 1600, 1600, 2000, 2000, 2400, 2400, 2400, 3200]],
	"USA": ["dirt", 40, 121.0, ["USA"], [1200, 1400, 1800, 2000, 2000]],
	"HK": ["turf", 30, 118.0, ["HK"], [1200, 1200, 1600, 1600, 2000, 2400]],
	"AUS": ["turf", 24, 116.0, ["AUS"], [1200, 1200, 1600, 2000, 3200]],
	"MEA": ["dirt", 14, 114.0, ["UAE", "KSA"], [1200, 1800, 2000]],
}
const TRAVEL_COST := { "UAE": 12.0, "KSA": 12.0, "HK": 8.0, "GB": 25.0, "IRE": 25.0, "FR": 25.0, "USA": 25.0, "AUS": 30.0 }   # ¥M shipping, quarantine, staff
# game ability of a horse that should be rated R (calibrated with tests/intl_calib.gd)
static var FA := { "turf": 68.0, "dirt": 72.0 }
static var FB := 0.45

const WORDS_A := ["Royal", "Silent", "Golden", "Northern", "Wild", "Crimson", "Noble", "Silver", "Midnight", "Grand", "Brave", "Lucky", "Iron", "Celtic", "Desert",
	"Ocean", "Highland", "Emerald", "Shadow", "Rapid", "Velvet", "Dancing", "Flying", "Storm", "Winter", "Summer", "Secret", "Majestic", "Sacred", "Free"]
const WORDS_B := ["Harbour", "Legend", "Spirit", "Prince", "Falcon", "Ascent", "Warrior", "Rhythm", "Dream", "Glory", "Voyage", "Echo", "Monarch", "Empire",
	"Comet", "Anthem", "Crown", "Victory", "Horizon", "Banner", "Duke", "Sovereign", "Arrow", "Lady", "Queen", "Thunder", "Express", "Fortune", "Valley", "Tide"]

static func by_name(name: String) -> Variant:
	for x in RACES:
		if x[0] == name: return x
	return null

static func is_intl(r: Dictionary) -> bool:
	return r.get("intl", false)

static func country_of(course: String) -> String:
	return str(RaceEngine.COURSES[course].get("country", "JPN"))

## the races of this week, as race dictionaries for Career.build_week
static func races_for_week(w: int) -> Array:
	var out := []
	for x in RACES:
		if int(x[1]) != w: continue
		out.append({ "name": x[0], "cls": "G1", "course": x[2], "dist": x[3], "age": x[4], "sex": x[5], "handicap": x[10], "size": x[9],
			"intl": true, "prize": x[6], "rr": x[7], "regions": x[8], "jpMax": x[11], "country": country_of(x[2]) })
	return out

static func _name(rng: SimRng, region: String) -> String:
	for t in 40:
		var n: String = WORDS_A[int(rng.next() * WORDS_A.size())] + " " + WORDS_B[int(rng.next() * WORDS_B.size())]
		if t > 20: n += " " + ["II", "III", "Star", "Bay"][int(rng.next() * 4)]
		if not Breeding.names.has(n):
			Breeding.names[n] = true
			return n
	return "Foreign Star %d" % Breeding.next_id

## a foreign horse rated about R for its region, best at distance d
static func make_foreign(rng: SimRng, region: String, R: float, age: int, d: int) -> Dictionary:
	var reg: Array = REGIONS[region]
	var surf: String = reg[0]
	var sex := "F" if rng.next() < 0.25 else "M"
	var A: float = float(FA[surf]) + (R - 118.0) * FB
	var h := Breeding.founder(rng, sex, A)
	Breeding.names.erase(h.name)
	h.name = _name(rng, region)
	# distance specialist: MSTN genotype and stamina–burst balance for the target trip
	var g := "CC" if d <= 1400 else ("TT" if d >= 2600 else "CT")
	h.mstn = g; h.gene = g
	var base: float = { "CC": 1350.0, "CT": 1850.0, "TT": 2400.0 }[g]
	var sb := clampf((float(d) - base) / 12.0, -30.0, 30.0)
	var avg := (float(h.stats.stamina) + float(h.stats.burst)) / 2.0
	h.stats.stamina = int(clampf(roundf(avg + sb / 2.0), 1.0, 100.0)); h.stats.burst = int(clampf(roundf(avg - sb / 2.0), 1.0, 100.0))
	var delta := A - Career.rating(h)
	for k in Breeding.PERF: h.stats[k] = int(clampf(roundf(float(h.stats[k]) + delta), 1.0, 100.0))
	h.dirt = 85 if surf == "dirt" else 12
	h["going"] = 60 if region == "EUR" else 50
	h["foreign"] = region
	h["trained"] = reg[3][int(rng.next() * reg[3].size())]
	h["age"] = age
	h["born"] = int(Career.W.year) - age
	h["jockey"] = 82
	var c := Career.new_career(h, int(h.born))
	c.starts = 3 + age * 2; c.wins = 2 + int(rng.next() * 4.0); c.cm = 30.0
	if R >= 118.0: c.graded = 1 + int(rng.next() * 3.0)
	if R >= 121.0: c.g1 = 1 + int(rng.next() * 2.0)
	c["mark"] = roundf(R); c["nRated"] = 3; c["rtMax"] = roundf(R)
	c["rtPrev"] = { "y": int(Career.W.year) - 1, "r": roundf(R), "cat": Ratings.cat(d), "surf": "D" if surf == "dirt" else "T", "race": "%s form" % reg[3][0] }
	c.last = -4.0
	h["c"] = c
	return h

## keep each region's pool topped up (start of the career, and every January for the new 3-year-olds)
static func top_up(rng: SimRng) -> void:
	var have := {}
	for h in Breeding.book.values():
		if h.has("foreign") and h.has("c") and h.c.status == "active": have[h.foreign] = int(have.get(h.foreign, 0)) + 1
	for reg in REGIONS:
		var R0: Array = REGIONS[reg]
		var need: int = int(R0[1]) - int(have.get(reg, 0))
		for i in maxi(0, need):
			# ratings: a few near the top, most well below (exponential tail under the top rating)
			var R := float(R0[2]) - 1.0 - (-log(maxf(1e-4, rng.next())) * 7.5)
			R = clampf(R, 98.0, float(R0[2]) + 2.0)
			var age := 3 if have.size() > 0 and Career.W.week <= 2 else 3 + int(rng.next() * 3.0)
			var dm: Array = R0[4]
			make_foreign(rng, reg, R, age, int(dm[int(rng.next() * dm.size())]))

## year end: foreign horses retire at 6–7 (most top horses go to stud earlier)
static func year_end(rng: SimRng) -> void:
	for h in Breeding.book.values():
		if not h.has("foreign") or not h.has("c") or h.c.status != "active": continue
		var a := int(h.age)
		if a >= 7 or (a >= 5 and rng.next() < 0.45) or (a == 4 and float(h.c.get("mark", 0)) >= 122.0 and rng.next() < 0.5):
			h.c.status = "retired"

## who may run: foreign horses in their region's races (and a few in the Japan Cup); Japanese horses abroad only
## when good enough (the AI) or entered by the player
static func eligible(h: Dictionary, r: Dictionary) -> int:
	# 1 = yes, 0 = no, -1 = use the normal JRA rules
	var f = h.get("foreign")
	if not is_intl(r):
		if f == null: return -1
		return 1 if r.name == "Japan Cup" and f in ["EUR", "USA"] and str(REGIONS[f][0]) == "turf" else 0
	if f != null: return 1 if f in r.regions else 0
	var c: Dictionary = h.c
	var m = c.get("mark")
	if Career.class_of(c) != "OP" and int(c.get("graded", 0)) == 0: return 0
	if Career._in_stable(h.id): return 1          # the player may take any open-class horse abroad
	# the AI stables only travel with horses that can compete (and that suit the trip and the surface)
	if m == null or float(m) < float(r.rr) - 8.0: return 0
	return 1 if Career.suit(h, r) > 0.35 else 0

## entry score adjustments for international races (travel is a big decision for a Japanese stable)
static func entry_bonus(h: Dictionary, r: Dictionary) -> float:
	if h.get("foreign") != null:
		if not is_intl(r): return -1.5 + Career.rng() * 2.0       # Japan Cup: a few travel
		return 2.0
	var m = h.c.get("mark")
	return (float(m) - float(r.rr)) * 0.3 if m != null else -9.0

## LONGINES World's Best Racehorse Rankings for a year: every horse rated 115+, with trained country
static func world_ranking(year: int, min_r := 115.0) -> Array:
	var out := []
	for h in Breeding.book.values():
		var yb = Ratings.year_best(h, year)
		if yb == null or float(yb.r) < min_r: continue
		var age: int = int(h.age) - (int(Career.W.year) - year)
		if age < 3: continue
		out.append({ "id": int(h.id), "name": h.name, "r": float(yb.r), "cat": yb.cat, "surf": yb.surf, "race": yb.race, "sex": h.sex, "age": age,
			"trained": str(h.get("trained", "JPN")) })
	return SimUtil.stable_sort(out, func(a, b): return b.r - a.r)

## Top 100 G1 races of a year (annual race ratings, JRA G1s and the overseas G1s together)
static func top_races(year: int) -> Array:
	var out := []
	var rr: Dictionary = Career.W.get("raceRt", {})
	for name in rr:
		for e in rr[name]:
			if int(e.y) == year and e.cls == "G1":
				var x = by_name(name)
				out.append({ "name": name, "rr": float(e.rr), "country": country_of(x[2]) if x != null else "JPN" })
	return SimUtil.stable_sort(out, func(a, b): return b.rr - a.rr)

class_name Game
extends RefCounted
## Helpers shared by the game screens: dates, horse descriptions, ratings, value, stable info.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const DAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

static var mode := ""                 # "career" or "quick"
static var pending_replay := {}        # set before switching to the 3D scene: {opts, field, name, race_id}
static var return_page := ""           # page to open when coming back from 3D
static var return_arg = null            # its argument (e.g. [race id, tab] for a race card)

## race day of a career week = the Saturday of that week
static func week_date(year: int, week: int) -> Dictionary:
	var jan1 := Time.get_unix_time_from_datetime_dict({ "year": year, "month": 1, "day": 1, "hour": 12 })
	var wd: int = Time.get_datetime_dict_from_unix_time(jan1).weekday
	var off := (6 - wd + 7) % 7
	return Time.get_datetime_dict_from_unix_time(jan1 + (off + (week - 1) * 7) * 86400)

static func date_text(year: int, week: int) -> String:
	var d := week_date(year, week)
	return "%s %d %s %d" % [DAYS[d.weekday], d.day, MONTHS[d.month - 1], d.year]

static func now_text() -> String:
	return date_text(Career.W.year, Career.W.week)

static func horse(id) -> Dictionary:
	var h = Breeding.get_horse(id)
	return h if h != null else {}

static func is_mine(h: Dictionary) -> bool:
	return Career.W.has("stable") and Career.W.stable.has(int(h.get("id", -1)))

static func sex_word(h: Dictionary) -> String:
	var age := int(h.get("age", 3))
	if h.get("sex", "M") == "F": return "mare" if age >= 5 else "filly"
	if h.get("retired", false) and h.get("c", {}).get("status", "") == "stud": return "stallion"
	return "horse" if age >= 5 else "colt"

static func summary(h: Dictionary) -> String:
	return "%dyo %s %s · %s · %s gene" % [int(h.get("age", 0)), h.get("coat", ""), sex_word(h), RaceEngine.STYLES[h.style].label, h.gene]

static var _vc := {}
static var _vk := -1

## what the stable / the public believes about a horse: stats replaced by scouting estimates (Stud.est).
## Use this for anything shown on screen; races and the world always use the real values.
static func view(h: Dictionary) -> Dictionary:
	if Stud.know(h) >= 0.96: return h
	var key := int(Career.W.get("year", 0)) * 100 + int(Career.W.get("week", 0))
	if key != _vk:
		_vc = {}
		_vk = key
	var id := int(h.id)
	if _vc.has(id): return _vc[id]
	var v := h.duplicate(false)
	v["stats"] = Stud.est_stats(h)
	v["dirt"] = Stud.est_dirt(h)
	v["grow"] = Stud.est_side(h, "grow")
	v["going"] = Stud.est_side(h, "going")
	_vc[id] = v
	return v

## current ability (0-5 stars) from the weighted rating; 50 ≈ maiden, 80 ≈ G1 (estimated, young horses not yet mature)
static func ability_stars(h: Dictionary) -> float:
	var r := Career.rating(view(h))
	var age := int(h.get("age", 3))
	if age <= 3 and h.get("c") != null and h.c.get("status", "") == "active": r *= Career.age_factor(h, int(Career.W.get("week", 1))) if age >= 2 else (0.9 if age == 1 else 0.82)
	return clampf(snappedf((r - 45.0) / 8.0, 0.5), 0.5, 5.0)

## potential (0-5 stars) from the genetic values behind the stats (what the horse could pass on / grow to)
## (estimated rating at maturity; the less is known, the more it is a guess)
static func potential_stars(h: Dictionary) -> float:
	return maxf(clampf(snappedf((Career.rating(view(h)) - 45.0) / 8.0, 0.5), 0.5, 5.0), ability_stars(h))

## estimated market value in million yen
static func value(h: Dictionary) -> float:
	var r := Career.rating(view(h))
	var age := int(h.get("age", 3))
	var c: Dictionary = h.get("c", {})
	var base := pow(maxf(0.0, r - 48.0), 2.0) * 0.09
	# a proven racehorse is valued on its official rating (career best, lb): ~¥14M at 100, ~¥75M at 120, ~¥115M at 130
	var rb := Ratings.career_best(h)
	if rb > 0.0: base = 0.35 * base + 0.65 * pow(maxf(0.0, rb - 85.0), 2.0) * 0.06
	var age_k := 1.0 if age <= 4 else (0.75 if age == 5 else (0.5 if age == 6 else 0.3))
	var fame := float(c.get("g1", 0)) * 60.0 + float(c.get("graded", 0)) * 15.0 + float(c.get("earn", 0.0)) * 0.15
	if c.get("status", "active") == "stud": return roundf(base * 1.5 + fame * 2.0)
	return maxf(1.0, roundf(base * age_k + fame * age_k))

static func money(m: float) -> String:
	if absf(m) >= 1000.0: return "¥%.2fB" % (m / 1000.0)
	return "¥%.1fM" % m

static func distance_label(h: Dictionary) -> String:
	var bd := Career.best_dist(view(h))
	if bd < 1300: return "Sprinter"
	if bd < 1700: return "Miler"
	if bd < 2100: return "Intermediate"
	if bd < 2700: return "Middle-distance horse"
	return "Stayer"

static func personality(h: Dictionary) -> String:
	var t := float(view(h).stats.temper)
	var g := float(view(h).stats.guts)
	if t >= 72 and g >= 72: return "Professional"
	if g >= 78: return "Determined"
	if t >= 75: return "Calm"
	if t <= 38: return "Hot-headed"
	if t <= 48: return "Highly strung"
	if g <= 45: return "Faint-hearted"
	return "Balanced"

static func surface_label(h: Dictionary) -> String:
	var d := int(view(h).get("dirt", 50))
	if d >= 65: return "Dirt"
	if d <= 35: return "Turf"
	return "Turf & Dirt"

## growth type from the inherited "grow" value (50 = normal; high = matures early, low = late developer)
static func growth_label(h: Dictionary) -> String:
	var g := int(view(h).get("grow", 50))
	if g >= 70: return "Very early"
	if g >= 58: return "Early"
	if g > 42: return "Normal"
	if g > 30: return "Late"
	return "Very late"

## soft/heavy-ground aptitude from the inherited "going" value (50 = average)
static func going_pref_label(h: Dictionary) -> String:
	var g := int(view(h).get("going", 50))
	if g >= 68: return "Loves soft ground"
	if g >= 56: return "Handles soft ground"
	if g > 44: return "Average on soft ground"
	if g > 32: return "Dislikes soft ground"
	return "Needs good/firm ground"

## suitability 0..1 for a distance and surface (same model the AI trainers use when choosing races)
static func suit(h: Dictionary, dist: float, dirt: bool) -> float:
	h = view(h)
	var bd := Career.best_dist(h)
	var dd: float = absf(dist - bd) / bd
	var sf: float = (float(h.get("dirt", 50)) - 50.0) / 50.0 if dirt else (50.0 - float(h.get("dirt", 50))) / 50.0
	return clampf(1.0 - dd * 2.5 + sf * 0.6, 0.0, 1.0)

## how well the stats fit each running style (0-5 stars)
static func style_fit(h: Dictionary, style: String) -> float:
	var s: Dictionary = view(h).stats
	var v := 0.0
	match style:
		"front": v = 0.35 * s.speed + 0.3 * s.accel + 0.2 * s.stamina + 0.15 * s.guts
		"stalker": v = 0.3 * s.speed + 0.25 * s.accel + 0.25 * s.stamina + 0.2 * s.agility
		"mid": v = 0.3 * s.burst + 0.25 * s.speed + 0.25 * s.stamina + 0.2 * s.temper
		"closer": v = 0.4 * s.burst + 0.25 * s.speed + 0.2 * s.temper + 0.15 * s.agility
	var st := clampf(snappedf((v - 45.0) / 8.0, 0.5), 0.5, 5.0)
	if h.style == style: st = minf(5.0, st + 0.5)      # its natural style
	return st

static func status_text(h: Dictionary) -> String:
	var c: Dictionary = h.get("c", {})
	if c.is_empty(): return "-"
	if c.status == "stud": return "At stud · %s" % money(float(Stud.stud(h).fee))
	if c.status == "broodmare":
		var r := Stud.repro(h)
		if r.due > 0: return "In foal (due %s)" % Stud._date(r.due).substr(0, 6).strip_edges()
		if r.scan > 0: return "Covered"
		return "Barren" if r.st == "barren" else ("Booked" if r.plan != null else "Open")
	if c.status != "active": return "Retired"
	if c.get("out", 0) > 0: return ("Severe injury (%d wk)" if Career.injury_level(h) == "severe" else "Injured (%d wk)") % c.out
	if int(c.get("sore", 0)) > 0 and c.get("entry") == null: return "Caution (%d wk)" % int(c.sore)
	if c.get("entry") != null: return "Entered"
	if not is_mine(h) and Planner.on_break(h): return "At the farm (%d wk)" % (int(c.breakUntil) - Planner.now())
	if not is_mine(h) and Planner.now() < int(c.get("readyW", 0)): return "Recovering"
	var a := int(h.age)
	return "Racing" if a >= 2 else ("Yearling" if a == 1 else "Foal")

## body weight now: foals grow from ~55 kg to the adult weight by about 3 years old
static func weight_now(h: Dictionary) -> int:
	var adult := float(h.get("bw", 480))
	var a := int(h.get("age", 3))
	if a >= 3: return int(adult)
	var born_w := float(h.get("birthW", 55))
	var months := float(a) * 12.0 + float(Career.W.get("week", 1)) / 4.33 - float(h.get("foaled", 10)) / 4.33
	var f := clampf(1.0 - exp(-months / 9.0), 0.0, 1.0)
	return int(born_w + (adult - born_w) * f)

## a short staff report on a young horse, from what the staff can see (estimated stats; clearer with age)
static func staff_report(h: Dictionary) -> String:
	var v := view(h)
	var s: Dictionary = v.stats
	var best := ""
	var bv := -1.0
	var worst := ""
	var wv := 999.0
	var words := { "speed": "quick", "stamina": "plenty of stamina", "accel": "nimble off the mark", "strength": "strong", "burst": "a good turn of foot",
		"guts": "brave", "agility": "well balanced", "temper": "calm and willing", "sound": "clean-legged", "wind": "breathes well" }
	var weak := { "speed": "lacks pace", "stamina": "may not stay", "accel": "slow to get going", "strength": "light-framed", "burst": "one-paced",
		"guts": "soft", "agility": "a bit clumsy", "temper": "headstrong", "sound": "watch the legs", "wind": "noisy breather" }
	for k in s:
		if float(s[k]) > bv: bv = float(s[k]); best = k
		if float(s[k]) < wv: wv = float(s[k]); worst = k
	var age := int(h.get("age", 0))
	var lead: String = ["Early days, but", "As a yearling", "In training"][clampi(age, 0, 2)]
	var g := int(v.get("grow", 50))
	var extra := " — looks forward, could run early" if g >= 62 else (" — backward type, will need time" if g <= 38 else "")
	return "%s: %s; %s%s" % [lead, words[best], weak[worst], extra]

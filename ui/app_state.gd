class_name AppState
extends RefCounted
## Shared state between screens: the current race field and race settings.

static var field: Array = []            # horse Dictionaries (with "color")
static var course := "tokyo"
static var dist := 2400
static var going := "firm"
static var runners := 16
static var seed := 1
static var injuries := true
static var eiph := true
static var _rng: SimRng = null

static func rng() -> SimRng:
	if _rng == null: _rng = SimRng.new(int(Time.get_unix_time_from_system()) & 0xFFFF)
	return _rng

static func ensure_book() -> void:
	if Breeding.stallions().is_empty() or Breeding.mares().is_empty():
		Breeding.seed_book(SimRng.new(int(Time.get_unix_time_from_system()) & 0xFFFF))

static func assign_colors() -> void:
	for i in field.size(): field[i]["color"] = UiTheme.SILKS[i % UiTheme.SILKS.size()]

## mode: "rand" = bred from the stud book, "equal" = all stats 70, "genes" = 75s with the three MSTN genes
static func build_field(mode := "rand", n := -1) -> void:
	if n > 0: runners = n
	ensure_book()
	var r := rng()
	field = []
	var st := Breeding.stallions()
	var ma := Breeding.mares()
	for i in runners:
		var h: Dictionary
		if mode == "rand":
			h = Breeding.breed(st[int(floor(r.next() * st.size()))], ma[int(floor(r.next() * ma.size()))], r)
		else:
			h = Breeding.founder(r, "M" if r.next() < 0.5 else "F", 70)
			for k in RaceEngine.STATS: h.stats[k] = 75 if mode == "genes" else 70
			h.form = 0; h.bw = 465 if h.sex == "F" else 490; h.dirt = 50
			if mode == "genes":
				var g: String = ["CC", "CT", "TT"][i % 3]
				h.mstn = g; h.gene = g
				h.name = ["Sprinter", "Miler", "Stayer"][i % 3] + " " + str(i / 3 + 1)
		h.jockey = int(SimUtil.js_round(50.0 + r.next() * 45.0)) if mode == "rand" else 75
		h.form = int(SimUtil.js_round((r.next() - 0.5) * 6.0)) if mode == "rand" else 0
		field.append(h)
	assign_colors()

static var weather_opts := {}       # optional { weather, week, hour } for the quick race (tests, a future weather picker)

static func race_opts() -> Dictionary:
	var o := { "course": course, "dist": dist, "going": going, "seed": seed, "injuries": injuries, "eiph": eiph, "risk": 1.0 }
	o.merge(weather_opts, true)
	return o

static func sex_sign(h: Dictionary) -> String:
	return "♀" if h.get("sex", "M") == "F" else "♂"

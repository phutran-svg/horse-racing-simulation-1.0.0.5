class_name RaceCommentary
extends RefCounted
## Race caller (port of the browser commentary). Call update() every few engine steps.

signal line(clock: String, text: String, important: bool)

var race: RaceEngine.Race
var lines: Array = []
var banner := ""
var banner_t := -99.0
var last_call := -99.0
var said := {}
var ev_idx := 0
var leader_i := -1
var leader_since := 0.0
var last_lead_id := -1
var kicks := 0

func reset(r: RaceEngine.Race) -> void:
	race = r
	lines = []; banner = ""; banner_t = -99.0; last_call = -99.0; said = {}; ev_idx = 0
	leader_i = -1; leader_since = 0.0; last_lead_id = -1; kicks = 0

func intro() -> String:
	var g: String = RaceEngine.going_label(race.opts.going, race.course.surface).split(" ")[0].to_lower()
	return "%d runners, %d m at %s on %s going. They're loading into the gates…" % [race.runners.size(), race.opts.dist, race.course.short, g]

func say(text: String, pri := false) -> bool:
	if not pri and race.t - last_call < 3.5: return false
	last_call = race.t
	lines.append({ "t": race.t, "text": text })
	line.emit(RaceEngine.fmt_time(RaceEngine.race_clock(race)), text, pri)
	return true

static func standings(race: RaceEngine.Race) -> Array:
	var rk := func(r) -> int: return 0 if r.state == &"fin" else (2 if r.state == &"dnf" else 1)
	return SimUtil.stable_sort(race.runners, func(a, b):
		var d: int = rk.call(a) - rk.call(b)
		if d != 0: return float(d)
		return a.finishT - b.finishT if rk.call(a) == 0 else b.dist - a.dist)

static func _nm(r) -> String: return r.h.name

static func _l2(x: float) -> String:
	if x < 0.3: return "a head"
	if x < 0.8: return "half a length"
	if x < 1.5: return "a length"
	if x < 25.0: return "%d lengths" % roundi(x)
	return "a long way"

static func spoken_margin(m: String) -> String:
	var mp := { "Dead heat": "a dead heat", "Nose": "a nose", "Head": "a head", "Neck": "a neck", "1/2": "half a length", "3/4": "three-quarters of a length", "Distance": "a distance" }
	if mp.has(m): return mp[m]
	var parts := m.split(" ")
	var fx := ""
	if parts.size() > 1: fx = { "1/4": " and a quarter", "1/2": " and a half", "3/4": " and three-quarters" }.get(parts[1], "")
	if parts[0] == "1" and fx == "": return "a length"
	return parts[0] + fx + " lengths"

static func _par1000(d: int) -> float:
	if d <= 1400: return 57.5
	if d <= 1800: return 58.5
	if d <= 2200: return 59.5
	if d <= 2600: return 60.5
	return 62.0

func _once(k: String, f: Callable) -> void:
	if said.has(k): return
	if f.call() != false: said[k] = true

func update() -> void:
	var T: Dictionary = race.course
	var D: int = race.opts.dist
	var st: Array = standings(race).filter(func(r): return r.state != &"dnf" and r.state != &"pulling")
	if st.is_empty() or race.t < 0.3: return
	var L = st[0]
	var rem: float = D - L.dist
	var len_behind := func(a, b) -> float: return (a.dist - b.dist) / 2.4
	# engine events (injury, EIPH, bad breaks, pulling, bumps)
	while ev_idx < race.events.size():
		var e: Dictionary = race.events[ev_idx]
		ev_idx += 1
		var m: String = e.msg
		if e.get("type", "") == "bump":
			var ab := m.split(" bumped by ")
			say("%s takes a bump from %s!" % [ab[0], ab[1]], false)
			continue
		var who := m.split(":")[0]
		if m.contains("missed the break"): say("%s misses the break and is slowly away!" % m.replace(" missed the break", ""), true)
		elif m.contains("pulled up"): say("Oh no — %s is being pulled up! %s" % [who, "Blood from the nostrils, a severe bleed." if m.contains("epistaxis") else "Looks like an injury."], true)
		elif m.contains("eased"): say("%s looks in trouble — the jockey is easing off." % who, true)
		elif m.contains("pulling hard"): say("%s is pulling hard, fighting for its head." % who, false)
		elif m.contains("EIPH"):
			var gi := m.find("grade ")
			if gi >= 0 and int(m.substr(gi + 6, 1)) >= 2: say("%s seems to be struggling for air." % who, false)
	_once("off", func(): return race.t > 0.6 and say("And they're off on the dirt!" if T.surface == "dirt" else "And they're off!", true))
	_once("early", func():
		if L.dist <= 250: return false
		return say("%s goes to the front.%s%s" % [_nm(L), " %s second" % _nm(st[1]) if st.size() > 1 else "", ", %s third." % _nm(st[2]) if st.size() > 2 else "."], true))
	# leader changes
	if leader_i != L.i:
		leader_i = L.i; leader_since = race.t
	if race.t - leader_since > 1.0 and last_lead_id != L.i and L.dist > 300 and rem > 0:
		last_lead_id = L.i
		if said.has("early"): say("%s hits the front!" % _nm(L) if rem < 600 else "%s takes over the lead." % _nm(L), rem < 600)
	# pace at 1000 m
	_once("pace", func():
		if D < 1600 or L.dist < 1000: return false
		var s = null
		for x in L.splits:
			if absf(x.m - 1000) < 1: s = x
		if s == null:
			for x in L.splits:
				if x.m <= 1000: s = x
		if s == null: return false
		var t1000: float = s.t * 1000.0 / s.m
		var par := _par1000(D) * (1.035 if T.surface == "dirt" else 1.0)
		var pace := "a fast pace" if t1000 < par - 1.0 else ("a slow pace — this will turn into a sprint" if t1000 > par + 1.5 else "a sensible pace")
		return say("The first 1000 m in %.1f seconds — %s." % [t1000, pace], true))
	# running order calls
	if said.has("early") and rem > 700 and race.t - last_call > 14.0 and st.size() > 3:
		var last = st[st.size() - 1]
		say("%s leads by %s from %s, then %s. %s is last, %s off the lead." % [_nm(st[0]), _l2(len_behind.call(st[0], st[1])), _nm(st[1]), _nm(st[2]), _nm(last), _l2(len_behind.call(L, last))])
	# final turn & straight
	var sL := RaceEngine.wrap_s(race.startS + L.dist)
	var in_straight: bool = sL < T.finish + 1.0 and rem <= T.finish + 1.0
	_once("turn", func():
		if T.straight: return false
		if not (rem < T.finish + (T.C - T.curves[1][0]) and not in_straight): return false
		return say("Round the final turn — the field is closing up!", true))
	_once("straight", func(): return in_straight and say("Into the straight at %s, %d metres to go! %s still in front." % [T.short, roundi(rem), _nm(L)], true))
	# moves
	if kicks < 3:
		for r in st.slice(2):
			if r.driving_started and not said.has("k%d" % r.i) and rem < 900 and r.v > L.v + 0.4:
				said["k%d" % r.i] = true; kicks += 1
				say("%s makes a move %s!" % [_nm(r), "down the outside" if r.lane > 4.0 else "through the field"], false)
				break
	_once("slope", func():
		if not (rem < 700 and RaceEngine.grade(sL) > 0.008): return false
		return say("Up %s! This is where they find out who has stamina left." % T.slope, true))
	_once("200", func():
		if rem > 200 or st.size() < 2: return false
		var cl = st[1]
		for r in st.slice(1, 6):
			if r.v > cl.v: cl = r
		var tail := "!"
		if cl != st[1] and cl.v > L.v: tail = ", and %s flying home!" % _nm(cl)
		return say("200 to go! %s from %s%s" % [_nm(L), _nm(st[1]), tail], true))
	_once("duel", func():
		if rem > 120 or st.size() < 2 or len_behind.call(L, st[1]) > 0.6: return false
		return say("%s and %s — neck and neck!" % [_nm(L), _nm(st[1])], true))
	_once("fin", func():
		if race.order.is_empty(): return false
		var w = race.order[0]
		for x in race.order:
			if x.finishT < w.finishT: w = x
		if race.order.size() < mini(3, race.runners.size()) and race.t - w.finishT < 4.0 and not race.done: return false
		var res: Array = RaceEngine.results(race).rows
		var s2 = res[1] if res.size() > 1 and res[1].pos > 0 else null
		var photo: bool = s2 != null and s2.margin in ["Nose", "Head", "Dead heat"]
		banner = "🏆 %s  %s" % [_nm(w), RaceEngine.fmt_time(w.finishT)]
		banner_t = race.t
		var txt := "%s%s wins" % ["It's a photo… " if photo else "", _nm(w)]
		if s2 != null: txt += " by %s from %s" % [spoken_margin(s2.margin), s2.name]
		if res.size() > 2 and res[2].pos > 0: txt += ", %s third" % res[2].name
		return say(txt + "! Time %s." % RaceEngine.fmt_time(w.finishT), true))

class_name Planner
## How CPU trainers and owners plan a horse's racing (the player decides for their own horses).
## Based on real JRA practice:
##  * JRA 2020: 3yo+ flat horses averaged ~4.7 starts a year, 2yo ~2.5 (JRA & NAR Statistics).
##  * Lower-class horses often run every 2–4 weeks (中1週–中3週 is common); graded horses space their races
##    and often come back from 2–6 month breaks (JRA-VAN: graded winners from 中9–24週 breaks do best).
##  * After a campaign, a big race or for the summer, horses go to the farm for a freshening break (放牧) and
##    return to the training centre a few weeks before their next run.
## Decisions: recovery time after each race, farm breaks, a fitness/fatigue/mood check before entering, and
## keeping good horses fresh for an upcoming G1 they can win.

const BASE := { "NEW": 2, "MDN": 2, "1W": 3, "2W": 3, "3W": 4, "OP": 4, "L": 4, "G3": 5, "G2": 6, "G1": 8 }
const GRADED := ["G1", "G2", "G3"]

static var W: Dictionary:
	get: return Career.W

static func now() -> int:
	return int(W.year) * 52 + int(W.week)

## after a race: when the horse can run again, and whether it goes to the farm for a break
static func after_race(h: Dictionary, r: Dictionary, pos: int, field_n: int) -> void:
	var c: Dictionary = h.c
	var cls: String = String(r.get("cls", "1W"))
	var wk: int = int(BASE.get(cls, 3))
	var dist := int(r.dist)
	if dist >= 2400: wk += 1
	if dist >= 3000: wk += 1
	if int(h.age) == 2: wk += 1                                         # young horses need more time
	if cls in GRADED and pos >= 1 and pos <= 3: wk += 1                  # a hard, successful effort takes more out of them
	if Intl.is_intl(r): wk += 3                                          # travel and quarantine
	wk += int(round(Career.gauss() * 0.8))
	wk = maxi(2, wk)
	if Career.rng() < 0.015 and not cls in GRADED: wk = 1                # the odd quick turnaround (連闘)
	c["readyW"] = now() + wk
	c["runs"] = int(c.get("runs", 0)) + 1
	# farm break: grows with the number of runs since the last one; big races and the summer make it likelier
	var p := 0.04 + 0.09 * maxf(0.0, float(c.runs) - 2.0)
	if cls == "G1": p += 0.40
	elif cls in GRADED: p += 0.12
	var top: bool = cls in GRADED or float(c.get("mark", 0.0)) >= 100.0
	var wn := int(W.week)
	if top and wn >= 24 and wn <= 31: p += 0.45                          # top horses summer at the farm, back for the autumn
	if int(h.age) == 2 and wn >= 46: p += 0.35                           # 2yos rest over the winter before their classic year
	if Career.rng() < clampf(p, 0.0, 0.9):
		var len := 8 + int(floor(Career.rng() * (10.0 if not top else 12.0)))
		if top and wn >= 24 and wn <= 31: len = maxi(len, 36 - wn)       # summer: back in September
		var g1w := next_g1(h, 5, 30)                                      # G1-class horse: back in time for its next G1
		if g1w > 0 and len > g1w - 3: len = maxi(4, g1w - 3)
		c["breakUntil"] = now() + len
		c["runs"] = 0
		if cls in GRADED: Career.log_msg("%s goes to the farm for a break (放牧) and is expected back in about %d weeks." % [h.name, len], h)

static func on_break(h: Dictionary) -> bool:
	return now() < int(h.c.get("breakUntil", 0))

## fit, fresh and recovered? (trainers with better race planning wait for the horse to peak)
static func ready(h: Dictionary) -> bool:
	var c: Dictionary = h.c
	if now() < int(c.get("readyW", 0)) or on_break(h): return false
	var plan := Training.trainer_attr(h, "plan")
	var need_fit := 0.74 + 0.04 * clampf((plan - 55.0) / 25.0, -1.0, 1.0)
	if float(c.get("fit", 1.0)) < need_fit: return false
	if float(c.get("fat", 0.0)) > 0.55: return false
	if float(c.get("mood", 60.0)) < 35.0: return false
	return true

## for a G1 the horse is good enough to run in: the trainer brings it back from the farm up to 4 weeks early,
## and runs it slightly short of a peak (it still has to be sound, recovered from its last race and not sour)
static func ready_for_g1(h: Dictionary) -> bool:
	var c: Dictionary = h.c
	# top horses go G1 to G1 four weeks apart (Tenno Sho Autumn → Japan Cup → Arima Kinen)
	if now() < int(c.get("readyW", 0)) and Career.since(h) < 4.0: return false
	if on_break(h) and int(c.get("breakUntil", 0)) - now() > 5: return false
	if float(c.get("fit", 1.0)) < 0.68: return false
	if float(c.get("fat", 0.0)) > 0.7: return false
	if float(c.get("mood", 60.0)) < 28.0: return false
	return true

## a good horse with a suitable G1 in 2–6 weeks skips lesser races (stays fresh for the target)
static func saving_for(h: Dictionary, r: Dictionary) -> bool:
	if r.get("cls", "") == "G1": return false
	var mk := float(h.c.get("mark", 0.0))
	if mk < 100.0: return false
	var bd := Career.best_dist(h)
	for g in Career.GRADED:
		if g[1] != "G1": continue
		var dw := int(g[2]) - int(W.week)
		if dw < 2 or dw > 6: continue
		if String(g[6]) == "F" and h.sex != "F": continue
		var ag := String(g[5])
		if ag == "2" and int(h.age) != 2: continue
		if ag == "3" and int(h.age) != 3: continue
		if ag.contains("+") and int(h.age) < int(ag.substr(0, 1)): continue
		var C = RaceEngine.COURSES.get(g[3])
		if C == null: continue
		var dirt: bool = C.surface == "dirt"
		if dirt and float(h.dirt) < 50.0: continue
		if not dirt and float(h.dirt) > 60.0: continue
		if absf(float(g[4]) - bd) / bd > 0.18: continue
		if mk >= Ratings.grade_par("G1", String(g[6]) == "F", ag) - 8.0: return true
	return false

## weeks until the next G1 that suits a horse rated near G1 level (within lo..hi weeks; 0 = none)
static func next_g1(h: Dictionary, lo: int, hi: int) -> int:
	var mk = h.c.get("mark")
	if mk == null: return 0
	var bd := Career.best_dist(h)
	var best := 0
	for g in Career.GRADED:
		if g[1] != "G1": continue
		var dw := (int(g[2]) - int(W.week) + 52) % 52
		if dw < lo or dw > hi or (best > 0 and dw >= best): continue
		if String(g[6]) == "F" and h.sex != "F": continue
		var ag := String(g[5])
		var age_then := int(h.age) + (1 if int(g[2]) < int(W.week) else 0)
		if ag == "2" and age_then != 2: continue
		if ag == "3" and age_then != 3: continue
		if ag.contains("+") and age_then < int(ag.substr(0, 1)): continue
		var C = RaceEngine.COURSES.get(g[3])
		if C == null: continue
		var dirt: bool = C.surface == "dirt"
		if dirt and float(h.dirt) < 50.0: continue
		if not dirt and float(h.dirt) > 60.0: continue
		if absf(float(g[4]) - bd) / bd > 0.18: continue
		if float(mk) < Ratings.grade_par("G1", String(g[6]) == "F", ag) - 8.0: continue
		best = dw
	return best

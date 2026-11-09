class_name Training
## Step 4B — weekly training. Each horse has a plan for the week: a work type and an intensity
## (JRA terms: 馬なり easy / 強め firm / 一杯 all-out). Training changes fitness, fatigue, mood, body weight,
## gate manners and injury risk. The trainer's skill scales the fitness gain and lowers the injury risk.
## Workout reports look like JRA ones: centre, course, time for the last 4 furlongs (800 m) and the last furlong.
##
## Work types: [label, Japanese, load, injury ×, mood/week, body weight kg/week, fitness efficiency]
const WORKS := {
	"rest": ["Rest (box rest / paddock)", "休養", 0.0, 0.0, 3.0, 1.2, 0.0],
	"walk": ["Walking / light exercise", "引き運動", 0.25, 0.35, 1.5, 0.5, 0.8],
	"canter": ["Canter", "キャンター", 0.5, 0.75, 0.5, 0.0, 1.0],
	"woodchip": ["Woodchip course", "ウッドチップ", 0.7, 0.85, 0.0, -0.3, 1.0],
	"slope": ["Uphill (hanro)", "坂路", 0.8, 0.95, -0.5, -0.5, 1.12],
	"turf": ["Turf course", "芝", 0.75, 1.1, 0.0, -0.3, 1.0],
	"dirt": ["Dirt course", "ダート", 0.7, 1.0, 0.0, -0.3, 1.0],
	"poly": ["Polytrack", "ポリトラック", 0.7, 0.8, 0.0, -0.3, 1.0],
	"pool": ["Swimming pool", "プール", 0.5, 0.3, 1.0, -0.2, 0.9],
	"gate": ["Gate practice", "ゲート練習", 0.2, 0.3, -0.5, 0.0, 0.6],
}
## intensity: [label, Japanese, load ×, injury ×, mood]
const INTENSITY := {
	"easy": ["Easy (hands and heels)", "馬なり", 0.8, 0.8, 0.5],
	"firm": ["Firm", "強め", 1.0, 1.0, 0.0],
	"hard": ["All-out (fast work)", "一杯", 1.3, 1.6, -1.5],
}
const ORDER := ["rest", "walk", "canter", "woodchip", "slope", "turf", "dirt", "poly", "pool", "gate"]

static func plan(h: Dictionary) -> Dictionary:
	var c: Dictionary = h.c
	if not c.has("plan"): c["plan"] = { "mode": "auto", "work": "woodchip", "int": "firm" }
	return c.plan

static func set_plan(h: Dictionary, mode: String, work := "", inten := "") -> void:
	var p := plan(h)
	p.mode = mode
	if work != "": p.work = work
	if inten != "": p.int = inten

static func trainer_skill(h: Dictionary) -> float:
	var c: Dictionary = h.get("c", {})
	if Career._in_stable(h.id) and Profile.licensed_trainer():
		var s: Dictionary = Profile.P().skills
		return (float(s.horse) + float(s.know)) / 2.0
	var t := People.trainer(c.get("trainer"))
	return float(t.get("skill", 55.0))

## one trainer attribute (cond / care / young / plan). A player who trains uses their own skills.
static func trainer_attr(h: Dictionary, key: String) -> float:
	var c: Dictionary = h.get("c", {})
	if Career._in_stable(h.id) and Profile.licensed_trainer():
		var s: Dictionary = Profile.P().skills
		return { "cond": float(s.horse) * 0.5 + float(s.know) * 0.5, "care": float(s.horse), "young": float(s.riding) * 0.5 + float(s.horse) * 0.5, "plan": float(s.know) }.get(key, trainer_skill(h))
	var t := People.trainer(c.get("trainer"))
	if t.is_empty(): return 55.0
	return float(People.tattr(t).get(key, t.skill))

## what the trainer would do this week (used for "Leave it to the trainer" and for every AI horse)
static func auto(h: Dictionary) -> Array:   # [work, intensity]
	var c: Dictionary = h.c
	if not Career._in_stable(h.id) and Planner.on_break(h): return ["walk", "easy"]      # at the farm (放牧): turned out, light exercise
	var since := int(W_week()) - int(c.get("last", -99)) if int(c.get("lastY", 0)) == int(Career.W.year) else 99
	var entered = c.get("entry")
	if float(c.fat) > 0.9: return ["walk", "easy"]
	if since <= 1: return ["walk", "easy"]                    # the week after a race
	if float(c.fat) > 0.6: return ["canter", "easy"]
	if entered != null: return ["slope" if (int(h.id) + int(W_week())) % 2 == 0 else "woodchip", "hard"]   # final fast work before the race
	if int(c.get("starts", 0)) == 0 and int(c.get("gate", 50)) < 60 and int(W_week()) % 3 == 0: return ["gate", "firm"]
	return ["slope" if (int(h.id) * 7 + int(W_week())) % 2 == 0 else "woodchip", "firm"]

static func W_week() -> int: return int(Career.W.week)

## one week of training for an active horse (called for every horse by Career.advance_week)
static func week(h: Dictionary) -> void:
	var c: Dictionary = h.c
	if c.status != "active": return
	if not c.has("mood"): c["mood"] = 60.0
	if not c.has("gate"): c["gate"] = 50
	if not c.has("bw0"): c["bw0"] = int(h.get("bw", 480))
	if c.out > 0:
		c.out -= 1; c.fit += (0.5 - c.fit) * 0.06; c.fat *= 0.5
		c.mood = minf(80.0, float(c.mood) + 0.5)
		if c.out == 0: Career.back_from_injury(h)
		return
	var sore := int(c.get("sore", 0))
	if sore > 0: c["sore"] = sore - 1
	var wk: Array
	var p := plan(h)
	if Career._in_stable(h.id) and p.mode == "manual": wk = [p.work, p.int]
	else: wk = auto(h)
	if int(h.age) < 2: wk = ["walk", "easy"]
	var w: Array = WORKS[wk[0]]
	var it: Array = INTENSITY[wk[1]]
	var tcond := trainer_attr(h, "cond")
	if int(h.age) <= 3: tcond = (tcond + trainer_attr(h, "young")) / 2.0      # bringing on 2- and 3-year-olds is its own skill
	var tcare := trainer_attr(h, "care")
	var ld: float = float(w[2]) * float(it[2])
	var eff: float = float(w[6]) * (0.9 + 0.2 * tcond / 100.0)
	var target := 0.55 + 0.45 * minf(1.0, ld * eff)
	if ld <= 0.0: target = c.fit       # rest keeps most fitness for a week or two, then detrains slowly
	c.fit += (target - c.fit) * (0.22 if target > c.fit else 0.04)
	c.fat = c.fat * 0.62 + ld * 0.12
	# mood: rest and swimming lift it, a run of hard weeks wears it down; slowly returns towards 60
	c.mood = clampf(float(c.mood) + float(w[4]) + float(it[4]) + (60.0 - float(c.mood)) * 0.08 - maxf(0.0, float(c.fat) - 0.7) * 6.0, 10.0, 100.0)
	# race planning: a good planner has the horse peaking for its race (mood lift in race week), a poor one misses it
	if c.get("entry") != null: c.mood = clampf(float(c.mood) + (trainer_attr(h, "plan") - 55.0) * 0.12, 10.0, 100.0)
	# body weight: hard work takes it off, rest puts it on (within ±15 kg of the horse's racing weight)
	# (shown as the horse's weight now; the race engine keeps the horse's frame weight, and being more than 10 kg
	#  away from the racing weight costs form instead)
	var now := float(c.get("bwNow", c.bw0))
	var dw: float = { "rest": 1.2, "walk": 0.5, "pool": 0.0, "gate": 0.0, "canter": 0.2 }.get(wk[0], 0.0) + { "easy": 0.2, "firm": 0.0, "hard": -0.8 }[wk[1]]
	c["bwNow"] = int(round(clampf(now + dw + (float(c.bw0) - now) * 0.08, float(c.bw0) - 18.0, float(c.bw0) + 18.0)))
	if wk[0] == "gate": c.gate = mini(100, int(c.gate) + 6)
	# injury risk (same scale as before, × work type × intensity, better trainers spot trouble earlier)
	var haz: float = 0.0015 * ld * ld * (1.6 - h.stats.sound / 100.0) * (1.0 + 2.0 * c.fat) * float(w[3]) * float(it[3]) * (1.4 if h.age >= 7 else 1.0) * (1.15 - 0.3 * tcare / 100.0)
	c.train = { "rest": "rest", "walk": "light", "pool": "light", "gate": "light" }.get(wk[0], "hard" if wk[1] == "hard" else "normal")
	c.work = "hill" if wk[0] == "slope" else String(wk[0])
	c["lastWork"] = [wk[0], wk[1]]
	if Career._in_stable(h.id) and ld > 0.3: _report(h, wk)
	if sore > 0: haz *= 1.6                 # still sore: hard work can turn it into a real injury
	# one draw: a real injury, or a knock / heat in a leg that puts the horse on caution for a week or three
	var u := Career.rng()
	if u < haz: Career.injure(h, "training")
	elif u < haz * 2.2 and int(c.get("sore", 0)) == 0:
		c["sore"] = 1 + int(floor(Career.rng() * 3.0))
		if Career._in_stable(h.id): Career.log_msg("%s has some heat in a leg after work: on caution for %d weeks." % [h.name, int(c.sore)], h)

## race-day form from mood: −1 % … +1 %
static func form(h: Dictionary) -> int:
	var c: Dictionary = h.get("c", {})
	var m := float(c.get("mood", 60.0))
	var f := int(round(clampf((m - 60.0) / 30.0, -1.0, 1.0)))
	if absf(float(c.get("bwNow", c.get("bw0", 0))) - float(c.get("bw0", 0))) > 10.0: f -= 1     # too heavy or too light
	return clampi(f, -1, 1)

static func mood_text(m: float) -> String:
	if m >= 80: return "Very keen"
	if m >= 67: return "Bright"
	if m >= 50: return "Settled"
	if m >= 35: return "Flat"
	return "Sour"

## JRA-style workout line for the player's horses
static func _report(h: Dictionary, wk: Array) -> void:
	var c: Dictionary = h.c
	var centre := "Ritto"
	if Profile.role() == "trainer": centre = Profile.center_name()
	else:
		var t := People.trainer(c.get("trainer"))
		if not t.is_empty(): centre = "Miho" if t.centre == "miho" else "Ritto"
	var sp := float(h.stats.speed) * 0.5 + float(h.stats.accel) * 0.25 + float(h.stats.stamina) * 0.25
	var base: float = { "slope": 53.5, "woodchip": 53.0, "turf": 51.5, "dirt": 54.0, "poly": 52.0, "canter": 58.0 }.get(wk[0], 0.0)
	if base == 0.0: return
	var k: float = { "easy": 1.5, "firm": 0.0, "hard": -1.6 }[wk[1]]
	var t4: float = base + k - (sp - 70.0) * 0.06 - (float(c.fit) - 0.8) * 3.0 + Career.gauss() * 0.4
	var t1: float = 12.4 + k * 0.25 - (sp - 70.0) * 0.012 + Career.gauss() * 0.15
	if not c.has("works"): c["works"] = []
	c.works.insert(0, { "y": Career.W.year, "w": Career.W.week, "txt": "%s %s 4F %.1f – 1F %.1f (%s)" % [centre, WORKS[wk[0]][0].split(" (")[0], t4, t1, INTENSITY[wk[1]][1]] })
	if c.works.size() > 8: c.works.resize(8)

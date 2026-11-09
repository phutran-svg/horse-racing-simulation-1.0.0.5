class_name Profile
## Step 4A — who the player is: Trainer, Owner or Breeder (Japan for now), their licences and career path.
## W.player holds everything (saved with the world). See claude/step4-plan.md for the real rules behind it:
##  * JRA trainer licence exam: 28 or older on exam day; few pass (7–9 a year; many need 3–6 tries);
##    first stage written + physical, second stage interview; results in December; licence from 1 March.
##  * A JRA trainer rents about 20 boxes on average, employs about 12 staff; they can't own racehorses.
##  * JRA trainers retire at 70.
##  * Owners need a licence (JRA: income ≥ ¥20M two years running, assets ≥ ¥100M).

const COUNTRIES := [["JPN", "Japan", true], ["USA", "United States", false], ["GB", "United Kingdom", false],
	["FR", "France", false], ["HK", "Hong Kong", false], ["UAE", "United Arab Emirates", false]]
const ROLES := {
	"trainer": ["Trainer", "Run a stable at Miho or Ritto. Owners send you their horses; you plan training, choose races and jockeys, and earn 10% of the prize money plus training fees. Trainers can't own racehorses."],
	"owner": ["Owner", "Own racehorses. Buy them, choose their trainer, pay the monthly training fees and collect 80% of the prize money. You can also keep broodmares or buy a farm later."],
	"breeder": ["Breeder", "Run a breeding farm in Hidaka. Choose stallions for your mares, raise foals and sell them; earn breeder prizes when horses you bred win. Get an owner licence to race your own."],
}
const DIFF := {
	"easy": { "owner": [1000.0, 60.0], "breeder": [400.0, 8, 120.0], "trainer": [60.0, 16], "young": 3.0, "label": "Easy" },
	"normal": { "owner": [300.0, 30.0], "breeder": [150.0, 5, 80.0], "trainer": [25.0, 12], "young": 1.5, "label": "Normal" },
	"hard": { "owner": [130.0, 22.0], "breeder": [60.0, 3, 50.0], "trainer": [10.0, 8], "young": 0.5, "label": "Hard" },
}
const RETIRE_AGE := 70
const EXAM_AGE := 28
const EXAM_APPLY_WEEK := 36    # applications in September
const EXAM_W1 := 42            # first stage (written + physical), October
const EXAM_W2 := 46            # second stage (interview), November
const EXAM_RESULT := 49        # results announced in December; licence from 1 March
const LICENCE_WEEK := 9
const EXAM_MARK1 := 64.0       # written: knowledge (racing law, horse science) and horsemanship
const EXAM_MARK2 := 58.0       # interview: practical skill and how people in racing see you
const SCHOOL_WEEKS := 26       # JRA Horse Racing School stable-staff course (about six months)
const BOX_MIN := 8
const BOX_MAX := 28
const OFFER_WEEKS := [6, 16, 28, 36, 44]
const FOCUS := { "care": "Horse care", "riding": "Riding work", "study": "Study for the exam", "balanced": "Balanced" }

const SURNAMES := ["Tanaka", "Suzuki", "Sato", "Takahashi", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida", "Yamada",
	"Sasaki", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Yamaguchi", "Mori", "Ikeda", "Hashimoto", "Ishikawa", "Ogawa", "Okada",
	"Fujita", "Goto", "Hasegawa", "Murakami", "Kondo", "Sakamoto", "Endo", "Aoki", "Fujii", "Nishimura", "Fukuda", "Ota", "Miura", "Okamoto", "Matsuda"]
const GIVEN := ["Hiroshi", "Takashi", "Kenji", "Makoto", "Satoshi", "Kazuo", "Yuki", "Naoko", "Akira", "Masato", "Keiko", "Tetsuya", "Shinji", "Emi", "Daisuke", "Ryo"]

static var W: Dictionary:
	get: return Career.W

static func P() -> Dictionary: return W.get("player", {})
static func age() -> int: return int(W.year) - int(P().get("born", int(W.year) - 30))
static func role() -> String: return String(P().get("role", "owner"))
static func can_own() -> bool:
	var p := P()
	return p.get("ownerLic", "") != "" and role() != "trainer"
static func licensed_trainer() -> bool: return role() == "trainer" and P().get("licensed", false)
static func is_young_trainer() -> bool: return role() == "trainer" and not P().get("licensed", false)

static func _r() -> float: return Career.rng()

static func ai_owner_name(seed_v: int) -> String:
	var s: String = SURNAMES[absi(seed_v * 7) % SURNAMES.size()]
	var g: String = GIVEN[absi(seed_v * 13 + 5) % GIVEN.size()]
	return "%s %s" % [g, s]

## ---------- new game ----------
## opts: role, bg ("young"/"pro"), diff, name, stable_name, silk, center ("miho"/"ritto"), age, package (owner)
static func create(opts: Dictionary) -> void:
	var rl := String(opts.get("role", "owner"))
	var diff: Dictionary = DIFF[String(opts.get("diff", "normal"))]
	var start_age := int(opts.get("age", 20)) if opts.get("bg", "") == "young" and rl == "trainer" else 40
	var p := {
		"role": rl, "country": "JPN", "bg": String(opts.get("bg", "pro")), "diff": String(opts.get("diff", "normal")),
		"name": String(opts.get("name", "Player")), "born": int(W.year) - start_age, "center": String(opts.get("center", "miho")),
		"licensed": false, "job": rl, "skills": { "horse": 30.0, "riding": 30.0, "know": 30.0, "business": 30.0 }, "rep": 20.0,
		"boxes": 0, "focus": "balanced", "care": [], "employer": "", "exams": [], "debt": 0.0, "business": 0.0,
		"farm": false, "farmValue": 0.0, "ownerLic": "", "offers": [], "over": false, "examApply": true, "jobSince": int(W.year),
		"history": [],
	}
	W["player"] = p
	W["money"] = 0.0
	W["ledger"] = []
	W["finYear"] = {}
	match rl:
		"owner":
			p.ownerLic = "jra"
			p.business = float(diff.owner[1])
			Career.ledger("Starting funds", float(diff.owner[0]), "capital")
			Career.ledger("JRA owner registration and tax", -0.1, "licence")
		"breeder":
			p.farm = true
			p.farmValue = float(diff.breeder[2])
			Career.ledger("Starting funds", float(diff.breeder[0]), "capital")
		"trainer":
			if p.bg == "young":
				p.job = "student"
				p.skills = { "horse": 18.0, "riding": 22.0, "know": 15.0, "business": 10.0 }
				p.rep = 0.0
				Career.ledger("Savings", float(diff.young), "capital")
				p.employer = "JRA Horse Racing School"
				_hist("Entered the JRA Horse Racing School (stable-staff course)")
			else:
				p.licensed = true
				p.job = "trainer"
				p.boxes = int(diff.trainer[1])
				p.skills = { "horse": 62.0, "riding": 55.0, "know": 70.0, "business": 50.0 }
				p.rep = 30.0
				Career.ledger("Savings and stable working capital", float(diff.trainer[0]), "capital")
				_hist("Opened a stable at %s with %d boxes" % [center_name(), p.boxes])

static func center_name() -> String:
	return "Miho" if P().get("center", "miho") == "miho" else "Ritto"

static func _hist(t: String) -> void:
	P().history.insert(0, { "y": W.year, "w": W.week, "t": t })

## a new licensed trainer's first horses: modest horses from owners who try a new stable
static func fill_new_yard(rng: SimRng) -> void:
	var p := P()
	var want := int(round(p.boxes * 0.75))
	var pool: Array = Career.active().filter(func(h): return int(h.age) >= 2 and int(h.age) <= 5 and not Career._in_stable(h.id) and not h.has("foreign") and int(h.c.get("out", 0)) == 0)
	pool.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
	var lo := int(pool.size() * 0.45)
	var hi := int(pool.size() * 0.9)
	for i in want:
		if hi <= lo: break
		var h: Dictionary = pool[lo + int(floor(rng.next() * (hi - lo)))]
		if Career._in_stable(h.id): continue
		_take_horse(h, ai_owner_name(int(h.id)))

static func _take_horse(h: Dictionary, owner: String) -> void:
	Career.add_to_stable(int(h.id))
	h.c["owner"] = owner
	h.c["joined"] = [int(W.year), int(W.week)]

## ---------- weekly ----------
static func week_tick() -> void:
	var p := P()
	if p.is_empty() or p.get("over", false): return
	match role():
		"trainer":
			if p.licensed: _trainer_week()
			else: _young_week()
		_:
			# owners' and breeders' horses go to a trainer when they start pre-training (yearlings) — the stable can be changed on the horse's Training tab
			for id in W.stable:
				var h = Breeding.get_horse(id)
				if h != null and h.c.status == "active" and int(h.age) >= 1: People.ensure_trainer(h)
	if age() >= RETIRE_AGE and licensed_trainer() and not p.get("retiredOut", false):
		p["retiredOut"] = true
		Career.log_msg("You have reached %d, the JRA retirement age for trainers. Your stable closes at the end of this season." % RETIRE_AGE, null)

static func _grow(k: String, rate: float) -> void:
	var s: Dictionary = P().skills
	s[k] = minf(100.0, float(s[k]) + rate * (1.0 - float(s[k]) / 110.0))

## youngster: racing school → groom → assistant trainer → exam
static func _young_week() -> void:
	var p := P()
	var f := String(p.focus)
	var mult := 1.0 if p.job != "student" else 1.3
	match f:
		"care": _grow("horse", 0.3 * mult); p.rep = minf(100.0, p.rep + 0.04)
		"riding": _grow("riding", 0.3 * mult)
		"study": _grow("know", 0.45 * mult)
		_: _grow("horse", 0.125 * mult); _grow("riding", 0.125 * mult); _grow("know", 0.175 * mult)
	if p.job != "student": _grow("business", 0.05)
	if p.job == "assistant": p.rep = minf(100.0, p.rep + 0.06)     # riding work every morning: trainers and owners get to know you
	var w := int(W.week)
	if p.job == "student" and (int(W.year) - int(p.jobSince)) * 52 + w >= SCHOOL_WEEKS + 1:
		p.job = "groom"
		p.jobSince = int(W.year)
		var sn: String = SURNAMES[absi(int(W.year) * 31 + 7) % SURNAMES.size()]
		p.employer = "%s stable (%s)" % [sn, center_name()]
		_hist("Graduated from the Racing School; hired as a groom at the %s" % p.employer)
		Career.log_msg("You graduated from the Racing School and start as a groom (厩務員) at the %s. You look after two horses." % p.employer, null)
	if p.job in ["groom", "assistant"]: _keep_care()
	if p.job == "groom" and float(p.skills.riding) >= 50.0 and int(W.year) - int(p.jobSince) >= 2 and w == 1:
		p.job = "assistant"
		p.jobSince = int(W.year)
		_hist("Promoted to assistant trainer (調教助手) at the %s" % p.employer)
		Career.log_msg("Promotion: you are now an assistant trainer (調教助手). You ride work every morning.", null)
	# the horses in your care: their wins build your name
	if not W.get("lastWeek", {}).is_empty():
		for r in W.lastWeek.get("races", []):
			if r.get("result", []).is_empty(): continue
			var win := int(r.result[0].id)
			if p.care.has(win):
				p.rep = minf(100.0, p.rep + (5.0 if r.cls in ["G1", "G2", "G3"] else 2.0))
	p.rep = maxf(0.0, p.rep - 0.01)
	_exam_calendar()

## the two horses a groom looks after
static func _keep_care() -> void:
	var p := P()
	var keep: Array = []
	for id in p.care:
		var h = Breeding.get_horse(id)
		if h != null and h.c.status == "active": keep.append(int(id))
	if keep.size() < 2:
		var pool: Array = Career.active().filter(func(h): return int(h.age) in [2, 3] and not keep.has(int(h.id)) and not h.has("foreign"))
		while keep.size() < 2 and not pool.is_empty():
			var h: Dictionary = pool[int(floor(_r() * pool.size()))]
			pool.erase(h)
			keep.append(int(h.id))
			if p.care.size() > 0: Career.log_msg("A new horse arrives in your care: %s." % h.name, h)
	p.care = keep

static func written_score() -> float:
	var s: Dictionary = P().skills
	return float(s.know) * 0.75 + float(s.horse) * 0.25

static func interview_score() -> float:
	var s: Dictionary = P().skills
	return float(s.horse) * 0.4 + float(s.riding) * 0.3 + float(P().rep) * 0.3

## exam calendar for the JRA trainer licence
static func _exam_calendar() -> void:
	var p := P()
	var w := int(W.week)
	var ok_age := age() >= EXAM_AGE
	if w == EXAM_APPLY_WEEK and p.job in ["groom", "assistant"]:
		if not ok_age:
			if age() == EXAM_AGE - 1: Career.log_msg("Next year you will be %d — old enough to sit the JRA trainer licence exam." % EXAM_AGE, null)
		elif p.examApply:
			p["examYear"] = int(W.year); p["examStage"] = 1
			Career.ledger("JRA trainer exam application fee", -0.03, "licence")
			Career.log_msg("You applied for the JRA trainer licence exam. First stage (written + physical) in week %d." % EXAM_W1, null)
	if int(p.get("examYear", 0)) != int(W.year): return
	if w == EXAM_W1 and int(p.examStage) == 1:
		var sc := written_score() + Career.gauss() * 7.0
		var passed := sc >= EXAM_MARK1
		p.exams.append({ "y": W.year, "stage": 1, "score": snappedf(sc, 0.1), "pass": passed })
		p.examStage = 2 if passed else 0
		Career.log_msg("Trainer exam, first stage: %s (score %.0f, pass mark %.0f)." % ["PASSED" if passed else "failed", sc, EXAM_MARK1], null)
	elif w == EXAM_W2 and int(p.examStage) == 2:
		var sc2 := interview_score() + Career.gauss() * 7.0
		var passed2 := sc2 >= EXAM_MARK2
		p.exams.append({ "y": W.year, "stage": 2, "score": snappedf(sc2, 0.1), "pass": passed2 })
		p.examStage = 3 if passed2 else 0
		Career.log_msg("Trainer exam, second stage (interview): %s." % ("you did well — wait for the results in December" if passed2 else "not this time"), null)
	elif w == EXAM_RESULT and int(p.examStage) == 3:
		p.examStage = 4
		_hist("Passed the JRA trainer licence exam (attempt %d)" % _attempts())
		Career.log_msg("🎉 You PASSED the JRA trainer licence exam! Your licence starts on 1 March (week %d)." % LICENCE_WEEK, null)

static func _attempts() -> int:
	var n := 0
	for e in P().exams:
		if int(e.stage) == 1: n += 1
	return n

## called at the start of each week (after the year change) — opens the stable on 1 March after passing
static func licence_check() -> void:
	var p := P()
	if role() != "trainer" or p.licensed: return
	if int(p.get("examStage", 0)) == 4 and int(W.year) == int(p.examYear) + 1 and int(W.week) >= LICENCE_WEEK:
		p.licensed = true
		p.job = "trainer"
		p.examStage = 0
		p.care = []
		p.boxes = BOX_MIN
		p.jobSince = int(W.year)
		_hist("Licensed as a JRA trainer; opened a stable at %s with %d boxes" % [center_name(), p.boxes])
		Career.log_msg("Your stable at %s is open with %d boxes. Owners are starting to send you horses." % [center_name(), p.boxes], null)
		fill_new_yard(Career.R)

## licensed trainer: owner offers, owners moving horses away
static func _trainer_week() -> void:
	var p := P()
	var w := int(W.week)
	# expire old offers
	p.offers = p.offers.filter(func(o): return int(o.until) >= int(W.year) * 53 + w and Breeding.get_horse(o.id) != null and not Career._in_stable(o.id))
	if w in OFFER_WEEKS: _make_offers()
	# owners judge results every 4 weeks
	if w % 4 == 0:
		for id in W.stable.duplicate():
			var h = Breeding.get_horse(id)
			if h == null: continue
			var c: Dictionary = h.c
			if String(c.get("owner", "")) == "": continue
			var hist: Array = c.get("history", [])
			if hist.size() < 4: continue
			var bad := 0
			for e in hist.slice(0, 4):
				if typeof(e.pos) != TYPE_INT or float(e.pos) / float(e.of) > 0.6: bad += 1
			if bad >= 4 and _r() < 0.35 * (1.2 - float(p.rep) / 100.0):
				W.stable.erase(int(id))
				Career.log_msg("%s's owner (%s) has moved the horse to another stable after four poor runs." % [h.name, c.owner], h)
				c["owner"] = ""
				p.rep = maxf(0.0, p.rep - 1.0)

static func _make_offers() -> void:
	var p := P()
	var free: int = int(p.boxes) - W.stable.size() - p.offers.size()
	if free <= 0: return
	var n := mini(free, 1 + int(floor(_r() * (2.0 + float(p.rep) / 25.0))))
	var w := int(W.week)
	var young := w < 30
	var pool: Array = Career.active().filter(func(h): return not Career._in_stable(h.id) and not h.has("foreign") and int(h.c.get("out", 0)) == 0 and (int(h.age) == 2 if young else int(h.age) in [2, 3, 4, 5]))
	pool.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
	if pool.is_empty(): return
	# better reputation → owners trust you with better horses
	var top := clampf(0.55 - float(p.rep) / 200.0, 0.02, 0.6)
	for i in n:
		var q := clampf(top + _r() * 0.4, 0.0, 0.98)
		var h: Dictionary = pool[int(q * (pool.size() - 1))]
		pool.erase(h)
		p.offers.append({ "id": int(h.id), "owner": ai_owner_name(int(h.id) + w), "until": int(W.year) * 53 + w + 4 })
	Career.log_msg("📨 %d new horse%s offered to your stable — see Career › Owner offers." % [n, "" if n == 1 else "s"], null)

static func accept_offer(i: int) -> bool:
	var p := P()
	if i < 0 or i >= p.offers.size(): return false
	if W.stable.size() >= int(p.boxes): return false
	var o: Dictionary = p.offers[i]
	var h = Breeding.get_horse(o.id)
	p.offers.remove_at(i)
	if h == null or Career._in_stable(h.id): return false
	_take_horse(h, String(o.owner))
	Career.log_msg("%s (owner %s) joins your stable." % [h.name, o.owner], h)
	return true

static func decline_offer(i: int) -> void:
	var p := P()
	if i >= 0 and i < p.offers.size(): p.offers.remove_at(i)

## ---------- yearly ----------
static func year_end() -> void:
	var p := P()
	if p.is_empty(): return
	if licensed_trainer():
		# JRA reviews box numbers each year by results
		var wins := 0
		var gw := 0
		for id in W.stable:
			var h = Breeding.get_horse(id)
			if h == null: continue
			for x in h.c.get("history", []):
				if int(x.y) == int(W.year) and typeof(x.pos) == TYPE_INT and int(x.pos) == 1:
					wins += 1
					if x.cls in ["G1", "G2", "G3"]: gw += 1
		p.rep = clampf(p.rep * 0.85 + wins * 1.6 + gw * 5.0, 0.0, 100.0)
		var target := clampi(int(round(BOX_MIN + wins * 0.5 + p.rep / 8.0)), BOX_MIN, BOX_MAX)
		var nb := clampi(target, int(p.boxes) - 3, int(p.boxes) + 4)     # boxes change gradually, a few at a time
		if nb != int(p.boxes):
			Career.log_msg("JRA box review: your stable now has %d boxes (was %d)." % [nb, p.boxes], null)
			p.boxes = nb
		p.history.insert(0, { "y": W.year, "w": 52, "t": "Season %d: %d wins (%d graded) · %d boxes" % [W.year, wins, gw, nb] })
		if p.get("retiredOut", false):
			p.over = true
			Career.log_msg("You retired from training at %d. Thank you for a great career!" % age(), null)
	if role() == "breeder" and p.ownerLic == "":
		pass

## breeders and trainers who stop training can apply for an owner licence
static func owner_licence_ok() -> Array:   # [ok, reason]
	var p := P()
	if role() == "trainer": return [false, "JRA trainers can't own racehorses."]
	if p.ownerLic != "": return [false, "You already hold an owner licence."]
	var a := Finance.assets()
	var need := 50.0 if role() == "breeder" else 100.0
	if a < need: return [false, "You need assets of at least ¥%.0fM (you have %s)." % [need, Game.money(a)]]
	return [true, ""]

static func apply_owner_licence() -> bool:
	var ok := owner_licence_ok()
	if not ok[0]: return false
	P().ownerLic = "jra"
	Career.ledger("JRA owner registration and tax", -0.1, "licence")
	_hist("Registered as a JRA owner")
	Career.log_msg("You are now a registered JRA owner and can race your own horses.", null)
	return true

const FARM_PRICE := 80.0
static func buy_farm() -> bool:
	var p := P()
	if role() != "owner" or p.farm or Finance.money() < FARM_PRICE: return false
	p.farm = true
	p.farmValue = FARM_PRICE
	Career.ledger("Bought a breeding farm in Hidaka", -FARM_PRICE, "purchase")
	_hist("Bought a breeding farm in Hidaka (owner-breeder)")
	Career.log_msg("You bought a farm in Hidaka. Horses foaled there count as bred by you (breeder prizes).", null)
	return true

## breeders without an owner licence must sell their 2-year-olds before they race
static func breeder_spring_sales() -> void:
	if role() != "breeder" or P().ownerLic != "": return
	if int(W.week) != 14: return
	for id in W.stable.duplicate():
		var h = Breeding.get_horse(id)
		if h == null or int(h.age) != 2 or h.c.status != "active": continue
		Finance.sell(h, Finance.offer_price(h) * 0.9, "unsold 2-year-old sold privately — you have no owner licence")

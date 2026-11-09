class_name People
## Step 4B — real JRA jockeys and trainers (data/jockeys.csv, data/trainers.csv: the user's netkeiba export,
## one season's record each), plus the young jockeys and new trainers who come in over the years.
##
## Skill (0–100) comes from the record:
##   jockeys  — win rate (log scale) plus prize money per ride (big-race rides), e.g. C. Lemaire ≈ 96, median ≈ 62
##   trainers — win rate plus prize money per start
## Real JRA rules used:
##   * Apprentice allowances (見習騎手の減量): within 5 years of the licence, 1–30 wins ▲3 kg, 31–50 △2 kg, 51–100 ☆1 kg;
##     female jockeys ★4 kg / 3 kg / 2 kg (2 kg after 5 years too). Not in graded or special (OP) races.
##   * Trainers retire at 70.
## Jockeys with no stats in the file and trainers aged 70+ in the start year are treated as retired.

const JOCKEY_CSV := "res://data/jockeys.csv"
const TRAINER_CSV := "res://data/trainers.csv"

## training centre of trainers in the file (JRA lists). Others are assigned by a fixed hash and marked as a guess.
const CENTRE := {
	"Haruki Sugiyama": "ritto", "Yoshito Yahagi": "ritto", "Masahiro Otake": "ritto", "Makoto Saito": "miho", "Hideaki Fujiwara": "ritto",
	"Takahisa Tezuka": "miho", "Yasutoshi Ikee": "ritto", "Yuichi Shikato": "miho", "Ryo Terashima": "ritto", "Yuichi Fukunaga": "ritto",
	"Takashi Saito": "ritto", "Keisuke Miyata": "miho", "Shizuya Kato": "miho", "Tomokazu Takano": "ritto", "Yukihiro Kato": "miho",
	"Ryuji Okubo": "ritto", "Noriyuki Hori": "miho", "Yasuo Tomomichi": "ritto", "Hiroyuki Uemura": "miho", "Toru Kurita": "miho",
	"Yutaka Okumura": "ritto", "Katsunori Tanaka": "miho", "Kenji Nonaka": "ritto", "Takeshi Matsushita": "ritto", "Koshiro Take": "miho",
	"Hidetomo Take": "ritto", "Shogo Yasuda": "ritto", "Hisashi Shimizu": "ritto", "Hiroyasu Tanaka": "ritto", "Tamio Hamada": "ritto",
	"Hirofumi Shii": "miho", "Daisuke Takayanagi": "ritto", "Masaki Matsuyama": "miho", "Koji Maki": "ritto", "Naruhito Kitade": "ritto",
}

static var W: Dictionary:
	get: return Career.W

## ---------- loading ----------
static func _num(s: String) -> float:
	s = s.strip_edges().replace("%", "")
	return float(s) if s.is_valid_float() else 0.0

static func _read(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path): return out
	var f := FileAccess.open(path, FileAccess.READ)
	var head := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < head.size() or String(row[0]).strip_edges() == "": continue
		var d := {}
		for i in head.size(): d[String(head[i]).strip_edges()] = String(row[i])
		out.append(d)
	return out

## shrink small samples towards the average (a jockey with 1 win from 3 rides is not a 33 % jockey)
static func jockey_skill(rate: float, earn: float, wins: float) -> float:
	var rides := wins / maxf(rate, 0.004) if wins > 0.0 else 20.0
	var r := (wins + 0.06 * 40.0) / (rides + 40.0)
	var epr := (earn / 1.0e6 + 1.3 * 40.0) / (rides + 40.0)          # ¥M per ride
	var s := 56.0 + 17.0 * log(maxf(r, 0.004) / 0.05) + 5.0 * log(maxf(epr, 0.2) / 1.3)
	return clampf(s, 38.0, 97.0)

static func trainer_skill(rate: float, earn: float, wins: float) -> float:
	var starts := wins / maxf(rate, 0.004) if wins > 0.0 else 30.0
	var r := (wins + 0.08 * 40.0) / (starts + 40.0)
	var eps := (earn / 1.0e6 + 2.2 * 40.0) / (starts + 40.0)
	var s := 55.0 + 16.0 * log(maxf(r, 0.004) / 0.08) + 5.0 * log(maxf(eps, 0.2) / 2.2)
	return clampf(s, 35.0, 95.0)

## build the people of a new world (called from Career.init)
static func build(year: int) -> void:
	var js: Array = []
	var id := 1
	for d in _read(JOCKEY_CSV):
		var wins := _num(d.get("Wins", ""))
		if String(d.get("Wins", "")).strip_edges() == "" and String(d.get("Earnings", "")).strip_edges() == "": continue   # retired
		var rate := _num(d.get("Winning Rate", "")) / 100.0
		var born := int(_num(d.get("Birth Year", "1990")))
		if year - born > 60: continue
		var j := { "id": id, "name": String(d.Name), "born": born, "sex": "F" if String(d.get("Sex", "")).begins_with("F") else "M",
			"skill": snappedf(jockey_skill(rate, _num(d.get("Earnings", "")), wins), 0.1), "real": true,
			"demand": clampf(wins / maxf(rate, 0.004) if wins > 0.0 else 30.0, 20.0, 700.0),     # real rides this season: how much trainers book them
			"debut": maxi(born + 18, year - 30) if year - born > 22 else born + 18, "careerWins": int(wins) * 4,
			"rec": [int(wins), int(_num(d.get("2nds", ""))), int(_num(d.get("3rds", ""))), _num(d.get("Earnings", "")) / 1.0e6, rate * 100.0],
			"y": {}, "active": true }
		# young riders in the file: debut at 18, career wins estimated from this season (≈ 1/4 of a career so far)
		if year - born <= 22: j.careerWins = int(wins) * maxi(1, year - born - 17)
		js.append(j); id += 1
	var ts: Array = []
	var tid := 1
	for d in _read(TRAINER_CSV):
		var born := int(_num(d.get("Birth Year", "1970")))
		if year - born >= Profile.RETIRE_AGE: continue
		if String(d.get("Wins", "")).strip_edges() == "": continue
		var rate := _num(d.get("Winning Rate", "")) / 100.0
		var nm := String(d.Name)
		var c: String = CENTRE.get(nm, "miho" if (nm.hash() & 1) == 0 else "ritto")
		ts.append({ "id": tid, "name": nm, "born": born, "skill": snappedf(trainer_skill(rate, _num(d.get("Earnings", "")), _num(d.Wins)), 0.1),
			"centre": c, "centreGuess": not CENTRE.has(nm), "real": true, "y": {}, "active": true,
			"rec": [int(_num(d.Wins)), int(_num(d.get("2nds", ""))), int(_num(d.get("3rds", ""))), _num(d.get("Earnings", "")) / 1.0e6, rate * 100.0] })
		tid += 1
	W["jockeys"] = js
	W["trainers"] = ts
	W["nextJockey"] = id
	W["nextTrainer"] = tid

## ---------- attributes ----------
## The files give one number per person (from wins, places, prize money and rides). The detailed attributes
## spread that number into strengths and weaknesses that average back to it, so a jockey's overall effect on
## race times is unchanged; age shifts experience-type skills. Personalities come from a fixed hash of the
## name (the same person always has the same profile). Shown in the game as estimates.
static func _hs(s: String, k: int) -> float:
	return Owners._h(s.hash(), k * 7 + 3)

static func _spread(name: String, base: float, keys: Array, amp: float, tilt: Dictionary) -> Dictionary:
	var off: Array = []
	var mean := 0.0
	for i in keys.size():
		var o: float = (_hs(name, i) - 0.5) * 2.0 * amp + float(tilt.get(keys[i], 0.0))
		off.append(o); mean += o
	mean /= keys.size()
	var out := {}
	for i in keys.size(): out[keys[i]] = clampf(base + float(off[i]) - mean, 25.0, 99.0)
	return out

const JATTR := [["start", "Gate start"], ["pace", "Pace judgement"], ["finish", "Finishing drive"], ["tactics", "Positioning"], ["nerve", "Big-race nerve"], ["turf", "Turf"], ["dirt", "Dirt"]]
const TATTR := [["cond", "Conditioning"], ["care", "Horse care"], ["young", "Young horses"], ["plan", "Race planning"]]

static func jattr(j: Dictionary) -> Dictionary:
	if j.is_empty(): return {}
	var age := int(W.get("year", 2027)) - int(j.get("born", 1990))
	var exp := clampf((age - 30.0) / 10.0, -1.0, 1.0)        # veterans judge pace and position; young riders break and drive
	var nm := String(j.name)
	var sk := float(j.skill)
	var a := _spread(nm, sk, ["start", "pace", "finish", "tactics"], 8.0, { "pace": 4.0 * exp, "tactics": 3.0 * exp, "start": -3.0 * exp, "finish": -4.0 * exp })
	a["nerve"] = clampf(sk + (_hs(nm, 7) - 0.5) * 18.0 + 3.0 * exp, 25.0, 99.0)
	var surf := (_hs(nm, 8) - 0.5) * 16.0
	a["turf"] = clampf(sk + surf, 25.0, 99.0)
	a["dirt"] = clampf(sk - surf, 25.0, 99.0)
	return a

static func tattr(t: Dictionary) -> Dictionary:
	if t.is_empty(): return {}
	return _spread(String(t.name), float(t.skill), ["cond", "care", "young", "plan"], 9.0, {})

## engine values for a ride (engine scale = skill + 10, like the overall "jockey" number)
static func ride_attrs(j: Dictionary, r: Dictionary) -> Dictionary:
	var a := jattr(j)
	if a.is_empty(): return {}
	var big := 0.0
	if r.get("cls", "") in ["G1", "G2"]: big = clampf((float(a.nerve) - float(j.skill)) * 0.5, -5.0, 5.0)
	var dirt: bool = String(RaceEngine.COURSES.get(r.course, {}).get("surface", "turf")) == "dirt"
	var surf := clampf((float(a.dirt if dirt else a.turf) - float(j.skill)) * 0.4, -4.0, 4.0)
	var out := {}
	for k in ["start", "pace", "finish", "tactics"]: out[k] = clampf(float(a[k]) + 10.0 + big + surf, 0.0, 100.0)
	return out

static func jockey(id: Variant) -> Dictionary:
	if id == null: return {}
	for j in W.get("jockeys", []):
		if int(j.id) == int(id): return j
	return {}

static func trainer(id: Variant) -> Dictionary:
	if id == null: return {}
	for t in W.get("trainers", []):
		if int(t.id) == int(id): return t
	return {}

static func active_jockeys() -> Array: return W.get("jockeys", []).filter(func(j): return j.active)
static func active_trainers() -> Array: return W.get("trainers", []).filter(func(t): return t.active)

## ---------- apprentice allowance ----------
static func claim(j: Dictionary, year: int) -> int:
	if j.is_empty(): return 0
	var yrs := year - int(j.get("debut", year - 10))
	var wins := int(j.get("careerWins", 999))
	var f := String(j.get("sex", "M")) == "F"
	if yrs < 5:
		if wins <= 30: return 4 if f else 3
		if wins <= 50: return 3 if f else 2
		if wins <= 100: return 2 if f else 1
		return 2 if f else 0
	return 2 if f else 0

static func claim_mark(kg: int) -> String:
	return { 4: "★", 3: "▲", 2: "△", 1: "☆" }.get(kg, "")

static func claim_ok(r: Dictionary) -> bool:
	return r.cls in ["NEW", "MDN", "1W", "2W", "3W"] and not Intl.is_intl(r)

## ---------- trainers for horses ----------
## AI horses get a trainer when they first need one: better horses tend to go to better (and busier) stables
static func ensure_trainer(h: Dictionary) -> void:
	var c: Dictionary = h.get("c", {})
	if c.has("trainer") or h.has("foreign"): return
	var ts := active_trainers()
	if ts.is_empty(): return
	var rating := Career.rating(Game.view(h)) if h.has("stats") else 60.0
	# the owner sends most horses to its favourite stables
	var fav: Array = Owners.of(h).get("favT", [])
	if not fav.is_empty() and Career.rng() < 0.6:
		var tf := trainer(fav[int(floor(Career.rng() * fav.size()))])
		if not tf.is_empty() and tf.active: c["trainer"] = int(tf.id); return
	# weight: skill^k (top stables get the top yearlings), with randomness
	var best = null
	var bs := -INF
	for i in 6:
		var t: Dictionary = ts[int(floor(Career.rng() * ts.size()))]
		var sc := float(t.skill) * (0.5 + (rating - 55.0) / 40.0) + Career.gauss() * 6.0
		if sc > bs: bs = sc; best = t
	c["trainer"] = int(best.id)

## ---------- jockeys for a race ----------
## every runner gets a jockey. Busy jockeys (many rides in the real season) get more rides, and the better a horse,
## the more its connections go for a top rider. The player's booking is kept (h.c.book = jockey id, h.c.bookRace = race).
static func assign_jockeys(r: Dictionary, field: Array) -> void:
	var js := active_jockeys()
	if js.is_empty(): return
	var taken := {}
	for h in field:
		var b = h.c.get("book")
		if b != null and int(h.c.get("bookRace", -1)) == int(r.id) and not jockey(b).is_empty(): taken[int(b)] = true
	var order: Array = field.duplicate()
	order.sort_custom(func(a, b): return Career.rating(a) > Career.rating(b))
	var n := order.size()
	var big := 1.6 if r.cls in ["G1", "G2"] else (1.25 if r.cls in ["G3", "OP"] else 1.0)
	for i in n:
		var h: Dictionary = order[i]
		var jid = null
		var b = h.c.get("book")
		if b != null and int(h.c.get("bookRace", -1)) == int(r.id) and taken.has(int(b)): jid = int(b)
		else:
			var q := 1.0 - 2.0 * float(i) / maxf(1.0, n - 1.0)          # +1 the best-fancied runner … −1 the outsider
			var fav: Array = Owners.of(h).get("favJ", [])
			var tot := 0.0
			var ws: Array = []
			for j in js:
				var w := 0.0
				if not taken.has(int(j.id)): w = float(j.get("demand", 150.0)) * exp(0.45 * big * q * (float(j.skill) - 70.0) / 10.0) * (3.0 if fav.has(int(j.id)) else 1.0)
				ws.append(w); tot += w
			var u := Career.rng() * tot
			for k in js.size():
				u -= float(ws[k])
				if u <= 0.0 and float(ws[k]) > 0.0: jid = int(js[k].id); break
		if jid == null: continue
		taken[int(jid)] = true
		var j := jockey(jid)
		h["jockey"] = minf(100.0, float(j.skill) + 10.0)      # engine scale: the average ride (≈60) = the old default 70
		h["jat"] = ride_attrs(j, r)                          # start / pace / finish / tactics for the full race engine
		h["jockeyId"] = int(jid)
		h["claim"] = claim(j, int(W.year)) if claim_ok(r) else 0
		h.c.erase("book"); h.c.erase("bookRace")

## record a ride for the season tables
static func ride(jid: Variant, tid: Variant, pos: int, prize: float) -> void:
	var y := str(int(W.year))
	for pair in [[jockey(jid), true], [trainer(tid), false]]:
		var p: Dictionary = pair[0]
		if p.is_empty(): continue
		if not p.y.has(y): p.y[y] = [0, 0, 0, 0, 0.0]     # rides, 1st, 2nd, 3rd, prize
		var s: Array = p.y[y]
		s[0] += 1
		if pos >= 1 and pos <= 3: s[pos] += 1
		s[4] += prize
		if pair[1] and pos == 1: p["careerWins"] = int(p.get("careerWins", 0)) + 1

## will a jockey accept the player's booking? Top riders turn down weak horses
static func accepts(j: Dictionary, h: Dictionary, r: Dictionary) -> bool:
	var need := float(j.skill) - 60.0
	var hr := Career.rating(Game.view(h)) - 55.0
	var big := 12.0 if r.cls in ["G1", "G2", "G3"] else 0.0
	var rep := float(Profile.P().get("rep", 30.0)) / 10.0
	return hr + big + rep >= need * 0.8

## ---------- year end: ageing, retirements, new apprentices and new stables ----------
const JFIRST := ["Haruto", "Sota", "Yuto", "Riku", "Kaito", "Ren", "Hinata", "Sora", "Takumi", "Daiki", "Kosei", "Yuma", "Rina", "Mio", "Aoi", "Koharu"]
const JLAST := ["Aoki", "Hirano", "Kubota", "Matsui", "Nagai", "Ono", "Sakai", "Shibata", "Takeda", "Ueda", "Yasuda", "Mochizuki", "Kawano", "Ishii", "Morioka", "Nishida"]

static func year_end(year: int) -> void:
	if not W.has("jockeys"): return
	var r := Career.R
	for j in W.jockeys:
		if not j.active: continue
		var age := year + 1 - int(j.born)
		# improvement while young, slow decline after 40
		if age < 27: j.skill = minf(97.0, float(j.skill) + 1.2 + r.gauss() * 0.8)
		elif age > 42: j.skill = maxf(35.0, float(j.skill) - 0.8 + r.gauss() * 0.5)
		var quit := (age >= 50 and r.next() < 0.12) or (age >= 56 and r.next() < 0.5) or age >= 60
		if quit:
			j.active = false
			Career.log_msg("Jockey %s retires at %d." % [j.name, age], null)
	for t in W.trainers:
		if t.active and year + 1 - int(t.born) >= Profile.RETIRE_AGE:
			t.active = false
			Career.log_msg("Trainer %s retires (age %d)." % [t.name, year + 1 - int(t.born)], null)
			for h in Career.active():
				if int(h.c.get("trainer", -1)) == int(t.id): h.c.erase("trainer")   # horses move to another stable
	# new apprentices from the JRA Racing School (7–9 a year) and new trainers (about as many as retire)
	var n := 7 + int(floor(r.next() * 3.0))
	for i in n:
		var f := r.next() < 0.15
		var nm := "%s %s" % [JFIRST[int(floor(r.next() * JFIRST.size()))] if not f else JFIRST[12 + int(floor(r.next() * 4.0))], JLAST[int(floor(r.next() * JLAST.size()))]]
		W.jockeys.append({ "id": int(W.nextJockey), "name": nm, "born": year + 1 - 18, "sex": "F" if f else "M", "skill": snappedf(40.0 + r.next() * 18.0, 0.1),
			"real": false, "debut": year + 1, "careerWins": 0, "y": {}, "active": true, "demand": 150.0 })
		W.nextJockey = int(W.nextJockey) + 1
	var gone: int = W.trainers.filter(func(t): return not t.active and int(t.get("retY", year)) == year).size()
	for t in W.trainers:
		if not t.active and not t.has("retY"): t["retY"] = year
	for i in maxi(2, gone):
		var nm := "%s %s" % [Profile.GIVEN[int(floor(r.next() * Profile.GIVEN.size()))], Profile.SURNAMES[int(floor(r.next() * Profile.SURNAMES.size()))]]
		W.trainers.append({ "id": int(W.nextTrainer), "name": nm, "born": year + 1 - 40 - int(floor(r.next() * 10.0)), "skill": snappedf(45.0 + r.next() * 15.0, 0.1),
			"centre": "miho" if r.next() < 0.5 else "ritto", "centreGuess": false, "real": false, "y": {}, "active": true })
		W.nextTrainer = int(W.nextTrainer) + 1

## leaders table for a year: [{p, rides, w, w2, w3, prize}] sorted by wins
static func leaders(kind: String, year: int) -> Array:
	var out: Array = []
	for p in W.get(kind, []):
		var s: Array = p.y.get(str(year), [])
		if s.is_empty(): continue
		out.append({ "p": p, "rides": int(s[0]), "w": int(s[1]), "w2": int(s[2]), "w3": int(s[3]), "prize": float(s[4]) })
	out.sort_custom(func(a, b): return a.w > b.w or (a.w == b.w and a.prize > b.prize))
	return out

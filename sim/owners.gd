class_name Owners
## Step 4 — CPU owners (馬主). Every horse not owned by the player belongs to an owner: the big racing clubs
## (一口馬主クラブ) and owner-breeders that dominate JRA racing, plus individual owners.
## Real organisation names are used for the clubs and farms; individuals are fictional. Silks are generated
## (not the real registered colours). Budgets and sizes are rough relative scales, not real figures.
##
## Owners matter in the game: they choose trainers (each has favourite stables), book jockeys (favourite riders
## get more of their rides), buy at the sales, and keep season records like a football club's honours.

## name, kind, size (relative number and quality of horses), budget (¥M a year for buying)
const REAL := [
	["Sunday Racing", "club", 10.0, 2500.0], ["Silk Racing", "club", 7.0, 1400.0], ["Carrot Farm", "club", 7.0, 1300.0],
	["Shadai Race Horse", "club", 6.5, 1200.0], ["G1 Racing", "club", 5.0, 900.0], ["Tokyo Horse Racing", "club", 4.5, 800.0],
	["Lord Horse Club", "club", 3.0, 450.0], ["Win Racing Club", "club", 3.0, 420.0], ["Hiroo Racing", "club", 3.0, 420.0],
	["Danox", "company", 4.0, 900.0], ["Kaneko Makoto Holdings", "company", 3.5, 700.0], ["Northern Farm", "breeder", 4.0, 500.0],
	["Shadai Farm", "breeder", 3.0, 400.0], ["Big Red Farm", "breeder", 2.5, 300.0],
]
const FIRST := ["Hiroshi", "Kenji", "Takashi", "Masaru", "Yoshio", "Kazuo", "Akira", "Shigeru", "Tadashi", "Noboru", "Keiko", "Yumiko", "Sachiko", "Ichiro", "Goro"]
const LAST := ["Fujita", "Ogawa", "Kimura", "Hayashi", "Shimizu", "Yamaguchi", "Matsumoto", "Inoue", "Kondo", "Ishikawa", "Maeda", "Okada", "Hasegawa", "Murakami", "Endo", "Aoyama"]
const INDIVIDUALS := 36

static var W: Dictionary:
	get: return Career.W

## stable hash in [0, 1) — owner choices must not use the career RNG (keeps saves and tests reproducible)
static func _h(a: int, b: int) -> float:
	var x := (a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffffff) / 16777216.0

static func build() -> void:
	var list: Array = []
	var id := 1
	for r in REAL:
		list.append({ "id": id, "name": r[0], "kind": r[1], "size": r[2], "budget": r[3], "real": true }); id += 1
	for i in INDIVIDUALS:
		var nm := "%s %s" % [FIRST[int(_h(i, 1) * FIRST.size())], LAST[int(_h(i, 2) * LAST.size())]]
		list.append({ "id": id, "name": nm, "kind": "individual", "size": 0.6 + 1.6 * _h(i, 3), "budget": 40.0 + 260.0 * _h(i, 4), "real": false }); id += 1
	var ts: Array = W.get("trainers", [])
	var js: Array = W.get("jockeys", [])
	for o in list:
		var oid := int(o.id)
		o["silks"] = Silks.random_for(oid * 4241 + 7)
		o["y"] = {}
		o["g1"] = []
		# favourite stables and riders: the big clubs work with the top yards and jockeys
		var fav_t: Array = []
		var fav_j: Array = []
		var top_t := ts.duplicate(); top_t.sort_custom(func(a, b): return float(a.skill) > float(b.skill))
		var top_j := js.duplicate(); top_j.sort_custom(func(a, b): return float(a.skill) > float(b.skill))
		var reach := int(clampf(60.0 - float(o.size) * 5.0, 6.0, 60.0))     # bigger owners pick from a smaller, better pool
		for k in 4:
			if not top_t.is_empty(): fav_t.append(int(top_t[int(_h(oid, 10 + k) * mini(reach, top_t.size()))].id))
			if not top_j.is_empty(): fav_j.append(int(top_j[int(_h(oid, 20 + k) * mini(reach + 10, top_j.size()))].id))
		o["favT"] = fav_t
		o["favJ"] = fav_j
	W["owners"] = list

static func owner(id: Variant) -> Dictionary:
	if id == null: return {}
	for o in W.get("owners", []):
		if int(o.id) == int(id): return o
	return {}

## the owner of a CPU horse, assigned the first time it is needed: better horses go to the bigger owners
static func of(h: Dictionary) -> Dictionary:
	if h.is_empty() or Career._in_stable(h.get("id", -1)): return {}
	if not W.has("owners"): return {}
	if h.has("ownerId"): return owner(h.ownerId)
	var q := 0.5
	if h.has("stats"): q = clampf((Career.rating(Game.view(h)) - 45.0) / 40.0, 0.0, 1.0)
	var tot := 0.0
	var ws: Array = []
	for o in W.owners:
		var w := float(o.size) * pow(float(o.size), (q - 0.5) * 3.0)      # top horses gather at the big clubs
		ws.append(w); tot += w
	var u := _h(int(h.id), 99) * tot
	var pick: Dictionary = W.owners[0]
	for k in ws.size():
		u -= float(ws[k])
		if u <= 0.0: pick = W.owners[k]; break
	h["ownerId"] = int(pick.id)
	return pick

static func name_of(h: Dictionary) -> String:
	if Career._in_stable(h.get("id", -1)): return String(W.get("stable_name", "You"))
	var o := of(h)
	return String(o.get("name", "—"))

## an AI buyer at the sales: the deeper the pocket, the likelier to win the lot (expensive lots go to big buyers)
static func buyer_for(h: Dictionary, price: float) -> Dictionary:
	if not W.has("owners"): return {}
	var tot := 0.0
	var ws: Array = []
	for o in W.owners:
		var w := maxf(0.0, float(o.budget) - price * 2.0) + 1.0
		ws.append(w); tot += w
	var u := _h(int(h.id), int(price * 10.0) + 7) * tot
	for k in ws.size():
		u -= float(ws[k])
		if u <= 0.0: return W.owners[k]
	return W.owners[0]

## season record: [runs, 1st, 2nd, 3rd, prize]
static func record(h: Dictionary, pos: int, prize: float, race: Dictionary) -> void:
	var o := of(h)
	if o.is_empty(): return
	var y := str(int(W.year))
	if not o.y.has(y): o.y[y] = [0, 0, 0, 0, 0.0]
	var s: Array = o.y[y]
	s[0] += 1
	if pos >= 1 and pos <= 3: s[pos] += 1
	s[4] += prize
	if pos == 1 and race.get("cls", "") == "G1": o.g1.append({ "y": int(W.year), "race": race.name, "horse": h.name })

static func horses_of(oid: int) -> Array:
	return Career.active().filter(func(h): return int(h.get("ownerId", -1)) == oid)

static func leaders(year: int) -> Array:
	var out: Array = []
	for o in W.get("owners", []):
		var s: Array = o.y.get(str(year), [])
		if s.is_empty(): continue
		out.append({ "p": o, "rides": int(s[0]), "w": int(s[1]), "w2": int(s[2]), "w3": int(s[3]), "prize": float(s[4]) })
	out.sort_custom(func(a, b): return a.prize > b.prize)
	return out

class_name Rivals
extends RefCounted
## Step 5 — the rest of Japan's best horses.
## The game world breeds ~1,100 foals a year, but the JRA races ~4,600 newly registered horses a year. The full graded
## calendar (24 JRA G1s) is shared by all of them, so without the others a world horse would win graded races ~4×
## more often than a real one. Each crop therefore gets "rivals": the open-class horses from the stables outside the
## game world (about 3 % of the other ~3,500 horses, i.e. ~0.096 per world foal), bred from the world's stallions out
## of mares from other farms. They won their condition races off-screen, so they run only in open and graded races
## (2-year-olds: in the 2-year-old stakes). They are ordinary AI horses otherwise: CPU trainers and owners, injuries,
## retirement, the stallions among them can go to stud.

const PER_FOAL := 0.096          # rivals per world foal (3.2 × 3 %)
const TOP := 0.97                # they are as good as the world's top 3 % (rating at maturity)
const DAM_Q := 68.0              # the other farms' mares that bred them (founder quality; most are good mares)
const ATTEMPTS := 30             # tries per rival (rejection sampling above the threshold)

static func is_rival(h: Dictionary) -> bool:
	return h.get("rival", false)

## races a rival runs in
static func can_run(h: Dictionary, r: Dictionary) -> bool:
	return r.cls in ["OP", "G3", "G2", "G1"] or Intl.is_intl(r)

## make the rivals of one crop (born in year `born`, now `age` years old)
static func make_crop(born: int, age: int, rng: SimRng) -> int:
	var crop: Array = []
	for h in Breeding.book.values():
		var c = h.get("c")
		if c != null and int(c.get("born", -1)) == born and not is_rival(h) and h.get("foreign") == null and h.get("sire") != null: crop.append(Career.rating(h))
	if crop.size() < 50: return 0
	crop.sort()
	var thr: float = crop[int(floor(TOP * (crop.size() - 1)))]
	# (older crops at the start of a new world: some have already retired)
	var n := int(round(float(Career.W.get("crop", crop.size())) * PER_FOAL * float({ 4: 0.7, 5: 0.45, 6: 0.25 }.get(age, 1.0))))
	var made := 0
	var tries := 0
	while made < n and tries < n * ATTEMPTS:
		tries += 1
		var s = Career.pick_sire(rng, born)
		if s == null: break
		var d := Breeding.founder(rng, "F", DAM_Q, { "born": born - 6, "otherFarm": true })
		var f := Breeding.breed(s, d, rng)
		if Career.rating(f) < thr:
			Breeding.forget(f); Breeding.forget(d)
			continue
		f["age"] = age
		f["rival"] = true
		f["c"] = Career.new_career(f, born)
		d["age"] = age + 6
		_class_for_age(f)
		var k = Career.crop_rec(f)
		k.n += 1
		made += 1
	return made

## the condition-race wins they earned elsewhere (so they qualify and rank for the stakes like real open horses)
static func _class_for_age(h: Dictionary) -> void:
	var c: Dictionary = h.c
	var age := int(h.age)
	var u := float(Stud.hnoise(int(h.id), 41)) * 0.5 + 0.5            # hash-based: no RNG
	if age >= 2 and int(c.wins) == 0:
		c.wins = 1; c.cm = maxf(float(c.cm), 4.0)
	if age >= 3 and float(c.cm) <= 16.0:
		c.wins = maxi(int(c.wins), 4); c.cm = 17.0 + u * 8.0

## at the new year (after ages go up)
static func year_end() -> void:
	for h in Breeding.book.values():
		if is_rival(h) and h.has("c") and h.c.status == "active": _class_for_age(h)

class_name Markings
## White face and leg markings, and grey ageing.
##
## Genetics (simplified from horse genetics research): the amount of white is a polygenic trait with high
## heritability, so each horse carries a "white" value; a foal gets the parents' mean plus noise (about half
## the variance is inherited). Chestnuts (e/e) tend to show more white than bays and blacks, and hind legs are
## white more often than front legs. The face and leg markings are then drawn from that value with a fixed
## per-horse hash, so a horse always keeps the same markings.
##
## Grey (G allele): greys are born coloured, go dark iron-grey as youngsters and lighten every year, dappled in
## between, nearly white by about 7–9.

const FACE := ["none", "star", "stripe", "star_stripe", "snip", "star_snip", "blaze", "blaze_snip", "bald",
	"interrupted_stripe", "irregular_blaze", "star_stripe_snip", "star_streak"]
const FACE_EN := { "none": "", "star": "star", "stripe": "stripe", "star_stripe": "star and stripe", "snip": "snip",
	"star_snip": "star and snip", "blaze": "blaze", "blaze_snip": "blaze", "bald": "bald face",
	"interrupted_stripe": "interrupted stripe", "irregular_blaze": "irregular blaze", "star_stripe_snip": "star, stripe and snip",
	"star_streak": "star and streak" }
const LEG_EN := ["", "coronet", "pastern", "sock", "stocking"]
const LEG_NAMES := ["left fore", "right fore", "left hind", "right hind"]

## stable hash in [0, 1)
static func _h(id: int, k: int) -> float:
	return Owners._h(id * 31 + 7, k * 13 + 1)

## the inherited white value (≈ normal, mean 0, sd 1); stored on the horse when known
static func white(h: Dictionary) -> float:
	if h.has("white"): return float(h.white)
	var id := int(h.get("id", 0))
	var u1 := maxf(1e-6, _h(id, 1)); var u2 := _h(id, 2)
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)

## foal: mid-parent + half the variance as new noise
static func inherit(foal: Dictionary, sire: Dictionary, dam: Dictionary) -> void:
	var id := int(foal.get("id", 0))
	var u1 := maxf(1e-6, _h(id, 3)); var u2 := _h(id, 4)
	var n := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	foal["white"] = snappedf((white(sire) + white(dam)) * 0.5 + n * 0.72, 0.01)

## { face: String, legs: [LF, RF, LH, RH] each 0 none … 4 stocking }
static func of(h: Dictionary) -> Dictionary:
	if h.has("marks"): return h.marks
	var id := int(h.get("id", 0))
	var w := white(h) + (0.45 if String(h.get("coat", "")) == "chestnut" else 0.0)
	# face: more white -> bigger marks
	var fz := w + (_h(id, 5) - 0.5) * 1.2
	var face := "none"
	if fz > 2.1: face = "bald"
	elif fz > 1.3: face = "blaze_snip" if _h(id, 6) < 0.4 else "blaze"
	elif fz > 0.75: face = ["star_stripe", "star_snip", "stripe"][int(_h(id, 7) * 3.0)]
	elif fz > 0.1: face = "star" if _h(id, 8) < 0.75 else "snip"
	# the newer face patterns (ChatGPT's Blender set): variants of the same amount of white
	match face:
		"stripe": if _h(id, 30) < 0.3: face = "interrupted_stripe"
		"blaze": if _h(id, 31) < 0.35: face = "irregular_blaze"
		"star_stripe": if _h(id, 32) < 0.35: face = "star_stripe_snip"
		"star": if _h(id, 33) < 0.12: face = "star_streak"
	# legs: hind legs more often white; each leg its own level
	var legs: Array = []
	for k in 4:
		var hind := k >= 2
		var z := w + (0.55 if hind else 0.0) + (_h(id, 10 + k) - 0.5) * 1.6 - 0.6
		var lv := 0
		if z > 1.6: lv = 4
		elif z > 0.9: lv = 3
		elif z > 0.45: lv = 2
		elif z > 0.15: lv = 1
		legs.append(lv)
	var m := { "face": face, "legs": legs }
	h["marks"] = m
	return m

## words for the horse page: "Blaze; white socks on both hind legs" …
static func describe(h: Dictionary) -> String:
	var m := of(h)
	var parts: Array = []
	if m.face != "none":
		var fw := String(FACE_EN[m.face])
		parts.append(fw.substr(0, 1).to_upper() + fw.substr(1))
	var by := {}
	for k in 4:
		var lv := int(m.legs[k])
		if lv > 0:
			if not by.has(lv): by[lv] = []
			by[lv].append(LEG_NAMES[k])
	for lv in [4, 3, 2, 1]:
		if not by.has(lv): continue
		var ls: Array = by[lv]
		var where := ", ".join(ls)
		if ls.size() == 4: where = "all four legs"
		elif ls.size() == 2 and ls.has("left hind") and ls.has("right hind"): where = "both hind legs"
		elif ls.size() == 2 and ls.has("left fore") and ls.has("right fore"): where = "both front legs"
		parts.append("%s%s on %s" % [LEG_EN[lv], "s" if ls.size() > 1 else "", where])
	return "No white markings" if parts.is_empty() else "; ".join(parts)

## how light a grey is (0 = dark iron-grey youngster … 1 = nearly white), by age
static func grey_level(h: Dictionary) -> float:
	var a := float(h.get("age", 3))
	var speed := 0.85 + 0.3 * _h(int(h.get("id", 0)), 20)       # some greys go white faster than others
	return clampf((a - 1.0) * 0.14 * speed, 0.0, 1.0)

static func coat_text(h: Dictionary) -> String:
	var c := String(h.get("coat", "bay"))
	if c != "grey": return c
	var g := grey_level(h)
	if g < 0.3: return "grey (dark iron-grey, still lightening)"
	if g < 0.6: return "grey (dappled, lightening)"
	if g < 0.85: return "grey (light grey)"
	return "grey (almost white)"

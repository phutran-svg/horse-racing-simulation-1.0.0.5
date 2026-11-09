class_name Silks
extends RefCounted
## Racing silks (勝負服) by JRA rules: up to 13 registered colours, a body pattern and a sleeve pattern.
## In JRA races the cap colour follows the gate bracket (枠番), so it is not part of the owner's design.
## Stored in W.silks = { body, pattern, pcol, sleeve, spattern, scol }; W.silk keeps the main colour for older code.

const COLORS := [
	["White", "白", "#f4f4f2"], ["Black", "黒", "#1b1b1d"], ["Red", "赤", "#d32f2f"], ["Blue", "青", "#1f4fb8"], ["Yellow", "黄", "#f2c919"],
	["Green", "緑", "#1e8a3f"], ["Purple", "紫", "#6a2fa0"], ["Pink", "桃", "#f08cb4"], ["Light blue", "水", "#5fb4e6"], ["Brown", "茶", "#7a4a26"],
	["Maroon", "海老茶", "#7a1f2b"], ["Lilac", "薄紫", "#b39ddb"], ["Grey", "鼠", "#8c8f94"],
]
const BODY := [
	["plain", "Plain", "無地"], ["hoop1", "Single hoop", "一本輪"], ["hoop2", "Two hoops", "二本輪"], ["hoops", "Hoops", "横縞"],
	["stripes", "Stripes", "縦縞"], ["chevrons", "Chevrons", "山形"], ["zigzag", "Saw-tooth", "鋸歯形"], ["sash", "Sash", "襷"],
	["cross", "Cross-belts", "十字襷"], ["band", "Band", "帯"], ["diamonds", "Diamonds", "菱山形"], ["checks", "Checks", "格子"],
	["dots", "Spots", "玉霰"], ["stars", "Stars", "星散"], ["rings", "Rings", "蛇目"], ["quarters", "Quartered", "元禄"],
]
const SLEEVE := [
	["plain", "Plain", "無地"], ["hoops", "Hoops", "袖横縞"], ["stripes", "Stripes", "袖縦縞"], ["hoop1", "Single armlet", "袖一本輪"],
	["hoop2", "Two armlets", "袖二本輪"], ["chevrons", "Chevrons", "袖山形"], ["diamonds", "Diamonds", "袖菱山形"], ["dots", "Spots", "袖玉霰"],
]
## JRA gate bracket cap colours (枠1–8)
const CAPS := ["#f4f4f2", "#1b1b1d", "#d32f2f", "#1f4fb8", "#f2c919", "#1e8a3f", "#f08a1e", "#f08cb4"]

static func default_for(hex: String) -> Dictionary:
	return { "body": hex, "pattern": "plain", "pcol": "#f4f4f2", "sleeve": hex, "spattern": "plain", "scol": "#f4f4f2" }

static func of(W: Dictionary) -> Dictionary:
	if W.has("silks"): return W.silks
	return default_for(String(W.get("silk", "#6d4df2")))

static func main_hex(W: Dictionary) -> String:
	return String(of(W).body)

## a plausible owner's design for horses without one (stable per seed, built around a main colour)
static func random_for(seed: int, main := "") -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var base: String = main if main != "" else String(COLORS[r.randi() % COLORS.size()][2])
	var other: String = String(COLORS[r.randi() % COLORS.size()][2])
	while other == base: other = String(COLORS[r.randi() % COLORS.size()][2])
	var pat: String = String(BODY[r.randi() % BODY.size()][0]) if r.randf() < 0.75 else "plain"
	var sp: String = String(SLEEVE[r.randi() % SLEEVE.size()][0]) if r.randf() < 0.6 else "plain"
	return { "body": base, "pattern": pat, "pcol": other, "sleeve": base if r.randf() < 0.5 else other, "spattern": sp, "scol": other if r.randf() < 0.7 else base }

## JRA gate bracket (枠番, 1–8) for horse number n in a field of size N: the last brackets take the extra horses
static func bracket(n: int, N: int) -> int:
	if N <= 8: return n
	var base := N / 8
	var extra := N % 8
	var k := 0
	for b in range(1, 9):
		k += base + (1 if b > 8 - extra else 0)
		if n <= k: return b
	return 8

static func cap_hex(n: int, N: int) -> String:
	return CAPS[bracket(n, N) - 1]

## 1 where the pattern colour shows, 0 where the base colour shows. u: 0..1 across, v: 0..1 down.
static func pattern_at(p: String, u: float, v: float, sleeve := false) -> float:
	match p:
		"plain": return 0.0
		"hoop1": return 1.0 if absf(v - (0.5 if sleeve else 0.5)) < (0.09 if sleeve else 0.08) else 0.0
		"hoop2": return 1.0 if absf(v - 0.36) < 0.065 or absf(v - 0.64) < 0.065 else 0.0
		"hoops": return 1.0 if fposmod(v * 6.0, 1.0) < 0.5 else 0.0
		"stripes": return 1.0 if fposmod(u * (5.0 if not sleeve else 3.0), 1.0) < 0.5 else 0.0
		"chevrons":
			var c := fposmod((v + absf(u - 0.5) * 0.9) * 4.0, 1.0)
			return 1.0 if c < 0.45 else 0.0
		"zigzag":
			var z := 0.5 + 0.12 * (absf(fposmod(u * 6.0, 1.0) - 0.5) * 2.0 - 0.5)
			return 1.0 if v > z else 0.0
		"sash": return 1.0 if absf((u - 0.5) - (v - 0.5) * 0.85) < 0.11 else 0.0
		"cross": return 1.0 if absf((u - 0.5) - (v - 0.5) * 0.85) < 0.09 or absf((u - 0.5) + (v - 0.5) * 0.85) < 0.09 else 0.0
		"band": return 1.0 if absf(u - 0.5) < 0.16 else 0.0
		"diamonds":
			var a := fposmod(u * 3.0, 1.0) - 0.5
			var b := fposmod(v * 3.0, 1.0) - 0.5
			return 1.0 if absf(a) + absf(b) < 0.32 else 0.0
		"checks": return 1.0 if (int(floor(u * 4.0)) + int(floor(v * 4.0))) % 2 == 0 else 0.0
		"dots":
			var du := fposmod(u * 4.0 + (0.5 if int(floor(v * 4.0)) % 2 == 1 else 0.0), 1.0) - 0.5
			var dv := fposmod(v * 4.0, 1.0) - 0.5
			return 1.0 if du * du + dv * dv < 0.06 else 0.0
		"stars":
			var su := fposmod(u * 3.0 + (0.5 if int(floor(v * 3.0)) % 2 == 1 else 0.0), 1.0) - 0.5
			var sv := fposmod(v * 3.0, 1.0) - 0.5
			var ang := atan2(sv, su)
			var r := sqrt(su * su + sv * sv)
			return 1.0 if r < 0.13 + 0.11 * cos(5.0 * ang) else 0.0
		"rings":
			var ru := fposmod(u * 2.0, 1.0) - 0.5
			var rv := fposmod(v * 2.0, 1.0) - 0.5
			var rr := sqrt(ru * ru + rv * rv)
			return 1.0 if rr > 0.2 and rr < 0.33 else 0.0
		"quarters": return 1.0 if (u < 0.5) != (v < 0.5) else 0.0
	return 0.0

static func body_color(s: Dictionary, u: float, v: float) -> Color:
	return Color(s.pcol) if pattern_at(String(s.pattern), u, v) > 0.5 else Color(s.body)

static func sleeve_color(s: Dictionary, u: float, v: float) -> Color:
	return Color(s.scol) if pattern_at(String(s.spattern), u, v, true) > 0.5 else Color(s.sleeve)

## flat jacket picture for menus: torso with two sleeves, plus a cap in the given colour
static func preview(s: Dictionary, w := 180, h := 150, cap := "") -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tx0 := w * 0.3; var tx1 := w * 0.7; var ty0 := h * 0.18; var ty1 := h * 0.96
	for y in h:
		for x in w:
			var fx := float(x); var fy := float(y)
			var col := Color(0, 0, 0, 0)
			# torso: slightly tapered towards the waist, with a V neck
			var inset := (fy - ty0) / (ty1 - ty0) * w * 0.03
			if fy >= ty0 and fy <= ty1 and fx >= tx0 + inset and fx <= tx1 - inset:
				var neck := absf(fx - w * 0.5) < (w * 0.07 - (fy - ty0) * 0.5) and fy < ty0 + h * 0.12
				if not neck:
					col = body_color(s, (fx - tx0) / (tx1 - tx0), (fy - ty0) / (ty1 - ty0))
			# sleeves: angled bands hanging from the shoulders
			for side in [-1.0, 1.0]:
				var sx: float = w * 0.5 + side * w * 0.2
				var sy := ty0 + h * 0.02
				var dx: float = (fx - sx) * side
				var dy := fy - sy
				var along := dx * 0.42 + dy * 0.91         # direction of the arm (hanging, slightly out)
				var across := -dx * 0.91 + dy * 0.42
				if along > 0.0 and along < h * 0.6 and absf(across) < w * 0.065 and dx > -w * 0.01:
					col = sleeve_color(s, (across + w * 0.065) / (w * 0.13), along / (h * 0.6))
			if cap != "":
				var cx := fx - w * 0.5; var cy := fy - h * 0.09
				if cx * cx + cy * cy * 2.2 < (w * 0.11) * (w * 0.11) and fy < h * 0.13: col = Color(cap)
			if col.a > 0.0:
				# soft shading so the jacket looks like cloth
				var shade := 0.9 + 0.1 * cos((fx / w - 0.5) * PI)
				col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

## wrap-around textures for the 3D jockey (u around the body, v top to bottom)
static func body_texture(s: Dictionary) -> ImageTexture:
	return _wrap(s, false)

static func sleeve_texture(s: Dictionary) -> ImageTexture:
	return _wrap(s, true)

static var _tex_cache := {}
static func _wrap(s: Dictionary, sleeve: bool) -> ImageTexture:
	var key := str(s) + str(sleeve)
	if _tex_cache.has(key): return _tex_cache[key]
	var n := 64
	var img := Image.create_empty(n * 2, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n * 2:
			var u := fposmod(float(x) / n, 1.0)     # the pattern repeats front and back
			var v := float(y) / n
			img.set_pixel(x, y, sleeve_color(s, u, v) if sleeve else body_color(s, u, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t

class_name Odds
## JRA parimutuel betting (勝馬投票). The public's stakes come from a "public" view of each horse's chance, the odds
## and payouts from the JRA formula.
##
## Take-out (JRA, since 7 Jun 2014): payout rate 80.0% win/place, 77.5% bracket quinella/quinella/wide,
## 75.0% exacta/trio, 72.5% trifecta (jra.go.jp/news/other/20140303.html).
## Payout per winning ticket (競馬法施行規則 付録第6): ((W + D/P) × R) / W, where W = stakes on that winning combination,
## D = stakes on all losing combinations, P = number of winning combinations (3 for place/wide, 2 for place with
## 5–7 runners, else 1), R = payout rate. Rounded down to ¥10 per ¥100; never below ¥100 (元返し).
## Sold when: win ≥2 runners, place ≥5 (top 2 only with ≤7), bracket quinella ≥9, quinella/wide/exacta ≥3,
## trio/trifecta ≥3 (wide needs ≥3).
##
## Public opinion: Monte-Carlo of the quick race model with the public's error added (they misjudge horses by more than
## the race's own randomness), plus the usual biases: fame of the jockey, last-start winners, favourite-longshot bias
## (outsiders are over-bet). Combination stakes use Harville's formula on the public win chances.
## Calibrated so the favourite wins ~32–33 % of JRA races (JRA 1番人気 勝率 ~32 %).

const TYPES := ["win", "place", "bracket", "quinella", "wide", "exacta", "trio", "trifecta"]
const NAMES := { "win": "Win 単勝", "place": "Place 複勝", "bracket": "Bracket quinella 枠連", "quinella": "Quinella 馬連",
	"wide": "Wide ワイド", "exacta": "Exacta 馬単", "trio": "Trio 3連複", "trifecta": "Trifecta 3連単" }
const RATE := { "win": 0.80, "place": 0.80, "bracket": 0.775, "quinella": 0.775, "wide": 0.775, "exacta": 0.75, "trio": 0.75, "trifecta": 0.725 }
const PICKS := { "win": 1, "place": 1, "bracket": 2, "quinella": 2, "wide": 2, "exacta": 2, "trio": 3, "trifecta": 3 }
const ORDERED := { "exacta": true, "trifecta": true }
const PUBLIC_ERR := 2.6        # race-to-race randomness the public allows for (÷ the model's noise)
const OPINION := 1.0           # the public's own misjudgement of each horse (÷ the model's noise), fixed for the race
const SIMS := 700
const SIMS_QUICK := 220       # everyday races without your horses (the card is still complete; slightly coarser odds)

static func sold(t: String, n: int) -> bool:
	match t:
		"win": return n >= 2
		"place": return n >= 5
		"bracket": return n >= 9
		_: return n >= 3

## public chances: p[i] win, q[i] in the places (top 3, or top 2 with ≤7 runners)
## sims: simulated races behind the crowd's view (fewer for everyday races nobody in the stable runs in: speed)
static func public_view(field: Array, r: Dictionary, rng: SimRng, sims := SIMS) -> Dictionary:
	var n := field.size()
	var t0: Array = []
	var bias: Array = []
	for h in field:
		t0.append(Career.quick_time(h, r, 0.0))
		var b := 0.0
		b += 0.0012 * (float(h.get("jockey", 70.0)) - 70.0) / 10.0          # famous jockeys draw money
		var hist: Array = h.c.get("history", []) if h.has("c") else []
		if not hist.is_empty() and str(hist[0].get("pos", "")) == "1": b += 0.0010   # last-start winners are backed
		if not hist.is_empty() and int(h.c.get("starts", 0)) > 0 and str(hist[0].get("pos", "")) in ["2", "3"]: b += 0.0004
		b += rng.gauss() * Career.QSIG * OPINION      # how wrong the crowd is about this horse today
		bias.append(b)
	var sig: float = Career.QSIG * PUBLIC_ERR
	var wins: Array = []; wins.resize(n); wins.fill(0.0)
	var plc: Array = []; plc.resize(n); plc.fill(0.0)
	var k_pl := 3 if n >= 8 else 2
	var ts := PackedFloat64Array(); ts.resize(n)
	var tf := PackedFloat64Array(t0)
	var bf := PackedFloat64Array(bias)
	var kk := mini(k_pl, n)
	for s in sims:
		for i in n: ts[i] = tf[i] * (1.0 - bf[i] + rng.gauss() * sig)
		# only the first places matter: pick them by scanning (the same horses a full sort puts first, much faster)
		var a0 := -1; var a1 := -1; var a2 := -1
		for i in n:
			var t := ts[i]
			if a0 < 0 or t < ts[a0]: a2 = a1; a1 = a0; a0 = i
			elif a1 < 0 or t < ts[a1]: a2 = a1; a1 = i
			elif a2 < 0 or t < ts[a2]: a2 = i
		wins[a0] += 1.0
		plc[a0] += 1.0
		if kk >= 2: plc[a1] += 1.0
		if kk >= 3: plc[a2] += 1.0
	var p: Array = []; var q: Array = []
	var tot := 0.0
	for i in n:
		# favourite-longshot bias: the public over-bets outsiders (stake share ∝ chance^0.88)
		var x := pow((wins[i] + 0.25 + 1.5 * plc[i] / float(sims)) / sims, 0.85)   # outsiders that never won a simulation are told apart by their placings
		p.append(x); tot += x
	for i in n: p[i] = p[i] / tot
	var tq := 0.0
	for i in n:
		var y := pow((plc[i] + 0.5) / (sims + 0.5 * n), 0.9)
		q.append(y); tq += y
	for i in n: q[i] = q[i] / tq
	return { "p": p, "q": q, "kpl": k_pl }

## stake share of every combination per bet type (keys: "3", "3-7", "3-7-12"; brackets for "bracket")
static func pools(view: Dictionary, n: int, brackets: Array) -> Dictionary:
	var p: Array = view.p
	var out := {}
	var win := {}; var place := {}
	for i in n: win[str(i + 1)] = p[i]; place[str(i + 1)] = view.q[i]
	out["win"] = win; out["place"] = place
	var ex := {}; var qu := {}; var tf := {}; var tr := {}; var wd := {}; var bq := {}
	for i in n:
		for j in n:
			if i == j: continue
			var pij: float = p[i] * p[j] / maxf(1e-9, 1.0 - p[i])
			ex["%d-%d" % [i + 1, j + 1]] = pij
			var a := mini(i, j); var b := maxi(i, j)
			var kq := "%d-%d" % [a + 1, b + 1]
			qu[kq] = qu.get(kq, 0.0) + pij
			var bi: int = brackets[i]; var bj: int = brackets[j]
			var kb := "%d-%d" % [mini(bi, bj), maxi(bi, bj)]
			bq[kb] = bq.get(kb, 0.0) + pij
			if n >= 3:
				for k in n:
					if k == i or k == j: continue
					var pijk: float = pij * p[k] / maxf(1e-9, 1.0 - p[i] - p[j])
					tf["%d-%d-%d" % [i + 1, j + 1, k + 1]] = pijk
					var s := [i + 1, j + 1, k + 1]; s.sort()
					var kt := "%d-%d-%d" % s
					tr[kt] = tr.get(kt, 0.0) + pijk
					# wide: every pair inside the first three
					for pr in [[s[0], s[1]], [s[0], s[2]], [s[1], s[2]]]:
						var kw := "%d-%d" % pr
						wd[kw] = wd.get(kw, 0.0) + pijk
	out["exacta"] = ex; out["quinella"] = qu; out["trifecta"] = tf; out["trio"] = tr; out["wide"] = wd; out["bracket"] = bq
	for t in out:   # normalise to stake shares
		var s := 0.0
		for k in out[t]: s += float(out[t][k])
		if s > 0.0:
			for k in out[t]: out[t][k] = float(out[t][k]) / s
	return out

static func _round_odds(x: float) -> float:
	return maxf(1.0, floorf(x * 10.0 + 1e-6) / 10.0)

## pre-race odds: single figure for win/quinella/exacta/trio/trifecta/bracket, [min, max] for place and wide
static func board(pool: Dictionary, kpl: int) -> Dictionary:
	var out := {}
	for t in pool:
		var R: float = RATE[t]
		var o := {}
		if t == "place" or t == "wide":
			var keys: Array = pool[t].keys()
			var vals: Array = []
			for k in keys: vals.append(float(pool[t][k]))
			var sorted_v := vals.duplicate(); sorted_v.sort(); sorted_v.reverse()
			var P := kpl if t == "place" else 3
			for k in keys:
				var w: float = pool[t][k]
				# others in the winning set: largest stakes give the lowest payout, smallest the highest
				var others := sorted_v.duplicate(); others.erase(w)
				var hi_set := 0.0; var lo_set := 0.0
				for m in P - 1: hi_set += float(others[m]); lo_set += float(others[others.size() - 1 - m])
				var lo := R * (w + (1.0 - w - hi_set) / P) / w
				var hi := R * (w + (1.0 - w - lo_set) / P) / w
				o[k] = [_round_odds(lo), _round_odds(hi)]
		else:
			for k in pool[t]: o[k] = _round_odds(R / maxf(1e-6, float(pool[t][k])))
		out[t] = o
	return out

## payouts per ¥100 for a finishing order (horse numbers, 1-based) — the official dividends
static func payouts(pool: Dictionary, order: Array, brackets: Array, kpl: int) -> Dictionary:
	var out := {}
	var n := order.size()
	if n < 2: return out
	var a: int = order[0]; var b: int = order[1]
	var c: int = order[2] if n >= 3 else -1
	var pay := func(t: String, win_keys: Array) -> Dictionary:
		var R: float = RATE[t]
		var W := 0.0
		for k in win_keys: W += float(pool[t].get(k, 0.0))
		var D := 1.0 - W
		var res := {}
		for k in win_keys:
			var w := maxf(1e-6, float(pool[t].get(k, 0.0)))
			res[k] = int(maxf(100.0, floorf(R * (w + D / win_keys.size()) / w * 10.0 + 1e-6) * 10.0))
		return res
	out["win"] = pay.call("win", [str(a)])
	if pool.has("place") and n >= 5:
		var pk := [str(a), str(b)]
		if kpl == 3 and c > 0: pk.append(str(c))
		out["place"] = pay.call("place", pk)
	if n >= 9: out["bracket"] = pay.call("bracket", ["%d-%d" % [mini(brackets[a - 1], brackets[b - 1]), maxi(brackets[a - 1], brackets[b - 1])]])
	out["quinella"] = pay.call("quinella", ["%d-%d" % [mini(a, b), maxi(a, b)]])
	out["exacta"] = pay.call("exacta", ["%d-%d" % [a, b]])
	if c > 0:
		var s := [a, b, c]; s.sort()
		out["wide"] = pay.call("wide", ["%d-%d" % [s[0], s[1]], "%d-%d" % [s[0], s[2]], "%d-%d" % [s[1], s[2]]])
		out["trio"] = pay.call("trio", ["%d-%d-%d" % s])
		out["trifecta"] = pay.call("trifecta", ["%d-%d-%d" % [a, b, c]])
	return out

## the key a bet's picks make for its type (picks are horse numbers, or bracket numbers for "bracket")
static func key_of(t: String, picks: Array) -> String:
	var s := picks.duplicate()
	if not ORDERED.has(t): s.sort()
	var parts: PackedStringArray = []
	for x in s: parts.append(str(int(x)))
	return "-".join(parts)

class_name Auction
## Step 4C — Japan's real sale calendar (JBBA 2025 summary; JRHA, HBA). Our world is about a tenth the size, so
## catalogues are smaller, but prices follow the real ones:
##   HBA Training Sale (2yo, late May, Sapporo)          ~¥7M average
##   JRHA Select Sale (mid July: yearlings, then foals)   ~¥65–70M average, median ~¥50M, ~94 % sold
##   HBA Selection Sale (late July, yearlings)            ~¥18M average
##   HBA Summer Sale (mid–late August, yearlings)         ~¥7.8M average, ~80 % sold
##   HBA Autumn Sale (October, yearlings)                 ~¥4M average (estimate)
##   Northern Horse Park Mixed Sale (November: foals and broodmares; date approximate)
## Price model: a horse's market value comes from its sire's fee (Kitasan Black yearlings averaged ¥197M at
## a ¥25M fee — about 8×; ¥1–3M sires sell for ~4× fee at the Summer Sale), the dam's record and what buyers
## can see of the horse itself. Each bidder values a lot within ±25 % of that; the second-highest bidder sets
## the price (English auction). Lots that don't reach the reserve are bought back (主取り).
## Estimates: consignor commission 5 %; prices quoted including tax.

const SALES := [
	{ "key": "training", "name": "HBA Training Sale (2-year-olds)", "week": 21, "age": [2], "share": 0.05, "prem": 0.8, "place": "Sapporo Racecourse" },
	{ "key": "select_y", "name": "JRHA Select Sale — yearlings", "week": 28, "age": [1], "share": 0.08, "prem": 1.45, "place": "Northern Horse Park, Tomakomai" },
	{ "key": "select_f", "name": "JRHA Select Sale — foals", "week": 28, "age": [0], "share": 0.08, "prem": 1.45, "place": "Northern Horse Park, Tomakomai" },
	{ "key": "selection", "name": "HBA Selection Sale (yearlings)", "week": 30, "age": [1], "share": 0.06, "prem": 1.1, "place": "Hokkaido Sales Pavilion, Shizunai" },
	{ "key": "summer", "name": "HBA Summer Sale (yearlings)", "week": 34, "age": [1], "share": 0.32, "prem": 0.9, "place": "Hokkaido Sales Pavilion, Shizunai" },
	{ "key": "autumn", "name": "HBA Autumn Sale (yearlings)", "week": 41, "age": [1], "share": 0.12, "prem": 0.75, "place": "Hokkaido Sales Pavilion, Shizunai" },
	{ "key": "mixed", "name": "Mixed Sale (foals and broodmares)", "week": 46, "age": [0, -1], "share": 0.06, "prem": 1.0, "place": "Northern Horse Park, Tomakomai" },
]
const COMMISSION := 0.05
## real 2025 average prices (¥M, JBBA summary; Autumn and Mixed estimated): each catalogue is scaled so its expected
## average matches, while the order and spread inside it come from each horse's pedigree and looks
const AVG := { "training": 7.4, "select_y": 65.0, "select_f": 69.4, "selection": 18.1, "summer": 7.8, "autumn": 4.0, "mixed": 15.0 }
const CATALOGUE_WEEKS := 3        # the catalogue comes out three weeks before the sale

static var W: Dictionary:
	get: return Career.W

static func sale(key: String) -> Dictionary:
	for s in SALES:
		if s.key == key: return s
	return {}

## the next sale on the calendar (this week counts)
static func next_sale(from_week := -1) -> Dictionary:
	var w := int(W.week) if from_week < 0 else from_week
	for s in SALES:
		if int(s.week) >= w: return s
	return SALES[0]

static func fee_of(sire: Variant) -> float:
	if sire == null or not sire.has("c"): return 2.0
	var sd = sire.get("stud")
	if sd != null and float(sd.get("fee", 0.0)) > 0.0: return float(sd.fee)
	# dead or retired sires: what the market would have paid
	return clampf(pow(maxf(0.0, Career.rating(sire) - 55.0), 2.0) * 0.03, 0.5, 30.0)

## market value of a young horse or a mare (¥M) — what the trade thinks, not what the horse really is
static func market_value(h: Dictionary) -> float:
	var age := int(h.get("age", 0))
	if h.get("retired", false) or String(h.get("c", {}).get("status", "")) == "broodmare":
		return maxf(1.0, Stud.Game_mare_value(h))
	var s = Breeding.get_horse(h.sire)
	var d = Breeding.get_horse(h.dam)
	var fee := fee_of(s)
	var mult := 4.0 + 4.0 * clampf((fee - 1.0) / 24.0, 0.0, 1.0)      # ~4× fee for cheap sires, ~8× for the top
	var v := mult * pow(fee, 0.95)
	if d != null:
		var dc: Dictionary = d.get("c", {})
		if int(dc.get("g1", 0)) > 0: v *= 1.8
		elif int(dc.get("graded", 0)) > 0: v *= 1.35
		elif int(dc.get("wins", 0)) >= 2: v *= 1.1
	# what buyers see in the horse itself (conformation, walk, breeze): ability with scouting noise
	var est := Stud.est_rating(h) if h.has("stats") else 60.0
	v *= exp(0.045 * (est - 62.0))
	if h.sex == "F": v *= 0.8
	if age == 2: v = maxf(v * 0.6, Game.value(h))
	return clampf(v, 0.5, 900.0)

## ---------- catalogues ----------
## W.auctions: { sale week: auction } — several catalogues can be out at once (Select Sale week 28, Selection week 30)
static func week_tick() -> void:
	var w := int(W.week)
	if not W.has("auctions"): W["auctions"] = {}
	if W.has("auction"): W.erase("auction")         # old single-catalogue saves
	for k in W.auctions.keys():
		var a: Dictionary = W.auctions[k]
		if int(a.year) < int(W.year) or (int(a.year) == int(W.year) and int(a.week) < w): finish(a)   # sold without the player
	for s in SALES:
		if int(s.week) - CATALOGUE_WEEKS == w: _catalogue(s)

static func _catalogue(s: Dictionary) -> void:
	# the same week's sales share one catalogue (Select Sale: yearlings, then foals)
	var lots: Array = []
	if not W.has("auctions"): W["auctions"] = {}
	var a: Dictionary = W.auctions.get(int(s.week), {})
	if not a.is_empty() and int(a.year) == int(W.year): lots = a.lots
	var pool: Array = []
	for h in Career.active() + Breeding.mares():
		if Career._in_stable(h.id) or h.has("foreign") or h.has("abroad"): continue
		var age := int(h.get("age", 0))
		var mare: bool = h.get("retired", false) and h.sex == "F"
		var ok := false
		for ag in s.age:
			if ag == -1 and mare and age <= 16: ok = true
			elif ag >= 0 and not mare and age == ag and String(h.get("c", {}).get("status", "active")) == "active" and int(h.get("c", {}).get("starts", 0)) == 0: ok = true
		if ok and not h.get("c", {}).get("sold", {}).has(str(W.year)): pool.append(h)
	# the best go to the Select Sale, the rest spread over the other sales (with noise: not every good horse is sold)
	# (each horse's value worked out once, not once per comparison: the same order, far quicker)
	var mvs := {}
	for h in pool: mvs[int(h.id)] = market_value(h)
	pool.sort_custom(func(a, b): return mvs[int(a.id)] > mvs[int(b.id)])
	var n := int(round(pool.size() * float(s.share)))
	var start: float = { "select_y": 0.0, "select_f": 0.0, "selection": 0.08, "summer": 0.18, "autumn": 0.6, "training": 0.5, "mixed": 0.15 }.get(s.key, 0.2)
	var i0 := int(pool.size() * start)
	var picked := 0
	var i := i0
	while picked < n and i < pool.size():
		var h: Dictionary = pool[i]
		i += 1
		if Career.rng() < 0.35: continue          # kept by the breeder or sold privately
		var mv: float = mvs[int(h.id)]
		lots.append({ "id": int(h.id), "sale": s.key, "mv": snappedf(mv, 0.1), "reserve": snappedf(mv * 0.55, 0.1), "cons": "ai", "done": false, "price": 0.0, "buyer": "", "lot": 0 })
		picked += 1
	# scale to the sale's real price level (expected price ≈ 1.15 × premium × value with 3–8 bidders). Real sale prices are
	# spread much wider than pedigrees alone (Select Sale: median ¥50M, top ¥460M), so values are stretched around the
	# middle and each lot gets its own "looks on the day"
	var mine_l: Array = lots.filter(func(l): return l.sale == s.key and not l.has("k"))
	if not mine_l.is_empty():
		var lg := 0.0
		for lot in mine_l: lg += log(maxf(0.1, float(lot.mv)))
		var g := exp(lg / mine_l.size())
		var tot := 0.0
		for lot in mine_l:
			lot.mv = g * pow(maxf(0.1, float(lot.mv)) / g, 1.8) * exp(Career.gauss() * 0.3)
			tot += float(lot.mv)
		var k: float = float(AVG.get(s.key, 10.0)) / (tot / mine_l.size() * 1.15 * float(s.prem))
		for lot in mine_l:
			lot["k"] = k * float(lot.mv) / maxf(0.1, market_value(Breeding.get_horse(lot.id)))
			lot.mv = snappedf(float(lot.mv) * k, 0.1)
			lot.reserve = snappedf(float(lot.mv) * float(s.prem) * 0.9 * exp(Career.gauss() * 0.2), 0.1)     # the breeder's reserve
	# the player's consignments
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h == null or String(h.get("c", {}).get("consign", "")) != s.key: continue
		var mv := market_value(h) * k_of(lots)
		lots.append({ "id": int(id), "sale": s.key, "mv": snappedf(mv, 0.1), "reserve": float(h.c.get("reserve", snappedf(mv * 0.5, 0.1))), "cons": "player", "done": false, "price": 0.0, "buyer": "", "lot": 0 })
	for k in lots.size(): lots[k].lot = k + 1
	W.auctions[int(s.week)] = { "key": s.key, "week": int(s.week), "year": int(W.year), "lots": lots, "cur": 0, "bid": null }
	Career.log_msg("🔨 Catalogue out: %s, week %d at %s — %d lots. See Auctions." % [s.name, int(s.week), s.place, lots.size()], null)

## the sale on now, else the next catalogue that is out
## the sale's typical scale from value to price (median of its lots)
static func k_of(lots: Array) -> float:
	var ks: Array = []
	for lot in lots:
		if lot.has("k"): ks.append(float(lot.k))
	if ks.is_empty(): return 0.35
	ks.sort()
	return float(ks[ks.size() / 2])

## what a horse would fetch at a given sale (used for estimates and the consign menu)
static func sale_estimate(h: Dictionary, key: String) -> float:
	var s := sale(key)
	var a: Dictionary = W.get("auctions", {}).get(int(s.get("week", 0)), {})
	var k := k_of(a.get("lots", [])) if not a.is_empty() else 0.35
	return market_value(h) * k * float(s.get("prem", 1.0)) * 1.1

static func current() -> Dictionary:
	var best := {}
	for k in W.get("auctions", {}):
		var a: Dictionary = W.auctions[k]
		if int(a.year) != int(W.year) or int(a.week) < int(W.week): continue
		if best.is_empty() or int(a.week) < int(best.week): best = a
	return best

static func is_sale_week() -> bool:
	var a := current()
	return not a.is_empty() and int(a.week) == int(W.week) and int(a.year) == int(W.year)

## ---------- bidding ----------
static func increment(p: float) -> float:
	if p < 5.0: return 0.5
	if p < 20.0: return 1.0
	if p < 50.0: return 2.0
	if p < 200.0: return 5.0
	return 10.0

## AI bidders for a lot: 3–8 buyers, each values it within about ±25 % of the market value
static func _bidders(lot: Dictionary) -> Array:
	var s := sale(String(lot.sale))
	var n := 3 + int(floor(Career.rng() * 6.0))
	var out: Array = []
	for i in n:
		out.append({ "name": "Bidder %d" % (10 + int(floor(Career.rng() * 290.0))), "max": float(lot.mv) * float(s.get("prem", 1.0)) * exp(Career.gauss() * 0.25) })
	return out

## start live bidding on a lot (the player is in the room)
static func open_lot(i: int) -> Dictionary:
	var a := current()
	var lot: Dictionary = a.lots[i]
	var b := { "i": i, "price": snappedf(maxf(0.5, float(lot.mv) * 0.35), 0.5), "high": "", "bidders": _bidders(lot), "log": [] }
	a.bid = b
	_ai_round(b, lot)
	return b

## AI bidders answer: the one with the most room left goes one step higher
static func _ai_round(b: Dictionary, lot: Dictionary) -> bool:
	var nxt := float(b.price) + (increment(float(b.price)) if b.high != "" else 0.0)
	var best = null
	for x in b.bidders:
		if x.name != b.high and float(x.max) >= nxt and (best == null or float(x.max) > float(best.max)): best = x
	if best == null: return false
	b.price = nxt
	b.high = best.name
	b.log.insert(0, "%s bids %s" % [best.name, Game.money(nxt)])
	return true

## respond: the CPU bidders answer at once (the 2D page); the 3D sale ring paces their answers itself
static func player_bid(respond := true) -> bool:
	var a := current()
	var b = a.get("bid")
	if b == null: return false
	var nxt := float(b.price) + increment(float(b.price))
	if nxt > Finance.money() + Finance.borrow_limit(): return false
	b.price = nxt
	b.high = "you"
	b.log.insert(0, "You bid %s" % Game.money(nxt))
	if respond: _ai_round(b, a.lots[b.i])
	return true

## the hammer falls (the player stops bidding): sold to the high bidder, or bought back below the reserve
static func hammer() -> Dictionary:
	var a := current()
	var b = a.get("bid")
	if b == null: return {}
	var lot: Dictionary = a.lots[b.i]
	while b.high != "you" and _ai_round(b, lot): pass
	_settle(lot, float(b.price), String(b.high))
	a.bid = null
	return lot

## a lot sold without the player (or the rest of the sale)
static func auto_lot(lot: Dictionary) -> void:
	var bs := _bidders(lot)
	var vals: Array = []
	for x in bs: vals.append(float(x.max))
	vals.sort()
	var price := float(vals[vals.size() - 2]) if vals.size() >= 2 else float(vals[0]) * 0.8
	price = snappedf(maxf(0.5, price), increment(price))
	_settle(lot, price, String(bs[vals.size() - 1].name) if true else "")

static func _settle(lot: Dictionary, price: float, buyer: String) -> void:
	var h = Breeding.get_horse(lot.id)
	lot.done = true
	if h == null: return
	if not h.has("c"): h["c"] = {}
	if not h.c.has("sold"): h.c["sold"] = {}
	if buyer == "" or price < float(lot.reserve):
		lot.price = price; lot.buyer = "bought back"
		if lot.cons == "player": Career.log_msg("%s was bought back at %s (reserve %s not reached)." % [h.name, Game.money(price), Game.money(float(lot.reserve))], h)
		h.c.erase("consign")
		return
	lot.price = price; lot.buyer = buyer
	h.c.sold[str(W.year)] = price
	if buyer != "you":                 # a CPU owner bought it
		var ob := Owners.buyer_for(h, price)
		if not ob.is_empty():
			h["ownerId"] = int(ob.id)
			lot.buyer = String(ob.name)
	if buyer == "you":
		if lot.cons == "player": return
		Career.add_to_stable(int(h.id))
		h.erase("ownerId")
		h.c.erase("owner")
		Career.ledger("Bought at the %s: %s" % [sale(String(lot.sale)).name, h.name], -price, "purchase")
		Career.log_msg("🔨 You bought %s for %s." % [h.name, Game.money(price)], h)
	elif lot.cons == "player":
		W.stable.erase(int(h.id))
		h.c["owner"] = "ai"
		h.c.erase("consign")
		Career.ledger("Sold at the %s: %s" % [sale(String(lot.sale)).name, h.name], price * (1.0 - COMMISSION), "sale")
		Career.log_msg("🔨 %s sold for %s at the %s (5%% commission)." % [h.name, Game.money(price), sale(String(lot.sale)).name], h)

## finish the sale: every remaining lot, then the results table
static func finish(a: Dictionary) -> void:
	if a.get("bid") != null: hammer()
	for lot in a.lots:
		if not lot.done: auto_lot(lot)
	var res := {}
	for lot in a.lots:
		var k := String(lot.sale)
		if not res.has(k): res[k] = { "n": 0, "sold": 0, "gross": 0.0, "top": [] }
		var r: Dictionary = res[k]
		r.n += 1
		if lot.buyer != "bought back":
			r.sold += 1; r.gross += float(lot.price)
			r.top.append([float(lot.price), int(lot.id)])
	if not W.has("sales"): W["sales"] = {}
	var ys := str(int(a.year))
	if not W.sales.has(ys): W.sales[ys] = {}
	for k in res:
		var r: Dictionary = res[k]
		r.top.sort_custom(func(x, y): return x[0] > y[0])
		r.top = r.top.slice(0, 5)
		W.sales[ys][k] = r
		Career.log_msg("%s: %d of %d sold, average %s, top %s." % [sale(k).name, r.sold, r.n, Game.money(r.gross / maxf(1, r.sold)), Game.money(r.top[0][0]) if not r.top.is_empty() else "-"], null)
	W.get("auctions", {}).erase(int(a.week))

## the player's horse can go into the next suitable sale
static func eligible_sales(h: Dictionary) -> Array:
	var out: Array = []
	var age := int(h.get("age", 0))
	var mare: bool = h.get("retired", false) and h.sex == "F"
	for s in SALES:
		if int(s.week) - CATALOGUE_WEEKS < int(W.week): continue
		for ag in s.age:
			if (ag == -1 and mare) or (ag >= 0 and not mare and age == ag and int(h.get("c", {}).get("starts", 0)) == 0 and String(h.get("c", {}).get("status", "")) == "active"):
				out.append(s); break
	return out

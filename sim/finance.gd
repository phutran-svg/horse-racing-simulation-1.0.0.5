class_name Finance
## Step 4A — money. Everything in million yen (¥M). The cash balance is W.money; every movement goes
## through Career.ledger(text, amount, cat) so the Finances screen can build statements by category.
##
## Real figures used (JRA, see claude/step4-plan.md):
##  * Prize split: owner 80 %, trainer 10 %, jockey 5 %, groom 5 % (places 1–5).
##  * Training fee (預託料) at Miho/Ritto: about ¥700,000 per horse per month (JRA owner guide).
##  * Farm keep for young horses before they go into training: ¥200–300k a month (mynavi 2012).
##  * Running allowance (出走奨励金) for 6th–10th: 8/7/6/4/2 % of the winner's prize in open/graded races,
##    8/7/6/4 % for 6th–9th in other races (JRA owner pages).
##  * JRA owner licence: income ≥ ¥20M in each of the last two years and assets ≥ ¥100M.
## Estimates (no public number found): special running allowance per start, breeder prize %, farm running costs.

const SPLIT := { "owner": 0.80, "trainer": 0.10, "jockey": 0.05, "groom": 0.05 }
const FEE_TRAINING := 0.70        # per horse per month in a JRA stable
const FEE_SPELLING := 0.30        # resting at an outside farm (injured / long break)
const FARM_FOAL := 0.10           # foal at foot / weanling
const FARM_YEARLING := 0.25       # yearling and pre-training (育成)
const FARM_MARE := 0.15           # broodmare boarded at a farm
const FARM_STALLION := 0.0        # stallions: the stud farm keeps them, the owner gets fees
const RUN_ALLOW := 0.45           # estimate: special running allowance per start (paid to the owner)
const ENCOURAGE_OPEN := [0.08, 0.07, 0.06, 0.04, 0.02]   # 6th–10th, open and graded races
const ENCOURAGE_OTHER := [0.08, 0.07, 0.06, 0.04]        # 6th–9th, other races
const BREEDER_PRIZE := 0.06       # estimate: breeder prize as a share of the horse's prize money (places 1–5)
const LOAN_RATE := 0.025          # yearly interest
const LOAN_LTV := 0.5             # you can borrow up to half your assets

# trainer business (per horse in the yard, per month): fee in, staff/feed/costs out
const TR_STAFF := 0.42            # one groom per two horses + assistant trainers (JRA grooms are well paid)
const TR_FEED := 0.10
const TR_OTHER := 0.05

const CATS := {
	"prize": "Prize money", "allow": "Running allowances", "breeder": "Breeder prizes", "trainer_fee": "Training fees received",
	"sale": "Horse sales", "stud_in": "Stud fees received", "business": "Business income", "salary": "Salary",
	"fee": "Training fees", "farm": "Farm and keep", "staff": "Staff and stable costs", "stud": "Stud fees",
	"purchase": "Horse purchases", "travel": "Travel and shipping", "betting": "Betting", "vet": "Vet bills", "loan": "Loans", "interest": "Interest",
	"licence": "Licences and fees", "other": "Other", "capital": "Starting capital",
}
const INCOME_CATS := ["prize", "allow", "breeder", "trainer_fee", "sale", "stud_in", "business", "salary"]

static var W: Dictionary:
	get: return Career.W

static func P() -> Dictionary: return W.get("player", {})
static func role() -> String: return String(P().get("role", "owner"))
static func money() -> float: return float(W.get("money", 0.0))
static func debt() -> float: return float(P().get("debt", 0.0))

## does the player own this horse (owner/breeder) — trainers only train other people's horses
static func owns(h: Dictionary) -> bool:
	return Career._in_stable(h.id) and String(h.get("c", {}).get("owner", "")) == ""

## ---------- race money ----------
## called from Career.run_race for every runner; pays the player's share
static func race_payout(r: Dictionary, h: Dictionary, pos: int, field_n: int, prize: float) -> void:
	var p := P()
	if p.is_empty(): return
	var share := 0.0
	if pos <= 5: share = prize * Career.PLACE_SHARE[pos - 1]
	var enc := 0.0
	var tbl: Array = ENCOURAGE_OPEN if r.cls in ["OP", "G3", "G2", "G1"] else ENCOURAGE_OTHER
	if pos >= 6 and pos - 6 < tbl.size(): enc = prize * float(tbl[pos - 6])
	var mine := Career._in_stable(h.id)
	var rl := role()
	if mine and (rl == "owner" or rl == "breeder") and owns(h):
		if share > 0.0: Career.ledger("Prize: %s — %s (%s)" % [h.name, r.name, _ord(pos)], share * SPLIT.owner, "prize")
		var allow := RUN_ALLOW + enc
		if not Intl.is_intl(r): Career.ledger("Running allowance: %s — %s" % [h.name, r.name], allow, "allow")
	elif mine and rl == "trainer" and p.get("licensed", false):
		if share > 0.0: Career.ledger("Trainer's 10%%: %s — %s (%s)" % [h.name, r.name, _ord(pos)], share * SPLIT.trainer, "prize")
	# a groom gets 5 % of the prize of the horses in their care (進上金)
	if rl == "trainer" and not p.get("licensed", false) and p.get("care", []).has(int(h.id)) and share > 0.0:
		Career.ledger("Groom's 5%%: %s — %s (%s)" % [h.name, r.name, _ord(pos)], share * SPLIT.groom, "prize")
	# breeder prize to the farm that bred the horse
	if share > 0.0 and h.get("bredBy", "") == "player" and has_farm():
		Career.ledger("Breeder prize: %s — %s (%s)" % [h.name, r.name, _ord(pos)], share * BREEDER_PRIZE, "breeder")

static func has_farm() -> bool:
	return role() == "breeder" or P().get("farm", false)

static func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]: return "%dth" % n
	return "%d%s" % [n, ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]]

## ---------- monthly bills ----------
## what each of the player's horses costs per month (owner/breeder view)
static func keep_cost(h: Dictionary) -> Array:   # [amount, label]
	var c: Dictionary = h.get("c", {})
	var st := String(c.get("status", "active"))
	var age := int(h.get("age", 0))
	if st == "stud": return [FARM_STALLION, "at stud"]
	if st == "broodmare" or h.get("retired", false):
		return [FARM_MARE * (0.8 if has_farm() else 1.0), "broodmare"]
	if st != "active": return [0.0, ""]
	if age <= 0: return [FARM_FOAL * (0.8 if has_farm() else 1.0), "foal"]
	if age == 1 or (age == 2 and Career.W.week < 14 and int(c.get("starts", 0)) == 0): return [FARM_YEARLING * (0.8 if has_farm() else 1.0), "pre-training"]
	if int(c.get("out", 0)) > 4: return [FEE_SPELLING, "resting at a farm"]
	return [FEE_TRAINING, "in training"]

static func monthly_preview() -> Dictionary:
	var lines: Array = []
	var total := 0.0
	var rl := role()
	var p := P()
	if rl == "owner" or rl == "breeder":
		var by := {}
		for id in W.stable:
			var h = Breeding.get_horse(id)
			if h == null or not owns(h): continue
			var kc := keep_cost(h)
			if float(kc[0]) <= 0.0: continue
			var k: String = kc[1]
			if not by.has(k): by[k] = [0, 0.0]
			by[k][0] += 1; by[k][1] += float(kc[0])
		for k in by:
			lines.append(["%s × %d" % [k.capitalize(), by[k][0]], -float(by[k][1])]); total -= float(by[k][1])
		if has_farm():
			var fixed := farm_fixed()
			lines.append(["Farm running costs", -fixed]); total -= fixed
		if rl == "owner" and float(p.get("business", 0.0)) > 0.0:
			var b := float(p.business) / 12.0
			lines.append(["Business income", b]); total += b
	elif rl == "trainer":
		if p.get("licensed", false):
			var n: int = W.stable.size()
			var inc: float = n * FEE_TRAINING
			var cost: float = n * (TR_STAFF + TR_FEED + TR_OTHER) + 0.6   # + office / box rent
			lines.append(["Training fees from owners × %d" % n, inc]); lines.append(["Staff, feed and stable costs", -cost])
			total += inc - cost
		else:
			var sal := salary()
			if sal > 0.0: lines.append(["Salary (%s)" % job_name(), sal]); total += sal
	if debt() > 0.0:
		var i := debt() * LOAN_RATE / 12.0
		lines.append(["Loan interest", -i]); total -= i
	return { "lines": lines, "total": total }

static func farm_fixed() -> float:
	var n := 0
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h != null and owns(h): n += 1
	return 0.8 + 0.05 * n      # estimate: farm staff, land, machinery for a small Hidaka farm

static func salary() -> float:
	match String(P().get("job", "")):
		"student": return 0.0
		"groom": return 0.42        # estimate: JRA grooms ~¥5M a year plus the 5 % prize share
		"assistant": return 0.55
	return 0.0

static func job_name() -> String:
	return { "student": "racing school student", "groom": "groom", "assistant": "assistant trainer", "trainer": "trainer", "owner": "owner", "breeder": "breeder" }.get(String(P().get("job", "")), "")

## run at the end of each month
static func settle_month(month: int) -> void:
	var p := P()
	if p.is_empty() or p.get("over", false): return
	var rl := role()
	if rl == "owner" or rl == "breeder":
		var by := {}
		for id in W.stable:
			var h = Breeding.get_horse(id)
			if h == null or not owns(h): continue
			var kc := keep_cost(h)
			if float(kc[0]) <= 0.0: continue
			var cat := "fee" if kc[1] in ["in training", "resting at a farm"] else "farm"
			by[cat] = float(by.get(cat, 0.0)) + float(kc[0])
		if by.has("fee"): Career.ledger("Training fees (%s)" % _mname(month), -float(by.fee), "fee")
		if by.has("farm"): Career.ledger("Farm keep (%s)" % _mname(month), -float(by.farm), "farm")
		if has_farm(): Career.ledger("Farm running costs (%s)" % _mname(month), -farm_fixed(), "staff")
		if rl == "owner" and float(p.get("business", 0.0)) > 0.0:
			Career.ledger("Business income (%s)" % _mname(month), float(p.business) / 12.0, "business")
	elif rl == "trainer":
		if p.get("licensed", false):
			var n: int = W.stable.size()
			if n > 0: Career.ledger("Training fees from owners × %d (%s)" % [n, _mname(month)], n * FEE_TRAINING, "trainer_fee")
			Career.ledger("Staff, feed and stable costs (%s)" % _mname(month), -(n * (TR_STAFF + TR_FEED + TR_OTHER) + 0.6), "staff")
		else:
			var sal := salary()
			if sal > 0.0: Career.ledger("Salary (%s)" % _mname(month), sal, "salary")
	if debt() > 0.0:
		Career.ledger("Loan interest (%s)" % _mname(month), -debt() * LOAN_RATE / 12.0, "interest")
	_check_solvency()

static func _mname(m: int) -> String:
	return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][clampi(m, 1, 12) - 1]

## ---------- assets and loans ----------
static func assets() -> float:
	var a := money()
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h != null and owns(h): a += Game.value(h)
	if P().get("farm", false) or role() == "breeder": a += float(P().get("farmValue", 0.0))
	return a - debt()

static func borrow_limit() -> float:
	return maxf(0.0, (assets() + debt()) * LOAN_LTV - debt())

static func borrow(amount: float) -> bool:
	amount = snappedf(amount, 0.1)
	if amount <= 0.0 or amount > borrow_limit() + 0.01: return false
	P()["debt"] = debt() + amount
	Career.ledger("Bank loan", amount, "loan")
	return true

static func repay(amount: float) -> bool:
	amount = minf(snappedf(amount, 0.1), debt())
	if amount <= 0.0 or amount > money(): return false
	P()["debt"] = debt() - amount
	Career.ledger("Loan repayment", -amount, "loan")
	return true

## negative cash: borrow what the bank allows, then sell horses (most valuable first), then game over
static func _check_solvency() -> void:
	var p := P()
	if money() >= 0.0: p["redWeeks"] = 0; return
	var need := -money() + 5.0
	if borrow_limit() >= need:
		borrow(need)
		Career.log_msg("⚠ Your bank covered an overdraft with a ¥%.1fM loan." % need, null)
		return
	var mine: Array = []
	for id in W.stable:
		var h = Breeding.get_horse(id)
		if h != null and owns(h): mine.append(h)
	mine.sort_custom(func(a, b): return Game.value(a) > Game.value(b))
	for h in mine:
		if money() >= 0.0: break
		var price := snappedf(Game.value(h) * 0.7, 0.1)
		sell(h, price, "forced sale to cover debts")
	if money() < 0.0:
		p["over"] = true
		Career.log_msg("✖ Bankrupt: you can no longer pay your bills. Your licence has been withdrawn.", null)

## ---------- buying and selling (private sales; auctions come in 4C) ----------
static func sell(h: Dictionary, price: float, why := "private sale") -> void:
	W.stable.erase(int(h.id))
	if h.has("c"): h.c["owner"] = "ai"
	var ob := Owners.buyer_for(h, price)
	if not ob.is_empty(): h["ownerId"] = int(ob.id)
	Career.ledger("Sold %s (%s)" % [h.name, why], price, "sale")
	Career.log_msg("%s sold for %s (%s)." % [h.name, Game.money(price), why], h)

static func buy(h: Dictionary, price: float) -> bool:
	if price > money(): return false
	Career.add_to_stable(int(h.id))
	h.c.erase("owner")
	h.erase("ownerId")
	Career.ledger("Bought %s" % h.name, -price, "purchase")
	Career.log_msg("You bought %s for %s." % [h.name, Game.money(price)], h)
	return true

## asking price for a horse from another stable / offer for one of yours (± a little negotiation noise)
static func ask_price(h: Dictionary) -> float:
	return snappedf(maxf(1.0, Game.value(h) * 1.15), 0.1)

static func offer_price(h: Dictionary) -> float:
	var k := 0.8 + 0.15 * fposmod(float(int(h.id) * 7919 + int(W.week) * 31), 100.0) / 100.0
	return snappedf(maxf(0.5, Game.value(h) * k), 0.1)

## horses other stables would sell (a rotating list, changes every 4 weeks)
static func market(kind := "all") -> Array:
	var out: Array = []
	var seed := int(W.year) * 100 + int(W.week) / 4
	for h in Career.active():
		if Career._in_stable(h.id) or h.has("foreign"): continue
		var a := int(h.age)
		if kind == "young" and a > 1: continue
		if kind == "racing" and (a < 2 or int(h.c.get("starts", 0)) == 0 and a > 2): continue
		if a > 6: continue
		var hsh := (int(h.id) * 2654435761 + seed * 40503) % 1000
		if hsh < 60: out.append(h)      # ~6 % of horses are for sale at any time
	out.sort_custom(func(a, b): return Game.value(a) > Game.value(b))
	return out.slice(0, 80)

## ---------- statements ----------
static func statement(year: int) -> Dictionary:
	var by: Dictionary = W.get("finYear", {}).get(year, {})
	var inc := 0.0
	var exp := 0.0
	for k in by:
		if k == "loan" or k == "capital": continue
		if float(by[k]) >= 0.0: inc += float(by[k])
		else: exp += float(by[k])
	return { "by": by, "income": inc, "costs": exp, "net": inc + exp }

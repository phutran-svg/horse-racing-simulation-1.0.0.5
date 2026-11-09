class_name HorseTable
extends Tree
## FM-style horse list. Click a column title to sort; double-click a row to open the horse.

signal horse_opened(id: int)

const COLS := {
	"name": ["Name", 210, true], "age": ["Age", 46, false], "sex": ["Sex", 56, false], "gene": ["Gene", 52, false],
	"style": ["Style", 100, false], "dist": ["Best", 110, false], "surf": ["Surface", 90, false], "tier": ["Class", 120, false],
	"ab": ["Ability", 92, false], "pot": ["Potential", 92, false], "form": ["Form", 110, false], "status": ["Status", 120, false],
	"starts": ["Runs", 50, false], "wins": ["Wins", 50, false], "earn": ["Earnings", 96, false], "value": ["Value", 90, false],
	"sire": ["Sire", 160, false], "owner": ["Owner", 120, false],
	"fee": ["Fee", 80, false], "book": ["Book", 70, false], "line": ["Sire line", 170, false], "runners": ["Runners", 70, false],
	"winners": ["Winners", 90, false], "sw": ["Stakes wnrs", 110, false], "aei": ["AEI", 56, false], "mstat": ["Breeding status", 330, true], "country": ["Country", 80, false], "report": ["Staff report", 330, true],
}
var cols: Array = []
var rows: Array = []
var sort_col := ""
var sort_desc := true

func _init(col_keys: Array = ["name", "age", "sex", "style", "tier", "ab", "form", "status"]) -> void:
	cols = col_keys
	hide_root = true
	column_titles_visible = true
	select_mode = Tree.SELECT_ROW
	columns = cols.size()
	for i in cols.size():
		var c: Array = COLS[cols[i]]
		set_column_title(i, c[0])
		set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		set_column_custom_minimum_width(i, c[1])
		set_column_expand(i, c[2])
	item_activated.connect(func():
		var it := get_selected()
		if it != null: horse_opened.emit(int(it.get_metadata(0))))
	column_title_clicked.connect(func(col: int, _b: int):
		var k: String = cols[col]
		if sort_col == k: sort_desc = not sort_desc
		else:
			sort_col = k; sort_desc = k != "name"
		set_horses(rows))
	size_flags_vertical = Control.SIZE_EXPAND_FILL

static func form_text(h: Dictionary) -> String:
	var hist: Array = h.get("c", {}).get("history", [])
	var out: PackedStringArray = []
	for x in hist.slice(0, 5):
		var p = x.pos
		out.append("0" if str(p) == "DNF" else (str(p) if int(p) < 10 else "0"))
	return "-".join(out) if not out.is_empty() else "-"

func _key(h: Dictionary, k: String) -> Variant:
	var c: Dictionary = h.get("c", {})
	match k:
		"name": return String(h.name)
		"age": return int(h.get("age", 0))
		"ab": return Career.rating(Game.view(h))
		"fee": return float(Stud.stud(h).fee) if h.get("stud") != null else 0.0
		"country": return String(h.get("abroad", "Japan"))
		"book": return int(Stud.stud(h).book) if h.get("stud") != null else 0
		"runners": return int(Stud.progeny(h).runners)
		"winners": return int(Stud.progeny(h).winners)
		"sw": return int(Stud.progeny(h).graded)
		"aei": return float(Stud.progeny(h).aei)
		"pot": return Game.potential_stars(h)
		"starts": return int(c.get("starts", 0))
		"wins": return int(c.get("wins", 0))
		"earn": return float(c.get("earn", 0.0))
		"value": return Game.value(h)
		"tier": return Career.TIERS.size() - Career.TIERS.find(Career.tier_of(h))
		"dist": return Career.best_dist(Game.view(h))
	return _text(h, k)

func _text(h: Dictionary, k: String) -> String:
	var c: Dictionary = h.get("c", {})
	match k:
		"name": return "%s %s" % [h.name, "★" if Game.is_mine(h) else ""]
		"age": return str(int(h.get("age", 0)))
		"sex": return Game.sex_word(h)
		"gene": return h.gene
		"style": return RaceEngine.STYLES[h.style].label
		"dist": return "%s %dm" % [Game.distance_label(h).split(" ")[0], int(Career.best_dist(Game.view(h)) / 100.0) * 100]
		"fee": return Stud.fee_text(h) if h.get("stud") != null else "-"
		"country": return String(h.get("abroad", "Japan"))
		"report": return Game.staff_report(h)
		"book": return "%d / %d" % [int(Stud.stud(h).book), int(Stud.stud(h).cap)] if h.get("stud") != null else "-"
		"line": return Stud.sire_line(h) + " line"
		"runners": return str(int(Stud.progeny(h).runners))
		"winners": var p := Stud.progeny(h); return "%d (%d%%)" % [int(p.winners), roundi(100.0 * p.winners / maxf(1.0, p.runners))]
		"sw": var p := Stud.progeny(h); return "%d · G1 %d" % [int(p.graded), int(p.g1)]
		"aei": var p := Stud.progeny(h); return "%.2f" % p.aei if p.runners > 0 else "-"
		"mstat": return Stud.mare_status(h) if h.get("repro") != null else "-"
		"surf": return Game.surface_label(h)
		"tier": return Career.tier_of(h)
		"ab": return UiTheme.stars(Game.ability_stars(h))
		"pot": return UiTheme.stars(Game.potential_stars(h))
		"form": return form_text(h)
		"status": return Game.status_text(h)
		"starts": return str(int(c.get("starts", 0)))
		"wins": return str(int(c.get("wins", 0)))
		"earn": return Game.money(float(c.get("earn", 0.0)))
		"value": return Game.money(Game.value(h))
		"sire": return Game.horse(h.sire).get("name", "-") if h.get("sire") != null else "-"
		"owner":
			var o := String(h.get("c", {}).get("owner", ""))
			if Game.is_mine(h): return o if o != "" else Career.W.get("stable_name", "You")
			return Owners.name_of(h)
	return ""

var limit := 0            # show at most this many rows (after sorting); 0 = all
signal limited(shown: int, total: int)

func set_horses(list: Array) -> void:
	rows = list
	var show := list.duplicate()
	if sort_col != "":
		# sort keys worked out once per horse (not once per comparison: big lists stay quick)
		var k := sort_col
		var d := sort_desc
		var keyed: Array = []
		for i in show.size(): keyed.append([_key(show[i], k), i])
		keyed.sort_custom(func(a, b): return (a[0] > b[0] if d else a[0] < b[0]) if a[0] != b[0] else a[1] < b[1])
		var sorted: Array = []
		for x in keyed: sorted.append(show[x[1]])
		show = sorted
	if limit > 0 and show.size() > limit: show = show.slice(0, limit)
	limited.emit(show.size(), list.size())
	clear()
	var root := create_item()
	for h in show:
		var it := create_item(root)
		it.set_metadata(0, int(h.id))
		for i in cols.size():
			var k: String = cols[i]
			it.set_text(i, _text(h, k))
			if k == "ab" or k == "pot": it.set_custom_color(i, UiTheme.ACC)
			if k == "name" and Game.is_mine(h): it.set_custom_color(i, UiTheme.MINE)
			if k == "status" and (str(_text(h, k)).begins_with("Injured") or str(_text(h, k)).begins_with("Severe")): it.set_custom_color(i, UiTheme.BAD)
			elif k == "status" and str(_text(h, k)).begins_with("Caution"): it.set_custom_color(i, UiTheme.ACC)

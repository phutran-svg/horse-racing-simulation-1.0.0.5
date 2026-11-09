class_name RatingsPage
extends VBoxContainer
## Ratings tab: JPN Thoroughbred Ranking · Race ratings & grading · G1 pre-race ratings · World (overseas step).
## All figures are official ratings in pounds (JRA / IFHA style).

var shell
var sub := "jpn"
var year := -1

func setup(game_shell, arg) -> RatingsPage:
	shell = game_shell
	if arg is Array and arg.size() > 0:
		sub = arg[0]
		if arg.size() > 1 and arg[1] != null: year = int(arg[1])
	if year < 0: year = int(Career.W.year)
	add_theme_constant_override("separation", 10)
	shell._set_title("Ratings", "Official ratings in pounds · JRA handicappers / IFHA")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 22)
	for t in [["jpn", "JPN Thoroughbred Ranking"], ["races", "Race ratings & grades"], ["pre", "G1 pre-race ratings"], ["world", "World rankings"]]:
		var b := Button.new()
		b.text = t[1]
		b.flat = true
		b.add_theme_color_override("font_color", UiTheme.ACC if t[0] == sub else UiTheme.DIM)
		b.add_theme_color_override("font_hover_color", UiTheme.STRONG)
		b.pressed.connect(func(): shell.open("ratings", [t[0], year]))
		tabs.add_child(b)
	add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	match sub:
		"jpn": _jpn(v)
		"races": _races(v)
		"pre": _pre(v)
		"world": _world(v)
	return self

func _card(title: String, parent: Control, expand := true) -> VBoxContainer:
	var pc := PanelContainer.new()
	if expand: pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	pc.add_child(v)
	if title != "": v.add_child(UiTheme.section(title))
	return v

static func rt_text(rt) -> String:
	if rt == null: return "-"
	return "%d %s%s" % [int(rt.r), str(rt.cat), "" if str(rt.surf) == "T" else " (" + str(rt.surf) + ")"]

func _table(cols: Array, widths: Array) -> Tree:
	var t := Tree.new()
	t.hide_root = true
	t.columns = cols.size()
	t.column_titles_visible = true
	for i in cols.size():
		t.set_column_title(i, cols[i])
		if widths[i] > 0:
			t.set_column_custom_minimum_width(i, widths[i]); t.set_column_expand(i, false)
		else: t.set_column_expand(i, true)
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null and it.get_metadata(0) != null: shell.open_horse(int(it.get_metadata(0))))
	return t

# ---------------- JPN Thoroughbred Ranking ----------------
func _jpn(v: VBoxContainer) -> void:
	var cur := int(Career.W.year)
	var yrs: Array = [cur]
	for k in Career.W.get("rankings", {}): yrs.append(int(k))
	yrs.sort(); yrs.reverse()
	var bar := HBoxContainer.new()
	bar.add_child(UiTheme.label("Year:", 13, UiTheme.DIM))
	for y in yrs:
		if y < cur - 6: continue
		var b := Button.new()
		b.text = str(y) + (" (so far)" if y == cur else "")
		b.flat = y != year
		b.pressed.connect(func(): shell.open("ratings", ["jpn", y]))
		bar.add_child(b)
	v.add_child(bar)
	var g: Dictionary = Ratings.jpn_ranking(year) if year == cur else Career.W.rankings.get(str(year), {})
	v.add_child(UiTheme.dim_label("Horses rated %d lb or more in Japan in %d, by age group. A horse's rating is its best performance of the year; category S 1000–1300 m · M 1301–1899 · I 1900–2100 · L 2101–2700 · E 2701+. Fillies and mares are rated on their own scale (add 4 lb to compare with colts). Double-click a horse to open it." % [int(Ratings.PUBLISH_JPN), year], 12))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for grp in ["2yo", "3yo Turf", "3yo Dirt", "4yo+ Turf", "4yo+ Dirt"]:
		var arr: Array = g.get(grp, [])
		var c := _card("%s  (%d)" % [grp, arr.size()], grid)
		c.custom_minimum_size = Vector2(560, 0)
		var t := _table(["#", "Rating", "Horse", "Sex", "Race"], [34, 90, 0, 40, 0])
		t.custom_minimum_size.y = 34 + 26 * mini(10, maxi(1, arr.size()))
		var root := t.create_item()
		var rank := 0
		var last := -1.0
		for i in mini(30, arr.size()):
			var e: Dictionary = arr[i]
			if float(e.r) != last: rank = i + 1; last = float(e.r)
			var it := t.create_item(root)
			it.set_text(0, str(rank))
			it.set_text(1, "%d %s" % [int(e.r), str(e.cat)])
			it.set_text(2, str(e.name))
			it.set_text(3, "F" if e.sex == "F" else "C")
			it.set_text(4, str(e.race))
			it.set_metadata(0, int(e.id))
			if Career.W.stable.has(int(e.id)):
				for k in 5: it.set_custom_color(k, UiTheme.ACC)
		if arr.is_empty(): c.add_child(UiTheme.dim_label("Nobody rated %d+ yet." % int(Ratings.PUBLISH_JPN), 12))
		else: c.add_child(t)

# ---------------- race ratings & grading ----------------
func _races(v: VBoxContainer) -> void:
	var c := _card("Annual race ratings (average of the first four's ratings; fillies +4 lb in open races)", v)
	c.add_child(UiTheme.dim_label("Grade parameter: G1 115 · G2 110 · G3 105 lb (5 lb lower for 2-year-old and fillies' races). A race whose 3-year average falls more than 5 lb below its parameter is downgraded; one that reaches the next grade's parameter is promoted (IFHA / JRA grading review, every December).", 12))
	var t := _table(["Race", "Grade", "Last", "2nd last", "3rd last", "3-yr avg", "Parameter", "Status"], [0, 60, 80, 80, 80, 80, 90, 150])
	t.custom_minimum_size.y = 640
	var root := t.create_item()
	var rr: Dictionary = Career.W.get("raceRt", {})
	var ov: Dictionary = Career.W.get("gradeOverride", {})
	for gr in Career.GRADED:
		var name: String = gr[0]
		var cls: String = ov.get(name, gr[1])
		var lst: Array = rr.get(name, [])
		var it := t.create_item(root)
		it.set_text(0, name)
		it.set_text(1, cls + ("*" if ov.has(name) else ""))
		var s := 0.0
		for k in 3:
			it.set_text(2 + k, "%.2f" % float(lst[k].rr) if k < lst.size() else "-")
			if k < lst.size(): s += float(lst[k].rr)
		var par := Ratings.grade_par(cls, gr[6] == "F", gr[5])
		it.set_text(5, "%.2f" % (s / 3.0) if lst.size() >= 3 else "-")
		it.set_text(6, "%d" % int(par))
		var st := "new grade" if ov.has(name) else "-"
		if lst.size() >= 3:
			var avg := s / 3.0
			st = "below tolerance" if avg < par - Ratings.GRADE_TOL else ("below parameter" if avg < par else "meets standard")
			if ov.has(name): st += " (was %s)" % gr[1]
		it.set_text(7, st)
		if cls == "G1": it.set_custom_color(1, UiTheme.ACC)
		if st.begins_with("below tolerance"): it.set_custom_color(7, UiTheme.BAD)
	c.add_child(t)

# ---------------- G1 pre-race ratings ----------------
func _pre(v: VBoxContainer) -> void:
	var next = null
	for r in Career.W.races:
		if r.cls == "G1": next = r; break
	var w: int = Career.W.week
	var gr_next = null
	if next == null:
		for g in Career.GRADED:
			if g[1] == "G1" and int(g[2]) >= w: gr_next = g; break
		if gr_next == null:
			for g in Career.GRADED:
				if g[1] == "G1": gr_next = g; break
	var title := ""
	var list: Array = []
	if next != null:
		title = "%s · %s %d m · entries" % [next.name, RaceEngine.COURSES[next.course].short, next.dist]
		list = Ratings.nominated(next)
	else:
		# before the field is declared: the top-rated horses who could run (eligible by age and sex)
		title = "%s (week %d) · likely runners by rating" % [gr_next[0], gr_next[2]]
		var fake := { "entries": [], "sex": gr_next[6], "age": gr_next[5] }
		var pool := Career.active().filter(func(h):
			if gr_next[6] == "F" and h.sex != "F": return false
			var a := int(h.age)
			if gr_next[5] == "2": return a == 2
			if gr_next[5] == "3": return a == 3
			if gr_next[5] == "4+": return a >= 4
			return a >= 3)
		for h in pool: fake.entries.append(int(h.id))
		list = Ratings.nominated(fake).slice(0, 24)
	var c := _card(title, v)
	c.add_child(UiTheme.dim_label("JRA publishes ratings for nominated horses before each G1: this year's and last year's best rating with distance category. Fillies and mares are ranked with 4 lb added.", 12))
	var t := _table(["#", "Horse", "Sex/Age", "This year", "Last year", "Ranking value"], [34, 0, 80, 110, 110, 110])
	t.custom_minimum_size.y = 34 + 26 * mini(20, maxi(1, list.size()))
	var root := t.create_item()
	for i in list.size():
		var e: Dictionary = list[i]
		var h = Breeding.get_horse(e.id)
		var it := t.create_item(root)
		it.set_text(0, str(i + 1))
		it.set_text(1, str(e.name))
		it.set_text(2, "%s%d" % ["F" if h.sex == "F" else "C", int(h.age)])
		it.set_text(3, rt_text(e.cur))
		it.set_text(4, rt_text(e.prev))
		it.set_text(5, "%d" % int(e.key) if e.key > 0 else "-")
		it.set_metadata(0, int(e.id))
		if Career.W.stable.has(int(e.id)):
			for k in 6: it.set_custom_color(k, UiTheme.ACC)
	c.add_child(t)

func _world(v: VBoxContainer) -> void:
	var cur := int(Career.W.year)
	var yrs: Array = [cur]
	for k in Career.W.get("world", {}): yrs.append(int(k))
	yrs.sort(); yrs.reverse()
	var bar := HBoxContainer.new()
	bar.add_child(UiTheme.label("Year:", 13, UiTheme.DIM))
	for y in yrs:
		if y < cur - 6: continue
		var b := Button.new()
		b.text = str(y) + (" (so far)" if y == cur else "")
		b.flat = y != year
		b.pressed.connect(func(): shell.open("ratings", ["world", y]))
		bar.add_child(b)
	v.add_child(bar)
	var snap: Dictionary = Career.W.get("world", {}).get(str(year), {})
	var rk: Array = Intl.world_ranking(year) if year == cur else snap.get("ranking", [])
	var races: Array = Intl.top_races(year) if year == cur else snap.get("races", [])
	if not races.is_empty() and year != cur:
		var best: Dictionary = races[0]
		v.add_child(UiTheme.label("LONGINES World's Best Horse Race %d: %s (%s) — race rating %.2f" % [year, best.name, best.country, float(best.rr)], 16, UiTheme.ACC))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var c := _card("LONGINES World's Best Racehorse Rankings %d  (rated 115+ · %d horses)" % [year, rk.size()], row)
	c.add_child(UiTheme.dim_label("Each horse once, at its best rating of the year. Trained: JPN, GB, IRE, FR, USA, HK, AUS, UAE, KSA.", 12))
	var t := _table(["#", "Rating", "Surf", "Horse", "Age/Sex", "Trained", "Race"], [34, 80, 50, 0, 70, 70, 0])
	t.custom_minimum_size.y = 640
	var root := t.create_item()
	var rank := 0
	var last := -1.0
	for i in mini(100, rk.size()):
		var e: Dictionary = rk[i]
		if float(e.r) != last: rank = i + 1; last = float(e.r)
		var it := t.create_item(root)
		it.set_text(0, str(rank))
		it.set_text(1, "%d %s" % [int(e.r), str(e.cat)])
		it.set_text(2, "D" if str(e.surf) == "D" else "T")
		it.set_text(3, str(e.name))
		it.set_text(4, "%d%s" % [int(e.age), "F" if e.sex == "F" else "C"])
		it.set_text(5, str(e.trained))
		it.set_text(6, str(e.race))
		it.set_metadata(0, int(e.id))
		if str(e.trained) == "JPN": it.set_custom_color(5, UiTheme.ACC)
		if Career.W.stable.has(int(e.id)):
			for k in 7: it.set_custom_color(k, UiTheme.ACC)
	c.add_child(t)
	var c2 := _card("Top G1 races %d (annual race rating)" % year, row, false)
	c2.custom_minimum_size.x = 470
	if races.is_empty(): c2.add_child(UiTheme.dim_label("Race ratings are published at the end of the year.", 12))
	var t2 := _table(["#", "Race", "Country", "Rating"], [34, 0, 70, 70])
	t2.custom_minimum_size.y = 640
	var r2 := t2.create_item()
	for i in mini(100, races.size()):
		var it := t2.create_item(r2)
		it.set_text(0, str(i + 1)); it.set_text(1, str(races[i].name)); it.set_text(2, str(races[i].country)); it.set_text(3, "%.2f" % float(races[i].rr))
		if str(races[i].country) == "JPN": it.set_custom_color(2, UiTheme.ACC)
	if not races.is_empty(): c2.add_child(t2)

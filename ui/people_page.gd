class_name PeoplePage
extends ScrollContainer
## Racing World — leading owners, trainers and jockeys for a season. Double-click anyone to open their profile.

var shell
var tab := "owners"
var year := 2027

func setup(s, arg = null) -> PeoplePage:
	shell = s
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	year = int(Career.W.year)
	if arg is Array:
		tab = String(arg[0]); year = int(arg[1])
	elif arg != null:
		year = int(arg)
	shell._set_title("Racing World", "Leading owners, trainers and jockeys · %d" % year)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var hb := HBoxContainer.new()
	for t in [["owners", "Owners"], ["trainers", "Trainers"], ["jockeys", "Jockeys"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = t[0] == tab
		b.custom_minimum_size.x = 120
		var key: String = t[0]
		b.pressed.connect(func(): shell.open("people", [key, year]))
		hb.add_child(b)
	var sp := Control.new(); sp.custom_minimum_size.x = 20
	hb.add_child(sp)
	hb.add_child(UiTheme.label("Season", 13))
	var ob := OptionButton.new()
	for y in range(int(Career.W.get("start_year", 2027)), int(Career.W.year) + 1):
		ob.add_item(str(y), y)
		if y == year: ob.select(ob.item_count - 1)
	ob.item_selected.connect(func(i): shell.open("people", [tab, ob.get_item_id(i)]))
	hb.add_child(ob)
	v.add_child(hb)
	var c: VBoxContainer = shell._card("Leading %s %d" % [tab, year], v)
	var t := Tree.new()
	t.hide_root = true
	t.column_titles_visible = true
	var cols: Array
	match tab:
		"owners": cols = ["#", "Owner", "Type", "Horses", "Runs", "Wins", "2nd", "3rd", "Win %", "Prize ¥M", "G1"]
		"trainers": cols = ["#", "Trainer", "Centre", "Age", "Skill", "Starts", "Wins", "2nd", "3rd", "Win %", "Prize ¥M"]
		_: cols = ["#", "Jockey", "Age", "Skill", "Rides", "Wins", "2nd", "3rd", "Win %", "Prize ¥M", ""]
	t.columns = cols.size()
	for i in cols.size():
		t.set_column_title(i, cols[i])
		t.set_column_expand(i, i == 1)
		t.set_column_custom_minimum_width(i, 220 if i == 1 else 66)
	t.custom_minimum_size.y = 720
	var root := t.create_item()
	var list: Array = Owners.leaders(year) if tab == "owners" else People.leaders(tab, year)
	# everyone shows, even without runs yet (sorted by skill / size after the season's runners)
	var seen := {}
	for e in list: seen[int(e.p.id)] = true
	var rest: Array = (Career.W.get("owners", []) if tab == "owners" else Career.W.get(tab, [])).filter(func(p): return not seen.has(int(p.id)) and p.get("active", true))
	rest.sort_custom(func(a, b): return float(a.get("size", a.get("skill", 0))) > float(b.get("size", b.get("skill", 0))))
	for p in rest: list.append({ "p": p, "rides": 0, "w": 0, "w2": 0, "w3": 0, "prize": 0.0 })
	var counts := {}
	if tab == "owners":
		for h in Career.active():
			if h.has("ownerId"): counts[int(h.ownerId)] = counts.get(int(h.ownerId), 0) + 1
	for i in list.size():
		var e: Dictionary = list[i]
		var p: Dictionary = e.p
		var it := t.create_item(root)
		it.set_metadata(0, int(p.id))
		it.set_text(0, str(i + 1) if e.rides > 0 else "-")
		it.set_text(1, String(p.name) + ("" if p.get("real", true) else "  (new)" if tab != "owners" else ""))
		var k := 2
		match tab:
			"owners":
				it.set_text(2, String(p.kind).capitalize()); it.set_text(3, str(counts.get(int(p.id), 0)))
				k = 4
			"trainers":
				it.set_text(2, "Miho" if p.centre == "miho" else "Ritto"); it.set_text(3, str(year - int(p.born))); it.set_text(4, str(roundi(float(p.skill))))
				it.set_custom_color(4, UiTheme.stat_color(float(p.skill)))
				k = 5
			_:
				it.set_text(2, str(year - int(p.born))); it.set_text(3, str(roundi(float(p.skill))))
				it.set_custom_color(3, UiTheme.stat_color(float(p.skill)))
				k = 4
		it.set_text(k, str(e.rides)); it.set_text(k + 1, str(e.w)); it.set_text(k + 2, str(e.w2)); it.set_text(k + 3, str(e.w3))
		it.set_text(k + 4, "%.1f" % (100.0 * e.w / maxf(1, e.rides)) if e.rides > 0 else "-")
		it.set_text(k + 5, "%.1f" % float(e.prize))
		if tab == "owners": it.set_text(k + 6, str(p.get("g1", []).filter(func(g): return int(g.y) == year).size()))
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null: shell.open("person", [tab, int(it.get_metadata(0))]))
	c.add_child(t)
	v.add_child(UiTheme.dim_label("Double-click a name to open the profile. Trainer and jockey skill comes from the real JRA record in your files; the detailed attributes are estimates built around it. Club and farm names are real; individual owners and all silks are fictional.", 11))
	return self

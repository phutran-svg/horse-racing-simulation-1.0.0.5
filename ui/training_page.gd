class_name TrainingPage
extends ScrollContainer
## Step 4B — the week's training for every horse in your care at once.

var shell

func setup(s) -> TrainingPage:
	shell = s
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell._set_title("Training", "Weekly plans · %s" % Game.now_text())
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var card: VBoxContainer = shell._card("Horses in training", v)
	var head := HBoxContainer.new()
	for x in [["Horse", 200], ["Fit", 50], ["Fatigue", 80], ["Mood", 90], ["Weight", 70], ["Plan", 210], ["Work", 260], ["Intensity", 200], ["Last workout", 0]]:
		var l := UiTheme.label(x[0], 12, UiTheme.ACC)
		l.custom_minimum_size.x = x[1]
		if x[1] == 0: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	card.add_child(head)
	var n := 0
	for h in shell.my_horses():
		var c: Dictionary = h.get("c", {})
		if c.get("status", "") != "active" or int(h.get("age", 0)) < 2: continue
		n += 1
		var row := HBoxContainer.new()
		var nb: Button = shell._horse_link(h)
		nb.custom_minimum_size.x = 200
		nb.pressed.connect(func(): shell.open_horse(int(h.id), "training"))
		row.add_child(nb)
		var fit := float(c.get("fit", 0.7)) * 100.0
		var add := func(t: String, w: int, col := UiTheme.TEXT) -> void:
			var l := UiTheme.label(t, 13, col)
			l.custom_minimum_size.x = w
			row.add_child(l)
		add.call("%d%%" % roundi(fit), 50, UiTheme.stat_color(fit))
		var fat := float(c.get("fat", 0.0))
		add.call("Fresh" if fat < 0.3 else ("Some" if fat < 0.6 else "Tired"), 80, UiTheme.GOOD if fat < 0.3 else (UiTheme.ACC if fat < 0.6 else UiTheme.BAD))
		add.call(Training.mood_text(float(c.get("mood", 60.0))), 90)
		add.call("%d kg" % int(c.get("bwNow", h.get("bw", 480))), 70)
		var p := Training.plan(h)
		var mode := OptionButton.new()
		mode.custom_minimum_size.x = 210
		mode.add_item("Trainer decides" if not Profile.licensed_trainer() else "Usual routine")
		mode.add_item("My plan")
		mode.select(1 if p.mode == "manual" else 0)
		row.add_child(mode)
		var wk := OptionButton.new()
		wk.custom_minimum_size.x = 260
		for i in Training.ORDER.size():
			wk.add_item("%s %s" % [Training.WORKS[Training.ORDER[i]][0], Training.WORKS[Training.ORDER[i]][1]])
			if Training.ORDER[i] == p.work: wk.select(i)
		row.add_child(wk)
		var it := OptionButton.new()
		it.custom_minimum_size.x = 200
		var iks := Training.INTENSITY.keys()
		for i in iks.size():
			it.add_item("%s %s" % [Training.INTENSITY[iks[i]][0], Training.INTENSITY[iks[i]][1]])
			if iks[i] == p.int: it.select(i)
		row.add_child(it)
		if p.mode != "manual":
			var au := Training.auto(h)
			wk.select(Training.ORDER.find(au[0])); it.select(iks.find(au[1]))
			wk.disabled = true; it.disabled = true
		var apply := func(_i):
			Training.set_plan(h, "manual" if mode.selected == 1 else "auto", Training.ORDER[wk.selected], iks[it.selected])
			shell.open("training")
		mode.item_selected.connect(apply); wk.item_selected.connect(apply); it.item_selected.connect(apply)
		var works: Array = c.get("works", [])
		var lw := UiTheme.label(works[0].txt if not works.is_empty() else "-", 12, UiTheme.DIM)
		lw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lw.clip_text = true
		row.add_child(lw)
		card.add_child(row)
	if n == 0: card.add_child(UiTheme.dim_label("No horses in training.", 13))
	v.add_child(UiTheme.dim_label("Plans repeat every week until you change them. 'Trainer decides' lets the stable choose: easy work after a race, fast work (一杯) in race week, rest when tired.", 12))
	return self

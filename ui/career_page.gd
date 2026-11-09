class_name CareerPage
extends ScrollContainer
## Step 4A — your career: who you are, licences, skills and reputation, the trainer exam, owner offers.

var shell

func setup(s) -> CareerPage:
	shell = s
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p := Profile.P()
	shell._set_title("Career", "%s · %s" % [p.get("name", ""), Profile.ROLES[Profile.role()][0]])
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_profile(shell._card("Profile", row))
	_skills(shell._card("Skills and reputation", row))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	v.add_child(row2)
	match Profile.role():
		"trainer":
			if Profile.licensed_trainer():
				_offers(shell._card("Owner offers", row2))
				_yard(shell._card("Your yard", row2))
			else:
				_focus(shell._card("This week's focus", row2))
				_exam(shell._card("JRA trainer licence", row2))
		"owner": _owner(shell._card("Owner", row2))
		"breeder": _breeder(shell._card("Farm", row2))
	_history(shell._card("Career history", v))
	return self

func _kv(parent: Control, k: String, val: String, col := UiTheme.TEXT) -> void:
	var hb := HBoxContainer.new()
	var l := UiTheme.dim_label(k, 13)
	l.custom_minimum_size.x = 170
	hb.add_child(l)
	var r := UiTheme.label(val, 14, col)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(r)
	parent.add_child(hb)

func _profile(c: VBoxContainer) -> void:
	var p := Profile.P()
	c.add_child(UiTheme.label(String(p.get("name", "")), 22, UiTheme.STRONG))
	_kv(c, "Age", "%d" % Profile.age())
	_kv(c, "Country", "Japan (JRA)")
	_kv(c, "Career", Profile.ROLES[Profile.role()][0])
	if Profile.role() == "trainer":
		var job := Finance.job_name().capitalize()
		_kv(c, "Job", job + (" · " + String(p.employer) if not p.licensed and String(p.employer) != "" else ""))
		_kv(c, "Training centre", Profile.center_name())
		_kv(c, "Trainer licence", "JRA ✓" if p.licensed else "Not yet (exam from age %d)" % Profile.EXAM_AGE, UiTheme.GOOD if p.licensed else UiTheme.DIM)
		if p.licensed: _kv(c, "Retirement", "At %d (in %d years)" % [Profile.RETIRE_AGE, maxi(0, Profile.RETIRE_AGE - Profile.age())])
	else:
		_kv(c, "Owner licence", "JRA ✓" if p.get("ownerLic", "") != "" else "None", UiTheme.GOOD if p.get("ownerLic", "") != "" else UiTheme.DIM)
		_kv(c, "Farm", ("Hidaka · " + Game.money(float(p.farmValue))) if Finance.has_farm() else "None")
	_kv(c, "Difficulty", Profile.DIFF[String(p.get("diff", "normal"))].label)

func _bar(c: VBoxContainer, name: String, val: float) -> void:
	var hb := HBoxContainer.new()
	var l := UiTheme.label(name, 13)
	l.custom_minimum_size.x = 150
	hb.add_child(l)
	var pb := ProgressBar.new()
	pb.min_value = 0; pb.max_value = 100; pb.value = val
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(200, 14)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.stat_color(val), Color(0, 0, 0, 0), 3, 0))
	pb.add_theme_stylebox_override("background", UiTheme.box(UiTheme.PANEL2, Color(0, 0, 0, 0), 3, 0))
	hb.add_child(pb)
	var n := UiTheme.label("%d" % roundi(val), 13, UiTheme.stat_color(val))
	n.custom_minimum_size.x = 34
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(n)
	c.add_child(hb)

func _skills(c: VBoxContainer) -> void:
	var p := Profile.P()
	var s: Dictionary = p.get("skills", {})
	_bar(c, "Horsemanship", float(s.get("horse", 0)))
	_bar(c, "Riding", float(s.get("riding", 0)))
	_bar(c, "Knowledge", float(s.get("know", 0)))
	_bar(c, "Business", float(s.get("business", 0)))
	_bar(c, "Reputation", float(p.get("rep", 0)))
	c.add_child(UiTheme.dim_label("Horsemanship and riding grow with daily work, knowledge with study, reputation with winners.", 11))

func _focus(c: VBoxContainer) -> void:
	var p := Profile.P()
	c.add_child(UiTheme.dim_label("What you spend your spare hours on each week:", 12))
	for k in Profile.FOCUS:
		var b := CheckBox.new()
		b.text = Profile.FOCUS[k]
		b.button_pressed = String(p.focus) == k
		b.pressed.connect(func(): p.focus = k; shell.open("career"))
		c.add_child(b)
	if p.job in ["groom", "assistant"]:
		c.add_child(HSeparator.new())
		c.add_child(UiTheme.section("Horses in your care"))
		for id in p.get("care", []):
			var h = Breeding.get_horse(id)
			if h == null: continue
			var hb := HBoxContainer.new()
			hb.add_child(shell._horse_link(h))
			var dl := UiTheme.label("%s · %d starts, %d wins" % [Career.tier_of(h), int(h.c.starts), int(h.c.wins)], 12, UiTheme.DIM)
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(dl)
			c.add_child(hb)
		c.add_child(UiTheme.dim_label("You get 5% of their prize money (the groom's share).", 11))
	else:
		c.add_child(UiTheme.dim_label("At the Racing School: the course lasts about six months, then a stable hires you as a groom.", 11))

func _exam(c: VBoxContainer) -> void:
	var p := Profile.P()
	var a := Profile.age()
	c.add_child(UiTheme.dim_label("Applications in September (week %d). First stage (written + physical) in October, second stage (interview) in November, results in December, licence from 1 March. You must be %d or older." % [Profile.EXAM_APPLY_WEEK, Profile.EXAM_AGE], 12))
	var st := int(p.get("examStage", 0))
	var stxt := "Not applied"
	if int(p.get("examYear", 0)) == int(Career.W.year):
		stxt = ["Not this year", "Applied — first stage week %d" % Profile.EXAM_W1, "Passed stage 1 — interview week %d" % Profile.EXAM_W2, "Waiting for results (week %d)" % Profile.EXAM_RESULT, "PASSED — licence from 1 March"][clampi(st, 0, 4)]
	elif st == 4: stxt = "PASSED — licence from 1 March"
	_kv(c, "Status", stxt, UiTheme.GOOD if st >= 3 else UiTheme.TEXT)
	_kv(c, "Eligible", "Yes" if a >= Profile.EXAM_AGE else "From age %d (in %d years)" % [Profile.EXAM_AGE, Profile.EXAM_AGE - a])
	var cb := CheckBox.new()
	cb.text = "Apply automatically each September"
	cb.button_pressed = p.get("examApply", true)
	cb.toggled.connect(func(on): p.examApply = on)
	c.add_child(cb)
	var est1 := Profile.written_score()
	var est2 := Profile.interview_score()
	_kv(c, "Readiness — written", "%d / %d needed" % [roundi(est1), roundi(Profile.EXAM_MARK1)], UiTheme.GOOD if est1 >= Profile.EXAM_MARK1 else UiTheme.ACC)
	_kv(c, "Readiness — interview", "%d / %d needed" % [roundi(est2), roundi(Profile.EXAM_MARK2)], UiTheme.GOOD if est2 >= Profile.EXAM_MARK2 else UiTheme.ACC)
	c.add_child(UiTheme.dim_label("Exam-day nerves and luck add about ±7 points. Written = knowledge and horsemanship; interview = horsemanship, riding and reputation.", 11))
	if not p.exams.is_empty():
		c.add_child(UiTheme.section("Past attempts"))
		for e in p.exams:
			c.add_child(UiTheme.label("%d · stage %d · %s (%.0f)" % [int(e.y), int(e.stage), "pass" if e.pass else "fail", float(e.score)], 12, UiTheme.GOOD if e.pass else UiTheme.BAD))

func _offers(c: VBoxContainer) -> void:
	var p := Profile.P()
	c.get_parent().custom_minimum_size.x = 620
	var free: int = int(p.boxes) - Career.W.stable.size()
	c.add_child(UiTheme.dim_label("Owners offer you horses a few times a year. Boxes free: %d of %d." % [maxi(0, free), int(p.boxes)], 12))
	if p.offers.is_empty(): c.add_child(UiTheme.dim_label("No offers right now.", 13))
	for i in p.offers.size():
		var o: Dictionary = p.offers[i]
		var h = Breeding.get_horse(o.id)
		if h == null: continue
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.add_child(shell._horse_link(h))
		var d := UiTheme.dim_label("%s %d · %s · %s · owner %s" % [Game.sex_word(h), int(h.age), Game.distance_label(h), UiTheme.stars(Game.ability_stars(h)), o.owner], 12)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(d)
		var ab := Button.new()
		ab.text = "Accept"
		ab.disabled = free <= 0
		ab.pressed.connect(func():
			if Profile.accept_offer(i): shell.toast("%s joins your stable" % h.name)
			shell.open("career"))
		hb.add_child(ab)
		var db := Button.new()
		db.text = "Decline"
		db.pressed.connect(func(): Profile.decline_offer(i); shell.open("career"))
		hb.add_child(db)
		c.add_child(hb)

func _yard(c: VBoxContainer) -> void:
	var p := Profile.P()
	_kv(c, "Boxes", "%d used of %d" % [Career.W.stable.size(), int(p.boxes)])
	_kv(c, "Box review", "Each January JRA sets your boxes by results (%d–%d)." % [Profile.BOX_MIN, Profile.BOX_MAX])
	var owners := {}
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h == null: continue
		var o := String(h.c.get("owner", "?"))
		owners[o] = int(owners.get(o, 0)) + 1
	c.add_child(UiTheme.section("Owners"))
	for o in owners: c.add_child(UiTheme.label("%s — %d horse%s" % [o, owners[o], "" if owners[o] == 1 else "s"], 13))
	c.add_child(UiTheme.dim_label("Owners move horses away after a run of poor results, and retire them when they choose.", 11))

func _owner(c: VBoxContainer) -> void:
	var p := Profile.P()
	_kv(c, "Business income", "%s a year" % Game.money(float(p.business)))
	_kv(c, "Horses", "%d" % Career.W.stable.size())
	if not p.farm:
		var b := Button.new()
		b.text = "Buy a breeding farm in Hidaka (%s)" % Game.money(Profile.FARM_PRICE)
		b.disabled = Finance.money() < Profile.FARM_PRICE
		b.pressed.connect(func():
			if Profile.buy_farm(): shell.toast("You now own a farm")
			shell.open("career"))
		c.add_child(b)
		c.add_child(UiTheme.dim_label("With your own farm, horses foaled there count as bred by you (breeder prizes) and keep is cheaper.", 11))
	c.add_child(UiTheme.dim_label("Buy and sell horses in the Market. Auctions arrive in step 4C.", 11))

func _breeder(c: VBoxContainer) -> void:
	var p := Profile.P()
	_kv(c, "Farm", "%s · Hidaka · value %s" % [Career.W.get("stable_name", ""), Game.money(float(p.farmValue))])
	_kv(c, "Owner licence", "JRA ✓" if p.ownerLic != "" else "None — your 2-year-olds are sold in April if not sold before")
	if p.ownerLic == "":
		var ok := Profile.owner_licence_ok()
		var b := Button.new()
		b.text = "Apply for an owner licence"
		b.disabled = not ok[0]
		b.pressed.connect(func():
			if Profile.apply_owner_licence(): shell.toast("You are now a JRA owner")
			shell.open("career"))
		c.add_child(b)
		if not ok[0]: c.add_child(UiTheme.dim_label(ok[1], 11))
	c.add_child(UiTheme.dim_label("Sell foals and yearlings in the Market (auctions arrive in step 4C). You earn breeder prizes whenever a horse you bred places in a race.", 11))

func _history(c: VBoxContainer) -> void:
	var p := Profile.P()
	if p.get("history", []).is_empty(): c.add_child(UiTheme.dim_label("Your story starts now.", 13))
	for e in p.get("history", []):
		c.add_child(UiTheme.label("%d · %s" % [int(e.y), e.t], 13))

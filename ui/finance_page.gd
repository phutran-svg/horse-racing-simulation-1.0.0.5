class_name FinancePage
extends ScrollContainer
## Step 4A — Finances: cash, assets and loans, this month's bills, income statement by year, and the ledger.

var shell
var year := 0

func setup(s, arg = null) -> FinancePage:
	shell = s
	year = int(arg) if arg != null else int(Career.W.year)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	shell._set_title("Finances", "%s · %s" % [Career.W.get("stable_name", ""), Game.now_text()])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_summary(shell._card("Balance", row))
	_month(shell._card("This month (estimate)", row))
	_loans(shell._card("Bank", row))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	v.add_child(row2)
	_statement(shell._card("Income statement", row2))
	_ledger(shell._card("Transactions", row2))
	return self

func _kv(parent: Control, k: String, val: String, col := UiTheme.TEXT, size := 14) -> void:
	var hb := HBoxContainer.new()
	var l := UiTheme.label(k, size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var r := UiTheme.label(val, size, col)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(r)
	parent.add_child(hb)

func _money_col(x: float) -> Color:
	return UiTheme.GOOD if x > 0.0005 else (UiTheme.BAD if x < -0.0005 else UiTheme.TEXT)

func _summary(c: VBoxContainer) -> void:
	var cash := Finance.money()
	c.add_child(UiTheme.label(Game.money(cash), 30, _money_col(cash) if cash < 0 else UiTheme.STRONG))
	c.add_child(UiTheme.dim_label("Cash", 12))
	var hv := 0.0
	var n := 0
	for id in Career.W.stable:
		var h = Breeding.get_horse(id)
		if h != null and Finance.owns(h): hv += Game.value(h); n += 1
	if Finance.role() != "trainer": _kv(c, "Horses owned (%d)" % n, Game.money(hv))
	var p := Finance.P()
	if Finance.has_farm(): _kv(c, "Farm", Game.money(float(p.get("farmValue", 0.0))))
	if Finance.debt() > 0.0: _kv(c, "Bank loans", "−" + Game.money(Finance.debt()), UiTheme.BAD)
	_kv(c, "Net worth", Game.money(Finance.assets()), UiTheme.ACC, 15)
	if p.get("ownerLic", "") != "": c.add_child(UiTheme.dim_label("JRA owner licence ✓", 11))

func _month(c: VBoxContainer) -> void:
	var m := Finance.monthly_preview()
	for l in m.lines: _kv(c, l[0], ("+" if float(l[1]) > 0 else "") + Game.money(float(l[1])), _money_col(float(l[1])), 13)
	if m.lines.is_empty(): c.add_child(UiTheme.dim_label("No regular bills.", 12))
	c.add_child(HSeparator.new())
	_kv(c, "Net each month", Game.money(m.total), _money_col(m.total), 15)
	c.add_child(UiTheme.dim_label("Paid at the end of each month. Prize money, sales and stud fees come on top.", 11))

func _loans(c: VBoxContainer) -> void:
	_kv(c, "Loans", Game.money(Finance.debt()))
	_kv(c, "You can borrow up to", Game.money(Finance.borrow_limit()))
	c.add_child(UiTheme.dim_label("Interest %.1f%% a year, charged monthly. Up to half your net worth." % (Finance.LOAN_RATE * 100.0), 11))
	var hb := HBoxContainer.new()
	var amt := SpinBox.new()
	amt.min_value = 1; amt.max_value = 5000; amt.step = 1; amt.value = 50
	amt.suffix = "¥M"
	hb.add_child(amt)
	var bb := Button.new()
	bb.text = "Borrow"
	bb.pressed.connect(func():
		if Finance.borrow(amt.value): shell.toast("Borrowed %s" % Game.money(amt.value)); shell.open("finances")
		else: shell.toast("The bank won't lend that much"))
	hb.add_child(bb)
	var rb := Button.new()
	rb.text = "Repay"
	rb.disabled = Finance.debt() <= 0.0
	rb.pressed.connect(func():
		if Finance.repay(minf(amt.value, Finance.debt())): shell.toast("Loan repaid"); shell.open("finances")
		else: shell.toast("Not enough cash"))
	hb.add_child(rb)
	c.add_child(hb)

func _statement(c: VBoxContainer) -> void:
	c.get_parent().custom_minimum_size.x = 520
	var hb := HBoxContainer.new()
	var years: Array = Career.W.get("finYear", {}).keys()
	years.sort()
	var ob := OptionButton.new()
	for y in years: ob.add_item(str(y), int(y))
	if years.is_empty(): ob.add_item(str(year), year)
	ob.select(maxi(0, years.find(year)))
	ob.item_selected.connect(func(i): shell.open("finances", ob.get_item_id(i)))
	hb.add_child(UiTheme.label("Year", 13))
	hb.add_child(ob)
	c.add_child(hb)
	var st := Finance.statement(year)
	c.add_child(UiTheme.section("Income"))
	for k in Finance.CATS:
		var x := float(st.by.get(k, 0.0))
		if k in ["loan", "capital"] or x <= 0.0005: continue
		_kv(c, Finance.CATS[k], Game.money(x), UiTheme.GOOD, 13)
	_kv(c, "Total income", Game.money(st.income), UiTheme.GOOD)
	c.add_child(UiTheme.section("Costs"))
	for k in Finance.CATS:
		var x := float(st.by.get(k, 0.0))
		if k in ["loan", "capital"] or x >= -0.0005: continue
		_kv(c, Finance.CATS[k], Game.money(x), UiTheme.BAD, 13)
	_kv(c, "Total costs", Game.money(st.costs), UiTheme.BAD)
	c.add_child(HSeparator.new())
	_kv(c, "Profit / loss", Game.money(st.net), _money_col(st.net), 16)
	if float(st.by.get("loan", 0.0)) != 0.0: c.add_child(UiTheme.dim_label("Loans taken/repaid this year: %s (not counted as income)" % Game.money(float(st.by.loan)), 11))

func _ledger(c: VBoxContainer) -> void:
	var n := 0
	for e in Career.W.get("ledger", []):
		if int(e.y) != year: continue
		if n >= 250: break
		var hb := HBoxContainer.new()
		var d := UiTheme.label(Game.date_text(int(e.y), int(e.w)).substr(4), 12, UiTheme.DIM)
		d.custom_minimum_size.x = 92
		hb.add_child(d)
		var t := UiTheme.label(String(e.text), 13)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		hb.add_child(t)
		var a := UiTheme.label(("+" if float(e.amt) > 0 else "") + Game.money(float(e.amt)), 13, _money_col(float(e.amt)))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.custom_minimum_size.x = 90
		hb.add_child(a)
		c.add_child(hb)
		n += 1
	if n == 0: c.add_child(UiTheme.dim_label("No transactions this year yet.", 13))

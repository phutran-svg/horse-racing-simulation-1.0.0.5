class_name MarketPage
extends VBoxContainer
## Step 4A — private market: horses other stables would sell (a list that changes every four weeks).
## Open a horse to buy it. Your own horses can be sold from their page. Auctions come in step 4C.

var shell

func setup(s, arg = null) -> MarketPage:
	shell = s
	var kind := String(arg) if arg != null else "all"
	shell._set_title("Market", "Private sales · cash %s" % Game.money(Finance.money()))
	add_theme_constant_override("separation", 8)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	add_child(hb)
	hb.add_child(UiTheme.label("Show", 13))
	var ob := OptionButton.new()
	var kinds := [["all", "All horses for sale"], ["young", "Foals and yearlings"], ["racing", "Racehorses"]]
	for i in kinds.size():
		ob.add_item(kinds[i][1])
		if kinds[i][0] == kind: ob.select(i)
	ob.item_selected.connect(func(i): shell.open("market", kinds[i][0]))
	hb.add_child(ob)
	var note := UiTheme.dim_label("Asking price is about 15% over the estimated value. The list changes every four weeks. Double-click a horse to see it and buy.", 12)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(note)
	if not Profile.can_own():
		add_child(UiTheme.label("You need an owner licence to buy horses%s." % (" — trainers can't own racehorses" if Profile.role() == "trainer" else ""), 14, UiTheme.BAD))
	var t := HorseTable.new(["name", "age", "sex", "dist", "tier", "ab", "pot", "starts", "wins", "value", "sire"])
	t.horse_opened.connect(shell.open_horse)
	t.set_horses(Finance.market(kind))
	add_child(t)
	return self

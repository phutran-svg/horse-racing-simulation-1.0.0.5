class_name HorsePanel
extends Control
## Selected horse: identity, 10 stats, and live physiology (speed, stride, heart rate, energy, lungs, tendon).

var race: RaceEngine.Race
var sel := 0

func refresh() -> void:
	custom_minimum_size.y = 430
	queue_redraw()

func _draw() -> void:
	if race == null or race.runners.is_empty(): return
	var r = race.runners[clampi(sel, 0, race.runners.size() - 1)]
	var h: Dictionary = r.h
	var p: RaceEngine.Params = r.p
	var font := get_theme_default_font()
	var bold := get_theme_default_font()
	var W := size.x
	var c := Color(h.get("color", "#ffffff"))
	var y := 4.0
	draw_rect(Rect2(0, y + 2, 22, 18), c)
	draw_string(font, Vector2(0, y + 16), str(r.i + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 12, UiTheme.on_silk(c))
	draw_string(bold, Vector2(28, y + 16), "%s %s" % [h.name, AppState.sex_sign(h)], HORIZONTAL_ALIGNMENT_LEFT, W - 28, 15, UiTheme.ACC)
	y += 26
	var info := "%s\n%s · %s · %s · dirt aptitude %d · %d kg, carries %s kg · jockey %d · form %+d%%" % [
		Breeding.byline(h) if h.has("sire") else "", RaceEngine.STYLES[h.style].label, RaceEngine.GENES[h.gene].label, h.get("coat", ""),
		int(h.get("dirt", 50)), int(h.bw), str(h.carried), int(h.get("jockey", 75)), int(h.get("form", 0))]
	draw_multiline_string(font, Vector2(0, y + 10), info, HORIZONTAL_ALIGNMENT_LEFT, W, 11, 4, UiTheme.DIM)
	y += 44
	# stats, two columns
	var cw := (W - 10.0) / 2.0
	for k in RaceEngine.STATS.size():
		var key: String = RaceEngine.STATS[k]
		var cx := (k % 2) * (cw + 10.0)
		var cy := y + (k / 2) * 20.0
		var v := float(h.stats[key])
		draw_string(font, Vector2(cx, cy + 13), RaceEngine.STAT_LABEL[key], HORIZONTAL_ALIGNMENT_LEFT, 86, 12, UiTheme.TEXT)
		draw_string(font, Vector2(cx + 86, cy + 13), str(int(v)), HORIZONTAL_ALIGNMENT_RIGHT, 24, 12, UiTheme.ACC)
		var bx := cx + 116.0
		var bw := cw - 118.0
		draw_rect(Rect2(bx, cy + 6, bw, 7), UiTheme.BG)
		draw_rect(Rect2(bx, cy + 6, bw * v / 100.0, 7), Color.from_hsv(0.33 * clampf((v - 40.0) / 50.0, 0.0, 1.0), 0.65, 0.85))
	y += 106
	draw_line(Vector2(0, y), Vector2(W, y), UiTheme.LINE)
	y += 6
	var status: String = String(r.state)
	if r.state == &"run": status = "in the gate" if race.t < r.t0 else ("driving" if r.driving_started else "cruising")
	var rows := [
		["Speed", "%.1f km/h (%.2f m/s)" % [r.v * 3.6, r.v]], ["Status", status],
		["Stride length", "%.2f m" % r.sl], ["Stride freq.", "%.2f /s" % r.sf],
		["Breathing", "%d /min (1 per stride)" % roundi(r.sf * 60.0)], ["Heart rate", "%d bpm" % roundi(r.hr)],
		["Hematocrit", "%d %% (spleen)" % roundi(r.hct)], ["Tendon core", "%.1f °C" % r.T],
		["Critical speed", "%.2f m/s" % r.csEff], ["Effort", "%d %% of CS" % roundi(r.ve / maxf(0.1, r.csEff) * 100.0)],
		["Reserve (Burst)", "%d / %d m" % [roundi(maxf(0.0, r.D)), roundi(p.d0)]], ["Guts reserve", "%d / %d m" % [roundi(r.G), roundi(p.gutsRes)]],
		["Lane", "%.1f m off rail" % r.lane], ["Extra ground", "%.1f m" % r.wideMeters],
		["Drafting", "%s (%d s)" % ["yes" if r.draft else "no", roundi(r.draftTime)]], ["EIPH (lungs)", "grade %d" % r.eiph if r.eiph > 0 else "none"],
		["Injury", r.injury.type if not r.injury.is_empty() else "none"], ["Top speed", "%.1f km/h" % (p.vmax * 3.6)],
	]
	for k in rows.size():
		var cx := (k % 2) * (cw + 10.0)
		var cy := y + (k / 2) * 30.0
		draw_string(font, Vector2(cx, cy + 11), rows[k][0], HORIZONTAL_ALIGNMENT_LEFT, cw, 10, UiTheme.DIM)
		var bad: bool = (rows[k][0] == "Injury" and not r.injury.is_empty()) or (rows[k][0] == "EIPH (lungs)" and r.eiph > 0)
		draw_string(font, Vector2(cx, cy + 25), rows[k][1], HORIZONTAL_ALIGNMENT_LEFT, cw, 12, UiTheme.BAD if bad else UiTheme.TEXT)

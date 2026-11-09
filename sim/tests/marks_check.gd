extends SceneTree
func _init() -> void:
	Career.init(31)
	var faces := {}; var legs := [0, 0, 0, 0, 0]; var n := 0; var nolegs := 0; var none := 0
	var hind := 0; var fore := 0
	var byc := {}
	for h in Career.active():
		var m := Markings.of(h)
		faces[m.face] = faces.get(m.face, 0) + 1
		var any := false
		for k in 4:
			legs[int(m.legs[k])] += 1
			if int(m.legs[k]) > 0:
				any = true
				if k >= 2: hind += 1
				else: fore += 1
		if not any: nolegs += 1
		if not any and m.face == "none": none += 1
		var c := String(h.get("coat", "?"))
		if not byc.has(c): byc[c] = [0, 0]
		byc[c][0] += 1
		if m.face != "none" or any: byc[c][1] += 1
		n += 1
	var fl := ""
	for f in Markings.FACE: fl += "%s %.0f%%  " % [f, 100.0 * faces.get(f, 0) / n]
	print("horses ", n)
	print("face: ", fl)
	print("no white at all: %.0f%%   no white legs: %.0f%%   white legs hind:fore = %.2f" % [100.0 * none / n, 100.0 * nolegs / n, float(hind) / maxf(1, fore)])
	for c in byc: print("  %-9s any white %.0f%% (%d horses)" % [c, 100.0 * byc[c][1] / byc[c][0], byc[c][0]])
	# heritability check: foals vs mid-parent white value
	var xs := []; var ys := []
	for i in 400:
		var s := { "id": 900000 + i }; var d := { "id": 950000 + i }
		var f := { "id": 990000 + i }
		Markings.inherit(f, s, d)
		xs.append((Markings.white(s) + Markings.white(d)) / 2.0); ys.append(float(f.white))
	var mx := 0.0; var my := 0.0
	for i in xs.size(): mx += xs[i]; my += ys[i]
	mx /= xs.size(); my /= ys.size()
	var sxy := 0.0; var sxx := 0.0
	for i in xs.size(): sxy += (xs[i] - mx) * (ys[i] - my); sxx += (xs[i] - mx) * (xs[i] - mx)
	print("foal on mid-parent regression slope %.2f (expected ~1 with this model)" % (sxy / sxx))
	quit()

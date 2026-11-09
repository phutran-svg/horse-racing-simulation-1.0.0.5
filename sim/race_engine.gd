class_name RaceEngine
extends RefCounted
## Race engine v0.5 (GDScript port of engine.js). Pure logic, no nodes.
## Physics/physiology from "The Racehorse at the Gallop" literature review; JRA timing and calibration
## from the lap-time research. See the project notes (race-sim-engine-notes.md).

const G := 9.81
const DT := 0.05
const LENGTH_M := 2.4

static var COURSES: Dictionary = {}
static var TRACK: Dictionary = {}
const STATS := ["speed", "stamina", "accel", "strength", "burst", "guts", "agility", "temper", "sound", "wind"]
const STAT_LABEL := { "speed": "Speed", "stamina": "Stamina", "accel": "Acceleration", "strength": "Strength", "burst": "Burst", "guts": "Guts", "agility": "Agility", "temper": "Temperament", "sound": "Soundness", "wind": "Wind" }
const STAT_INFO := {
	"speed": "Top speed: max stride length x frequency (17-19.5 m/s)",
	"stamina": "Aerobic engine (VO2max 130-200) -> critical speed",
	"accel": "Start dash, stride build-up, response when asked",
	"strength": "Limb force: hills, weight, soft ground, bends",
	"burst": "Anaerobic reserve (MAOD) spent above critical speed",
	"guts": "Extra reserve in the drive; slower fade when empty",
	"agility": "Cornering cost, downhill balance, lane changes",
	"temper": "Gate break, settling; low = may pull hard",
	"sound": "Tendon/bone tolerance -> injury risk",
	"wind": "Airway/breathing: small CS boost, lower EIPH risk",
}
static var GENES := {
	# v: top-speed factor — C:C horses carry more fast-twitch muscle (higher top speed, used in sprints where the
	# top-speed limit, not the aerobic speed, decides the race)
	"CC": { "cs": -0.45, "d": 1.30, "str": 0.06, "v": 1.01, "label": "C:C (sprinter)" },
	"CT": { "cs": 0.0, "d": 1.0, "str": 0.0, "v": 1.0, "label": "C:T (middle)" },
	"TT": { "cs": 0.33, "d": 0.72, "str": -0.04, "v": 0.99, "label": "T:T (stayer)" },
}
static var STYLES := {
	"front": { "x": 0.03, "gap": 0.0, "kf": 0.5, "early": 0.02, "earlyLen": 650.0, "dash": 0.07, "dashLen": 400.0, "kick": 620.0, "lane": 0.8, "label": "Front-runner" },
	"stalker": { "x": 0.022, "gap": 3.0, "kf": 0.45, "early": 0.015, "earlyLen": 350.0, "dash": 0.06, "dashLen": 350.0, "kick": 580.0, "lane": 1.3, "label": "Stalker" },
	"mid": { "x": 0.017, "gap": 7.0, "kf": 0.6, "early": 0.0, "earlyLen": 350.0, "dash": 0.03, "dashLen": 300.0, "kick": 580.0, "lane": 2.0, "label": "Mid-pack" },
	"closer": { "x": 0.012, "gap": 12.0, "kf": 0.7, "early": -0.015, "earlyLen": 400.0, "dash": 0.0, "dashLen": 300.0, "kick": 600.0, "lane": 2.6, "label": "Closer" },
}
# Going (JRA 良/稍重/重/不良). Turf: wetter = slower, mostly in the finishing speed (shorter strides).
# JRA dirt (sand): wetter = firmer and FASTER (JRA Equine Research Institute: 1800 m, 不良 ≈ 1.3 s faster than 良).
# Calibrated 2026-11 against JRA winning times by going (Step 2 notes).
static var GOING := {
	"firm": { "cs": 1.0, "vmax": 1.0, "dcs": 1.0, "dvmax": 1.0, "inj": 1.15, "jp": "良", "turf": "Firm", "dirt": "Standard" },
	"yielding": { "cs": 0.9935, "vmax": 0.996, "dcs": 1.007, "dvmax": 1.003, "inj": 1.0, "jp": "稍重", "turf": "Good", "dirt": "Good" },
	"soft": { "cs": 0.983, "vmax": 0.985, "dcs": 1.013, "dvmax": 1.005, "inj": 0.95, "jp": "重", "turf": "Yielding", "dirt": "Muddy" },
	"heavy": { "cs": 0.965, "vmax": 0.962, "dcs": 1.016, "dvmax": 1.006, "inj": 1.05, "jp": "不良", "turf": "Soft", "dirt": "Sloppy" },
}
## JRA English going name, e.g. "Firm (良)" on turf, "Standard (良)" on dirt
static func going_label(going: String, surface := "turf") -> String:
	var g: Dictionary = GOING.get(going, GOING.firm)
	return "%s (%s)" % [g.dirt if surface == "dirt" else g.turf, g.jp]

static var SURF := { "turf": { "cs": 1.0, "vmax": 1.0, "sl": 1.0, "curve": 1.0, "inj": 1.0, "heat": 1.0 }, "dirt": { "cs": 0.953, "vmax": 0.972, "sl": 0.97, "curve": 1.2, "inj": 1.1, "heat": 1.1 } }
static var DRAG_SHARE := 0.1
static var OVERPUSH := 0.03
static var FAT0 := 0.84
static var FATK := 0.3
static var GAPK := 0.04
static var SLOWK := 0.003
static var DRIFT := 0.35
const INJ_BASE := 0.18e-5     # per-stride injury hazard scale (was 0.8e-5: ~1.4 % of starters, far above JRA)
const DEC_EASE := 0.6          # m/s²: easing off / the pace slackening
const DEC_EMPTY := 0.45        # m/s²: a tired horse fades gradually
const DEC_EASED := 0.7         # m/s²: an eased (lame) horse
const DEC_PULL := 1.6          # m/s²: pulled up (≈150 m from a gallop)
const DEC_CHECK := 2.2         # m/s²: checked sharply right on another horse's heels
const LAT_A := 0.9            # lateral acceleration a horse can make (m/s², 535 kg, average agility)
static var DASH := 1.0
static var LONGK := 0.0
static var LULLK := 0.7
static var CONTK := 1.0
static var LULLLEN := 800.0
# pacing: how much jockeys ease off on bends/hills (1 = equal effort, 0 = equal speed)
static var TFAT_K := 0.0025    # aerobic fatigue in long races: CS falls after TFAT_T0 seconds
static var TFAT_T0 := 100.0
static var TFAT_PROJ := 1.0   # how much of the fatigue still to come jockeys allow for when timing the drive
static var PACE_A := 1.0
static var PACE_D := 1.0
# stat -> class calibration (one stat point ~0.1% of speed: 50 maiden ... 80 G1 ... 90 record)
# v0.9 (rating step): stat sensitivity ×2.4 around the population mean (0.66) so class gaps match JRA times
# (maiden → G1 ≈ 3 %); see Career.QSIG / PACK for race-day variance and finishing gaps
static var CAL := { "V0": 17.418, "VS": 2.16, "C0": 14.788, "CS": 2.16, "D0": 16.58, "DS": 192.0, "A0": 5.6, "AS": 2.0, "GATE": 5.0 }
const EIPH_CS_LOSS := [0.0, 0.005, 0.015, 0.04, 0.10]


# =============================== COURSES ===============================
# s = 0 at the exit of the final turn (start of the home straight); finish = home straight length.
# Loop, straight, direction, width and height difference are JRA figures (A course). Bends are a stadium
# oval; elevation points approximate the JRA cross-sections.
static func _make(o: Dictionary) -> Dictionary:
	var r: float = (o.C - 2.0 * o.S) / (2.0 * PI)
	o["r"] = r
	o["curves"] = [[o.S, o.S + PI * r], [2.0 * o.S + PI * r, o.C]]
	if not o.has("surface"): o["surface"] = "turf"
	if not o.has("pockets"): o["pockets"] = {}
	if not o.has("straight"): o["straight"] = false
	return o

static func _mk2(o: Dictionary, prof: Callable) -> Dictionary:
	var c := _make(o)
	var P: float = PI * c.r
	var pts: Array = prof.call(float(c.S), P, float(c.C), float(c.finish))
	pts.sort_custom(func(a, b): return a[0] < b[0])
	c["elev"] = pts
	return c

static func _static_init() -> void:
	var L := {}
	L["tokyo"] = _make({ "id": "tokyo", "name": "Tokyo – Turf (A course)", "short": "Tokyo", "dir": "L", "C": 2083.1, "S": 560.0, "finish": 525.9, "width": 34.0, "hdiff": 2.7,
		"elev": [[0, 0.3], [30, 0.2], [230, 2.3], [560, 2.4], [1041, 0.8], [1250, -0.3], [1520, 1.5], [1601, 1.6], [2083.1, 0.3]],
		"slope": "the Tokyo slope", "slopeNote": "2.1 m climb early in the straight", "distances": [1400, 1600, 1800, 2000, 2300, 2400, 2500, 3400], "def": 2400,
		"pockets": { 1600: 545.0, 1800: 156.0, 2000: 126.0 } })
	L["nakayama"] = _make({ "id": "nakayama", "name": "Nakayama – Turf inner (A course)", "short": "Nakayama inner", "dir": "R", "C": 1667.1, "S": 420.0, "finish": 310.0, "width": 26.0, "hdiff": 5.3,
		"elev": [[0, 0.2], [130, 0.0], [240, 2.2], [310, 2.4], [420, 3.0], [771, 5.3], [833.4, 5.2], [1253.4, 2.6], [1667.1, 0.2]],
		"slope": "the Nakayama hill", "slopeNote": "2.2 m climb from 180 m to 70 m out (2.24%)", "distances": [1800, 2000, 2500, 3600], "def": 2500 })
	L["hanshin"] = _make({ "id": "hanshin", "name": "Hanshin – Turf outer (A course)", "short": "Hanshin outer", "dir": "R", "C": 2089.0, "S": 520.0, "finish": 473.6, "width": 26.0, "hdiff": 2.4,
		"elev": [[0, 0.5], [274, 0.0], [394, 1.8], [520, 1.9], [1037, 1.6], [1557, 2.4], [1963, 0.9], [2089, 0.5]],
		"slope": "the Hanshin slope", "slopeNote": "downhill from 600 m out, then a steep 1.8 m climb", "distances": [1400, 1600, 1800, 2400, 2600], "def": 1600,
		"pockets": { 1800: 660.0 } })
	L["kyoto"] = _make({ "id": "kyoto", "name": "Kyoto – Turf outer (A course)", "short": "Kyoto outer", "dir": "R", "C": 1894.3, "S": 450.0, "finish": 403.7, "width": 30.0, "hdiff": 4.3,
		"elev": [[0, 0.0], [450, 0.0], [947, 0.3], [1150, 0.3], [1500, 4.3], [1700, 0.4], [1894.3, 0.0]],
		"slope": "the Yodo slope", "slopeNote": "4.3 m hill at the 3rd corner, flat straight", "distances": [1400, 1600, 1800, 2200, 2400, 3000, 3200], "def": 3000,
		"pockets": { 1400: 512.0, 1600: 720.0, 1800: 905.0, 2400: 597.0 } })
	L["niigata"] = _make({ "id": "niigata", "name": "Niigata – Turf outer (A course)", "short": "Niigata outer", "dir": "L", "C": 2223.0, "S": 700.0, "finish": 658.7, "width": 26.0, "hdiff": 2.2,
		"elev": [[0, 0.0], [700, 0.0], [1111, 0.1], [1500, 1.2], [1811, 2.2], [2050, 0.4], [2223, 0.0]],
		"slope": "the gentle 3rd-corner rise", "slopeNote": "longest straight in Japan, almost flat", "distances": [1600, 1800, 2000], "def": 1600 })
	L["tokyo_d"] = _make({ "id": "tokyo_d", "surface": "dirt", "name": "Tokyo – Dirt", "short": "Tokyo dirt", "dir": "L", "C": 1899.0, "S": 540.0, "finish": 501.6, "width": 25.0, "hdiff": 2.5,
		"elev": [[0, 0.3], [40, 0.2], [240, 2.2], [540, 2.4], [957, 0.9], [1150, -0.1], [1400, 1.3], [1497, 1.4], [1899, 0.3]],
		"slope": "the Tokyo slope", "slopeNote": "long dirt straight with a 2 m climb", "distances": [1200, 1300, 1400, 1600, 2100, 2400], "def": 1600, "pockets": { 1600: 645.0 } })
	L["nakayama_d"] = _make({ "id": "nakayama_d", "surface": "dirt", "name": "Nakayama – Dirt", "short": "Nakayama dirt", "dir": "R", "C": 1493.0, "S": 380.0, "finish": 308.0, "width": 22.0, "hdiff": 4.5,
		"elev": [[0, 0.2], [130, 0.0], [240, 2.0], [308, 2.2], [380, 2.6], [690, 4.5], [747, 4.4], [1115, 2.2], [1493, 0.2]],
		"slope": "the Nakayama hill", "slopeNote": "short straight, steep hill before the post", "distances": [1000, 1200, 1700, 1800, 2400, 2500], "def": 1800, "pockets": { 1200: 515.0 } })
	L["hanshin_d"] = _make({ "id": "hanshin_d", "surface": "dirt", "name": "Hanshin – Dirt", "short": "Hanshin dirt", "dir": "R", "C": 1517.6, "S": 400.0, "finish": 352.7, "width": 22.0, "hdiff": 1.6,
		"elev": [[0, 0.4], [180, 0.0], [300, 1.5], [400, 1.6], [757, 1.2], [1157, 1.4], [1517.6, 0.4]],
		"slope": "the Hanshin slope", "slopeNote": "flat-ish, short climb before the post", "distances": [1200, 1400, 1800, 2000, 2600], "def": 1800, "pockets": { 1400: 543.0, 2000: 500.0 } })
	L["nakayama_o"] = _mk2({ "id": "nakayama_o", "name": "Nakayama – Turf outer (A course)", "short": "Nakayama outer", "dir": "R", "C": 1839.7, "S": 420.0, "finish": 310.0, "width": 28.0, "hdiff": 5.3,
		"slope": "the Nakayama hill", "slopeNote": "downhill from the 2nd corner, steep 2.2 m climb before the post", "distances": [1200, 1600, 2200, 2600], "def": 1200, "pockets": { 1600: 240.0 } },
		func(S, P, C, f): return [[0, 0.2], [f - 180, 0.0], [f - 70, 2.2], [f, 2.4], [S, 3.0], [S + P * 0.6, 5.3], [S + P, 4.6], [2 * S + P, 1.5], [C, 0.2]])
	L["kyoto_i"] = _mk2({ "id": "kyoto_i", "name": "Kyoto – Turf inner (A course)", "short": "Kyoto inner", "dir": "R", "C": 1782.8, "S": 400.0, "finish": 328.4, "width": 30.0, "hdiff": 3.1,
		"slope": "the Yodo slope", "slopeNote": "3.1 m hill at the 3rd corner, flat straight", "distances": [1100, 1200, 1400, 1600, 2000], "def": 2000, "pockets": { 1600: 300.0 } },
		func(S, P, C, f): return [[0, 0], [S, 0], [S + P, 0.3], [S + P + S * 0.4, 0.3], [2 * S + P + P * 0.25, 3.1], [2 * S + P + P * 0.75, 0.4], [C, 0]])
	L["hanshin_i"] = _mk2({ "id": "hanshin_i", "name": "Hanshin – Turf inner (A course)", "short": "Hanshin inner", "dir": "R", "C": 1689.0, "S": 400.0, "finish": 356.5, "width": 26.0, "hdiff": 1.9,
		"slope": "the Hanshin slope", "slopeNote": "flat to the 3rd corner, downhill, then a 1.8 m climb before the post", "distances": [1200, 1400, 2000, 2200, 3000], "def": 2200, "pockets": { 1400: 450.0, 2200: 530.0 } },
		func(S, P, C, f): return [[0, 0.3], [f - 190, 0.0], [f - 70, 1.8], [S, 1.9], [2 * S + P, 1.9], [C, 0.3]])
	L["niigata_i"] = _mk2({ "id": "niigata_i", "name": "Niigata – Turf inner (A course)", "short": "Niigata inner", "dir": "L", "C": 1623.0, "S": 400.0, "finish": 358.7, "width": 25.0, "hdiff": 0.8,
		"slope": "the gentle 3rd-corner rise", "slopeNote": "almost flat, spiral final turn", "distances": [1200, 1400, 2000, 2200, 2400], "def": 2000 },
		func(S, P, C, f): return [[0, 0], [S, 0.1], [S + P, 0.4], [2 * S + P, 0.8], [C, 0]])
	L["niigata_s"] = _mk2({ "id": "niigata_s", "name": "Niigata – Turf straight 1000 m (直線)", "short": "Niigata straight", "dir": "L", "C": 2577.0, "S": 1100.0, "finish": 1050.0, "width": 25.0, "hdiff": 0.5,
		"slope": "the straight", "slopeNote": "one straight line, no corners", "distances": [1000], "def": 1000, "straight": true },
		func(S, P, C, f): return [[0, 0], [300, 0.3], [700, 0.0], [C, 0]])
	L["sapporo"] = _mk2({ "id": "sapporo", "name": "Sapporo – Turf", "short": "Sapporo", "dir": "R", "C": 1640.9, "S": 320.0, "finish": 266.1, "width": 26.0, "hdiff": 0.7,
		"slope": "the flat straight", "slopeNote": "almost flat, round shape, short straight", "distances": [1000, 1200, 1500, 1800, 2000, 2600], "def": 1800, "pockets": { 1500: 180.0, 2000: 370.0 } },
		func(S, P, C, f): return [[0, 0.2], [S, 0.1], [S + P, 0.4], [2 * S + P, 0.7], [C, 0.2]])
	L["hakodate"] = _mk2({ "id": "hakodate", "name": "Hakodate – Turf", "short": "Hakodate", "dir": "R", "C": 1626.6, "S": 330.0, "finish": 262.1, "width": 29.0, "hdiff": 3.5,
		"slope": "the Hakodate rise", "slopeNote": "shortest straight in the JRA, climbs to the 3rd corner, spiral turns", "distances": [1000, 1200, 1800, 2000, 2600], "def": 1800, "pockets": { 1200: 485.0 } },
		func(S, P, C, f): return [[0, 0.0], [S, 0.4], [S + P, 1.6], [2 * S + P, 3.4], [2 * S + P * 1.3, 3.5], [C, 0.0]])
	L["fukushima"] = _mk2({ "id": "fukushima", "name": "Fukushima – Turf", "short": "Fukushima", "dir": "R", "C": 1600.0, "S": 340.0, "finish": 292.0, "width": 26.0, "hdiff": 1.9,
		"slope": "the Fukushima rise", "slopeNote": "smallest JRA loop, dips then climbs before the post", "distances": [1000, 1200, 1700, 1800, 2000, 2600], "def": 1800, "pockets": { 1200: 440.0, 2000: 500.0 } },
		func(S, P, C, f): return [[0, 0.6], [f * 0.4, 0.0], [f, 1.0], [S, 1.4], [S + P * 0.5, 1.9], [S + P, 1.5], [2 * S + P, 1.2], [C, 0.6]])
	L["chukyo"] = _mk2({ "id": "chukyo", "name": "Chukyo – Turf", "short": "Chukyo", "dir": "L", "C": 1705.9, "S": 450.0, "finish": 412.5, "width": 29.0, "hdiff": 3.5,
		"slope": "the Chukyo hill", "slopeNote": "2 m climb (≈2%) right after the final turn, 200 m+ to run after it", "distances": [1200, 1300, 1400, 1600, 2000, 2200, 3000], "def": 2000, "pockets": { 1600: 210.0 } },
		func(S, P, C, f): return [[0, 0.0], [f - 330, 0.0], [f - 230, 2.0], [S, 2.2], [S + P * 0.5, 3.5], [S + P, 3.2], [2 * S + P, 2.4], [C, 0.0]])
	L["kokura"] = _mk2({ "id": "kokura", "name": "Kokura – Turf", "short": "Kokura", "dir": "R", "C": 1615.1, "S": 330.0, "finish": 293.0, "width": 30.0, "hdiff": 3.0,
		"slope": "the flat straight", "slopeNote": "hill at the 2nd corner, downhill to the 4th, flat straight", "distances": [1000, 1200, 1700, 1800, 2000, 2600], "def": 1200, "pockets": { 1200: 480.0, 2000: 480.0 } },
		func(S, P, C, f): return [[0, 0], [S, 0], [S + P * 0.7, 3.0], [2 * S + P, 1.4], [C, 0]])
	L["sapporo_d"] = _mk2({ "id": "sapporo_d", "surface": "dirt", "name": "Sapporo – Dirt", "short": "Sapporo dirt", "dir": "R", "C": 1487.0, "S": 300.0, "finish": 264.3, "width": 20.0, "hdiff": 0.9,
		"slope": "the flat straight", "slopeNote": "almost flat", "distances": [1000, 1700, 2400], "def": 1700 },
		func(S, P, C, f): return [[0, 0.2], [S, 0.1], [S + P, 0.5], [2 * S + P, 0.9], [C, 0.2]])
	L["hakodate_d"] = _mk2({ "id": "hakodate_d", "surface": "dirt", "name": "Hakodate – Dirt", "short": "Hakodate dirt", "dir": "R", "C": 1475.8, "S": 300.0, "finish": 260.3, "width": 20.0, "hdiff": 3.5,
		"slope": "the Hakodate rise", "slopeNote": "climbs to the 3rd corner, short straight", "distances": [1000, 1700, 2400], "def": 1700 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.4], [S + P, 1.6], [2 * S + P, 3.4], [2 * S + P * 1.3, 3.5], [C, 0.0]])
	L["fukushima_d"] = _mk2({ "id": "fukushima_d", "surface": "dirt", "name": "Fukushima – Dirt", "short": "Fukushima dirt", "dir": "R", "C": 1444.6, "S": 330.0, "finish": 295.7, "width": 22.0, "hdiff": 2.1,
		"slope": "the Fukushima rise", "slopeNote": "small ups and downs", "distances": [1000, 1150, 1700, 2400], "def": 1700, "pockets": { 1150: 495.0 } },
		func(S, P, C, f): return [[0, 0.6], [f * 0.4, 0.0], [f, 1.1], [S, 1.5], [S + P * 0.5, 2.1], [S + P, 1.6], [2 * S + P, 1.2], [C, 0.6]])
	L["niigata_d"] = _mk2({ "id": "niigata_d", "surface": "dirt", "name": "Niigata – Dirt", "short": "Niigata dirt", "dir": "L", "C": 1472.5, "S": 390.0, "finish": 353.9, "width": 20.0, "hdiff": 0.6,
		"slope": "the flat straight", "slopeNote": "flat, spiral final turn", "distances": [1000, 1200, 1700, 1800, 2500], "def": 1800, "pockets": { 1200: 530.0 } },
		func(S, P, C, f): return [[0, 0], [S, 0.1], [S + P, 0.3], [2 * S + P, 0.6], [C, 0]])
	L["chukyo_d"] = _mk2({ "id": "chukyo_d", "surface": "dirt", "name": "Chukyo – Dirt", "short": "Chukyo dirt", "dir": "L", "C": 1530.0, "S": 440.0, "finish": 410.7, "width": 25.0, "hdiff": 3.4,
		"slope": "the Chukyo hill", "slopeNote": "climb after the final turn", "distances": [1200, 1400, 1800, 1900, 2500], "def": 1800, "pockets": { 1400: 610.0 } },
		func(S, P, C, f): return [[0, 0.0], [f - 330, 0.0], [f - 230, 1.9], [S, 2.1], [S + P * 0.5, 3.4], [S + P, 3.1], [2 * S + P, 2.3], [C, 0.0]])
	L["kyoto_d"] = _mk2({ "id": "kyoto_d", "surface": "dirt", "name": "Kyoto – Dirt", "short": "Kyoto dirt", "dir": "R", "C": 1607.6, "S": 370.0, "finish": 329.1, "width": 25.0, "hdiff": 3.0,
		"slope": "the 3rd-corner hill", "slopeNote": "hill at the 3rd corner, flat straight", "distances": [1000, 1100, 1200, 1400, 1800, 1900], "def": 1800, "pockets": { 1400: 620.0 } },
		func(S, P, C, f): return [[0, 0], [S, 0], [S + P, 0.3], [S + P + S * 0.4, 0.3], [2 * S + P + P * 0.25, 3.0], [2 * S + P + P * 0.75, 0.4], [C, 0]])
	L["kokura_d"] = _mk2({ "id": "kokura_d", "surface": "dirt", "name": "Kokura – Dirt", "short": "Kokura dirt", "dir": "R", "C": 1445.4, "S": 330.0, "finish": 291.3, "width": 24.0, "hdiff": 2.9,
		"slope": "the gentle rise", "slopeNote": "hill at the 2nd corner, 0.6 m rise from 400 m out", "distances": [1000, 1700, 2400], "def": 1700 },
		func(S, P, C, f): return [[0, 0], [maxf(0.0, f - 400), 0], [f, 0.6], [S, 0.6], [S + P * 0.7, 2.9], [2 * S + P, 1.4], [C, 0]])
	# ---- overseas courses (approximate geometry from official course maps; "speedK" = typical speed of the surface
	# relative to JRA turf/dirt, from usual winning times: US dirt is faster, European turf slower) ----
	L["meydan"] = _mk2({ "id": "meydan", "name": "Meydan – Turf", "short": "Meydan", "country": "UAE", "dir": "L", "C": 2400.0, "S": 450.0, "finish": 400.0, "width": 30.0, "hdiff": 0.5,
		"slope": "", "slopeNote": "wide, flat track with a long straight", "distances": [1200, 1400, 1600, 1800, 2000, 2410], "def": 2410, "speedK": 0.985 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.2], [S + P, 0.5], [2 * S + P, 0.3], [C, 0.0]])
	L["meydan_d"] = _mk2({ "id": "meydan_d", "surface": "dirt", "name": "Meydan – Dirt", "short": "Meydan dirt", "country": "UAE", "dir": "L", "C": 1750.0, "S": 400.0, "finish": 360.0, "width": 25.0, "hdiff": 0.3,
		"slope": "", "slopeNote": "flat dirt oval", "distances": [1200, 1600, 1900, 2000], "def": 2000, "speedK": 1.01 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.1], [S + P, 0.3], [C, 0.0]])
	L["riyadh_d"] = _mk2({ "id": "riyadh_d", "surface": "dirt", "name": "King Abdulaziz – Dirt", "short": "Riyadh dirt", "country": "KSA", "dir": "L", "C": 2000.0, "S": 420.0, "finish": 380.0, "width": 25.0, "hdiff": 0.4,
		"slope": "", "slopeNote": "flat dirt oval", "distances": [1200, 1600, 1800, 2000], "def": 1800, "speedK": 1.005 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.2], [S + P, 0.4], [C, 0.0]])
	L["shatin"] = _mk2({ "id": "shatin", "name": "Sha Tin – Turf", "short": "Sha Tin", "country": "HK", "dir": "R", "C": 1900.0, "S": 430.0, "finish": 430.0, "width": 30.5, "hdiff": 1.0,
		"slope": "", "slopeNote": "tight turns, 430 m straight", "distances": [1200, 1400, 1600, 2000, 2400], "def": 2000, "speedK": 0.985 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.5], [S + P, 1.0], [2 * S + P, 0.5], [C, 0.0]])
	L["longchamp"] = _mk2({ "id": "longchamp", "name": "ParisLongchamp – Grande piste", "short": "Longchamp", "country": "FR", "dir": "R", "C": 2750.0, "S": 533.0, "finish": 533.0, "width": 30.0, "hdiff": 10.0,
		"slope": "the hill", "slopeNote": "10 m climb on the far side, the long descent and the false straight", "distances": [1600, 2000, 2100, 2400, 3000], "def": 2400, "speedK": 0.975 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.0], [S + P * 0.5, 2.0], [S + P + 300.0, 10.0], [S + P + 650.0, 10.0], [C - 200.0, 2.0], [C, 0.0]])
	L["ascot"] = _mk2({ "id": "ascot", "name": "Ascot – Round course", "short": "Ascot", "country": "GB", "dir": "R", "C": 2800.0, "S": 500.0, "finish": 450.0, "width": 28.0, "hdiff": 20.0,
		"slope": "the climb to the post", "slopeNote": "down to Swinley Bottom, then a long uphill run home", "distances": [1600, 2000, 2400, 2800], "def": 2400, "speedK": 0.975 },
		func(S, P, C, f): return [[0, 12.0], [f, 15.0], [S, 15.0], [S + P, 8.0], [S + P + 500.0, 0.0], [C - 400.0, 6.0], [C, 12.0]])
	L["york"] = _mk2({ "id": "york", "name": "York – Knavesmire", "short": "York", "country": "GB", "dir": "L", "C": 3000.0, "S": 900.0, "finish": 850.0, "width": 30.0, "hdiff": 1.0,
		"slope": "", "slopeNote": "flat, very long straight", "distances": [1200, 1600, 2050, 2800], "def": 2050, "speedK": 0.985 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.5], [S + P, 1.0], [C, 0.0]])
	L["leopardstown"] = _mk2({ "id": "leopardstown", "name": "Leopardstown – Turf", "short": "Leopardstown", "country": "IRE", "dir": "L", "C": 2800.0, "S": 450.0, "finish": 400.0, "width": 26.0, "hdiff": 6.0,
		"slope": "", "slopeNote": "undulating, short straight", "distances": [1600, 2000, 2800], "def": 2000, "speedK": 0.98 },
		func(S, P, C, f): return [[0, 2.0], [S, 3.0], [S + P, 6.0], [2 * S + P, 3.0], [C, 2.0]])
	L["keeneland_d"] = _mk2({ "id": "keeneland_d", "surface": "dirt", "name": "Keeneland – Dirt (Breeders' Cup)", "short": "Keeneland dirt", "country": "USA", "dir": "L", "C": 1710.0, "S": 358.0, "finish": 358.0, "width": 24.0, "hdiff": 0.5,
		"slope": "", "slopeNote": "American dirt: fast and tight", "distances": [1200, 1400, 1600, 1800, 2000], "def": 2000, "speedK": 1.03 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.2], [S + P, 0.5], [C, 0.0]])
	L["keeneland"] = _mk2({ "id": "keeneland", "name": "Keeneland – Turf (Breeders' Cup)", "short": "Keeneland", "country": "USA", "dir": "L", "C": 1509.0, "S": 300.0, "finish": 300.0, "width": 24.0, "hdiff": 0.5,
		"slope": "", "slopeNote": "tight American turf course", "distances": [1600, 2000, 2400], "def": 2400, "speedK": 0.99 },
		func(S, P, C, f): return [[0, 0.0], [S, 0.2], [S + P, 0.5], [C, 0.0]])
	L["flemington"] = _mk2({ "id": "flemington", "name": "Flemington – Turf", "short": "Flemington", "country": "AUS", "dir": "L", "C": 2312.0, "S": 450.0, "finish": 450.0, "width": 30.0, "hdiff": 2.0,
		"slope": "", "slopeNote": "wide course, 450 m straight", "distances": [1200, 1600, 2000, 2500, 3200], "def": 3200, "speedK": 0.985 },
		func(S, P, C, f): return [[0, 0.0], [S, 1.0], [S + P, 2.0], [C, 0.0]])
	COURSES = L
	TRACK = COURSES["tokyo"]


# =============================== GEOMETRY ===============================
static func use_course(id: String) -> Dictionary:
	TRACK = COURSES.get(id, COURSES["tokyo"])
	return TRACK

static func wrap_s(s: float) -> float:
	var C: float = TRACK.C
	return fposmod(s, C)

static func is_curve(s: float) -> bool:
	s = wrap_s(s)
	for c in TRACK.curves:
		if s >= c[0] and s < c[1]: return true
	return false

## Position on the loop (metres, y up). off = metres out from the inside rail.
static func xy(s: float, off: float) -> Vector2:
	s = wrap_s(s)
	var S: float = TRACK.S
	var r: float = TRACK.r
	var pr := PI * r
	var R: float = r + off
	var m := -1.0 if TRACK.dir == "R" else 1.0
	if s < S: return Vector2(m * (-S / 2.0 + s), -R)
	if s < S + pr:
		var a: float = -PI / 2.0 + (s - S) / r
		return Vector2(m * (S / 2.0 + R * cos(a)), R * sin(a))
	if s < 2.0 * S + pr: return Vector2(m * (S / 2.0 - (s - S - pr)), R)
	var a2 := PI / 2.0 + (s - 2.0 * S - pr) / r
	return Vector2(m * (-S / 2.0 + R * cos(a2)), R * sin(a2))

static func elevation(s: float) -> float:
	s = wrap_s(s)
	var e: Array = TRACK.elev
	for i in range(1, e.size()):
		if s <= e[i][0]:
			var s0: float = e[i - 1][0]
			var h0: float = e[i - 1][1]
			var s1: float = e[i][0]
			var h1: float = e[i][1]
			return h0 + (h1 - h0) * (s - s0) / (s1 - s0) if s1 > s0 else h1
	return float(e[e.size() - 1][1])

static func grade(s: float) -> float:
	return (elevation(s + 4.0) - elevation(s - 4.0)) / 8.0


# =============================== HORSE PARAMETERS ===============================
class Params:
	var vmax: float
	var slmax: float
	var cs: float
	var d0: float
	var gutsRes: float
	var a0: float
	var nStart: float
	var str: float
	var agi: float
	var guts: float
	var temper: float
	var sound: float
	var injMul := 1.0      # race-day injury risk multiplier (a horse running while on caution)
	var wind: float
	var stam: float
	var mass: float
	var jskill: float
	var jstart: float     # jockey attributes (Step 4): gate start, pace judgement, finishing drive, positioning
	var jpace: float
	var jfin: float
	var jtac: float

static func _s(h: Dictionary, k: String) -> float:
	return clampf(float(h.stats[k]), 1.0, 100.0) / 100.0

## Pack effect: in a race the field runs together — the pace is shared and the horses behind are carried along
## (slipstream, rhythm, jockeys holding position), so a weaker horse loses less than its solo ability gap.
## Each runner's aerobic speed, top speed and anaerobic reserve are pulled towards the field's leading group
## (the best value in the field) by PACK_F: the gaps between the horses shrink, the best horse is unchanged.
## Calibrated so finishing gaps match JRA (1st–2nd ≈ 0.25 s, 1st–5th ≈ 0.7 s, 1st–last ≈ 2.5–3 s at 1600–2000 m).
static var PACK_F := 0.3
## speed scale of the full engine for real fields, so its winning times match the quick model's (and so JRA's);
## QCal (equal fields of stat-70 horses) is built with ENGINE_K = 1
static var ENGINE_K := 0.9615

static func pack_ref(plist: Array) -> Dictionary:
	var ref := {}
	for k in ["cs", "vmax", "d0"]:
		var v := []
		for p in plist: v.append(float(p.get(k)))
		v.sort()
		ref[k] = v[v.size() - 1] if not v.is_empty() else 0.0
	return ref

static func pack_apply(p: Params, ref: Dictionary) -> void:
	if ref.is_empty() or PACK_F >= 1.0: return
	for k in ["cs", "vmax", "d0"]:
		var x: float = p.get(k)
		var r: float = ref[k]
		if x < r: p.set(k, r - (r - x) * PACK_F)
	p.gutsRes = (0.05 + 0.15 * p.guts) * p.d0

static func pack_compress(plist: Array) -> void:
	var ref := pack_ref(plist)
	for p in plist: pack_apply(p, ref)

## best racing distance from the MSTN genotype and the stamina–burst balance (m)
static func best_dist(h: Dictionary) -> float:
	return clampf({ "CC": 1350.0, "CT": 1850.0, "TT": 2400.0 }[h.gene] + (float(h.stats.stamina) - float(h.stats.burst)) * 12.0, 1000.0, 3400.0)

const DIST_K := 0.16
static var DIAG_NO_DISTF := false     # test tool

static func derive(h: Dictionary, opts: Dictionary) -> Params:
	var g: Dictionary = GENES[h.gene]
	var p := Params.new()
	var str := clampf(_s(h, "strength") + g.str, 0.0, 1.0)
	var cf: float = (1.0 + 0.01 * float(h.get("form", 0))) * float(h.get("ageF", 1.0)) * float(h.get("fitF", 1.0))   # form, age curve, fitness
	var sf: Dictionary = SURF[TRACK.surface]
	var dirt: bool = TRACK.surface == "dirt"
	var going: Dictionary = GOING[opts.going]
	# strong horses and horses that like soft ground (inherited "going" 0–100) cope better with soft turf
	var gk: float = (1.15 - 0.3 * str) * (1.35 - 0.7 * clampf(float(h.get("going", 50)) / 100.0, 0.0, 1.0))
	var goingF: float = going.dcs if dirt else 1.0 - (1.0 - going.cs) * gk
	var goingV: float = going.dvmax if dirt else 1.0 - (1.0 - going.vmax) * gk
	var apt: float = clampf(float(h.get("dirt", 50)), 0.0, 100.0) / 100.0       # 0 = turf type, 1 = dirt type
	var aptF: float = 1.0 + 0.035 * (apt - 0.5) if dirt else 1.0 + 0.025 * (0.5 - apt)
	# distance aptitude: away from the horse's best trip it loses aerobic speed (beyond it: about 1 % when 25 % too far,
	# 2.5 % when 40 % too far; half that when the race is shorter than its best) — the "preferred distance range" behind the aptitude chart
	var distF := 1.0
	if opts.has("dist") and h.has("stats") and h.stats.has("stamina") and not DIAG_NO_DISTF:
		var bd := best_dist(h)
		var x := clampf((float(opts.dist) - bd) / bd, -0.6, 0.6)
		distF = 1.0 - DIST_K * x * x * (0.5 if x < 0.0 else 1.0)   # dropping in trip costs less (speed/burst already count)
	p.d0 = (CAL.D0 + CAL.DS * _s(h, "burst")) * g.d
	p.vmax = (CAL.V0 + CAL.VS * _s(h, "speed")) * float(g.get("v", 1.0)) * cf * sf.vmax * (1.0 + (aptF - 1.0) * 0.5) * goingV * float(TRACK.get("speedK", 1.0))
	p.slmax = (6.8 + 0.8 * _s(h, "speed")) * sf.sl
	p.cs = (CAL.C0 + CAL.CS * _s(h, "stamina") + g.cs) * (1.0 + 0.015 * (_s(h, "wind") - 0.5)) * cf * goingF * sf.cs * aptF * distF * float(TRACK.get("speedK", 1.0))
	p.gutsRes = (0.05 + 0.15 * _s(h, "guts")) * p.d0
	p.a0 = CAL.A0 + CAL.AS * _s(h, "accel")
	p.nStart = 30.0 - 5.0 * _s(h, "accel")
	p.str = str
	p.agi = _s(h, "agility"); p.guts = _s(h, "guts"); p.temper = _s(h, "temper"); p.sound = _s(h, "sound"); p.injMul = float(h.get("injRisk", 1.0)); p.wind = _s(h, "wind"); p.stam = _s(h, "stamina")
	p.mass = float(h.bw) + float(h.carried)
	p.jskill = clampf(float(h.get("jockey", 75)), 0.0, 100.0) / 100.0
	var ja: Dictionary = h.get("jat", {})
	p.jstart = float(ja.get("start", p.jskill * 100.0)) / 100.0
	p.jpace = float(ja.get("pace", p.jskill * 100.0)) / 100.0
	p.jfin = float(ja.get("finish", p.jskill * 100.0)) / 100.0
	p.jtac = float(ja.get("tactics", p.jskill * 100.0)) / 100.0
	return p


# =============================== RACE STATE ===============================
class Runner:
	var h: Dictionary
	var i: int
	var p: Params
	var st: Dictionary
	var dist: float
	var lane: float
	var targetLane: float
	var v := 0.0
	var D: float
	var G: float
	var strides := 0.0
	var t0: float
	var badBreak := false
	var judg: float
	var kick: float
	var early: float
	var pullStart: float
	var pullDur: float
	var state: StringName = &"run"   # run / eased / pulling / fin / dnf
	# cached for speed (copies of h / style values)
	var front := false
	var closer := false
	var midOrCloser := false
	var carried := 57.0
	var sKf := 0.0
	var sDash := 0.0
	var sDashLen := 0.0
	var sEarly := 0.0
	var sEarlyLen := 0.0
	var sGap := 0.0
	var sLane := 0.0
	var T := 38.0
	var hr := 60.0
	var hct := 35.0
	var sl := 0.0
	var sf := 0.0
	var peakV := 0.0
	var ve: float = 0.0
	var csEff: float
	var ratio: float = 1.0
	var draft := false
	var blocked := 0.0
	var eiph := 0
	var eiphDose := 0.0
	var eiphThr: float
	var injury: Dictionary = {}
	var splits: Array = []      # [{m, t}]
	var finishT := -1.0
	var finishV := 0.0
	var draftTime := 0.0
	var wideMeters := 0.0
	var csLoss := 0.0
	var driveFrom := 0.0
	var driving_started := false
	var duelT := 0.0
	var conceded := false
	var contest := 0.0
	var posMove := false
	var nextLook := 0.0
	var drift := 0.0
	var driftS := 0.0      # drift as the horse actually moves (smoothed: no sideways jitter)
	var lv := 0.0          # lateral velocity (m/s, + = outwards): a 500 kg horse can't sidestep instantly
	var bumps := 0
	var pullLogged := false

class Race:
	var opts: Dictionary
	var course: Dictionary
	var rng: SimRng
	var cool: Dictionary = {}
	var t := 0.0
	var clock0 := -1.0          # < 0: clock not started yet
	var lead: Dictionary = {}   # mark -> leader time
	var startS: float
	var marks: Array = []
	var order: Array = []
	var events: Array = []
	var done := false
	var runners: Array = []
	var chute: Dictionary = {}  # {L, sj} or empty
	var firstCorner: float
	var lull: Dictionary = {}   # {from, to, frac} or empty
	# cached course / option values (for speed)
	var hasLull := false
	var lullFrom := 0.0
	var lullTo := 0.0
	var lullFrac := 0.0
	var chuteL := -1.0          # < 0: no starting spur
	var distF := 0.0
	var cC := 0.0
	var cR := 0.0
	var cW := 0.0
	var cFinish := 0.0
	var cStraight := false
	var cCurves := PackedFloat64Array()
	var cElevS := PackedFloat64Array()
	var cElevH := PackedFloat64Array()
	func gauss() -> float: return rng.gauss()


# =============================== RACE PATH (starting spurs) ===============================
## If the loop start point falls inside a corner, the race starts on a straight spur tangent to the loop
## that replaces the first part of that corner (race distance stays exact).
static func _setup_chute(race: Race) -> void:
	var T := race.course
	var s0 := race.startS
	var D: int = race.opts.dist
	race.chute = {}
	if T.straight: return
	var c = null
	for cv in T.curves:
		if s0 >= cv[0] and s0 < cv[1] - 1.0: c = cv
	if c == null: return
	var rem: float = c[1] - s0
	var want: float = float(T.pockets.get(D, 0.0))
	if want == 0.0 and rem > T.r * PI * 0.6: return
	var L: float = minf(rem, want if want > 0.0 else rem)
	race.chute = { "L": L, "sj": s0 + L }

static func race_on_spur(race: Race, d: float) -> bool:
	return not race.chute.is_empty() and d < race.chute.L

static func race_curve(race: Race, d: float) -> bool:
	return not race_on_spur(race, d) and is_curve(race.startS + d)

static func race_xy(race: Race, d: float, off: float) -> Vector2:
	if not race_on_spur(race, d): return xy(race.startS + d, off)
	var sj: float = race.chute.sj
	var b := xy(sj, off)
	var a := xy(sj - 0.5, off)
	var e := xy(sj + 0.5, off)
	var dir := (e - a)
	var L: float = dir.length()
	if L == 0.0: L = 1.0
	return b - dir / L * (race.chute.L - d)

static func race_elev(race: Race, d: float) -> float:
	return elevation(race.startS + d)


## fast versions of race_curve / grade using the race's cached course arrays (same arithmetic)
static func _rc(race: Race, d: float) -> bool:
	if race.chuteL >= 0.0 and d < race.chuteL: return false
	var s := fposmod(race.startS + d, race.cC)
	var c := race.cCurves
	return (s >= c[0] and s < c[1]) or (s >= c[2] and s < c[3])

static func _elev_fast(race: Race, s: float) -> float:
	s = fposmod(s, race.cC)
	var es := race.cElevS
	var eh := race.cElevH
	var n := es.size()
	for i in range(1, n):
		if s <= es[i]:
			var s0 := es[i - 1]
			var s1 := es[i]
			return eh[i - 1] + (eh[i] - eh[i - 1]) * (s - s0) / (s1 - s0) if s1 > s0 else eh[i]
	return eh[n - 1]

static func _grade_fast(race: Race, s: float) -> float:
	return (_elev_fast(race, s + 4.0) - _elev_fast(race, s - 4.0)) / 8.0


# =============================== CREATE ===============================
static func create_race(field: Array, opts_in: Dictionary) -> Race:
	var opts := { "course": "tokyo", "dist": 2400, "going": "firm", "seed": 1, "injuries": true, "eiph": true, "risk": 1.0 }
	opts.merge(opts_in, true)
	opts.dist = int(opts.dist)
	use_course(opts.course)
	var race := Race.new()
	race.opts = opts
	race.course = TRACK
	race.rng = SimRng.new(int(opts.seed))
	# marks = distances from the start at which a 200 m split ends (JRA style, measured back from the post)
	var D: int = opts.dist
	for k in range(int(floor((D - 1) / 200.0)), -1, -1):
		race.marks.append(D - 200 * k)
	race.startS = wrap_s(TRACK.finish - D)
	_setup_chute(race)
	race.chuteL = float(race.chute.L) if not race.chute.is_empty() else -1.0
	race.distF = float(D)
	race.cC = TRACK.C; race.cR = TRACK.r; race.cW = TRACK.width; race.cFinish = TRACK.finish; race.cStraight = TRACK.straight
	race.cCurves = PackedFloat64Array([TRACK.curves[0][0], TRACK.curves[0][1], TRACK.curves[1][0], TRACK.curves[1][1]])
	for e in TRACK.elev:
		race.cElevS.append(float(e[0])); race.cElevH.append(float(e[1]))
	race.firstCorner = float(D)
	var x := 0.0
	while x < D:
		if race_curve(race, x):
			race.firstCorner = x
			break
		x += 5.0
	# stayers' races: moderate start, a mid-race lull, then a long sprint
	var lw: float = clampf((D - 2200.0) / 800.0, 0.0, 1.0)
	var lf: float = maxf(1000.0, 0.4 * D)
	var lEnd: float = minf(lf + LULLLEN, D - 800.0)
	if lw > 0.0:
		race.lull = { "from": lf, "to": D - lEnd, "frac": maxf(0.0, 0.7 + race.gauss() * 0.3) / 12.2 * lw * LULLK }
		race.hasLull = true; race.lullFrom = race.lull.from; race.lullTo = race.lull.to; race.lullFrac = race.lull.frac
	var rng := race.rng
	var plist: Array = []
	for h in field: plist.append(derive(h, opts))
	pack_compress(plist)
	for p in plist:      # real (mixed) fields: the full engine's tactics and pack make it quicker than the quick model
		p.cs *= ENGINE_K; p.vmax *= ENGINE_K
	for i in field.size():
		var h: Dictionary = field[i]
		var p: Params = plist[i]
		var st: Dictionary = STYLES[h.style]
		var r := Runner.new()
		var react: float = (0.04 + (1.0 - p.temper) * 0.16 + absf(race.gauss()) * 0.07) * (1.0 - 0.8 * (p.jstart - p.jskill))   # sharp starters break quicker
		var badBreak := rng.next() < 0.06 * (1.2 - p.temper)
		if badBreak: react += 0.3 + rng.next() * 0.7
		var pullChance: float = 0.4 * pow(1.0 - p.temper, 1.5)
		r.h = h; r.i = i; r.p = p; r.st = st; r.dist = -CAL.GATE
		r.front = h.style == "front"; r.closer = h.style == "closer"; r.midOrCloser = h.style == "closer" or h.style == "mid"
		r.carried = float(h.carried)
		r.sKf = st.kf; r.sDash = st.dash; r.sDashLen = st.dashLen; r.sEarly = st.early; r.sEarlyLen = st.earlyLen; r.sGap = st.gap; r.sLane = st.lane
		r.lane = 0.8 + i * 1.15; r.targetLane = r.lane
		r.D = p.d0; r.G = p.gutsRes
		r.t0 = react; r.badBreak = badBreak
		r.judg = race.gauss() * 0.02 * (1.2 - p.jpace)
		r.kick = st.kick * (1.0 + race.gauss() * 0.06 * (1.1 - p.jfin)) * (1.0 + 0.04 * (p.jfin - p.jskill))
		r.early = race.gauss() * 0.02 + 0.03 * (p.a0 - CAL.A0 - CAL.AS / 2.0) / CAL.AS
		r.pullStart = 8.0 + rng.next() * 30.0 if rng.next() < pullChance else INF
		r.pullDur = 6.0 + rng.next() * 10.0 * (1.0 - p.temper)
		r.csEff = p.cs
		r.eiphThr = -log(1.0 - rng.next()) * 60.0 / maxf(0.01, opts.risk)
		if badBreak: race.events.append({ "t": 0.0, "i": i, "type": "", "msg": "%s missed the break" % h.name })
		race.runners.append(r)
	return race


# =============================== HELPERS ===============================
static func _free_lane(near: Array[Runner], width: float, r: Runner, cand: float, inward := false) -> bool:
	if cand < 0.6 or cand > width - 1.0: return false
	for o: Runner in near:
		if o == r or o.state == &"dnf" or o.state == &"fin": continue
		var dd: float = o.dist - r.dist
		if dd > (-1.2 if inward else -2.6) and dd < (2.6 if inward else 3.4) and absf(o.lane - cand) < 1.0: return false
	return true

static func _clear_ahead(near: Array[Runner], r: Runner, lane: float) -> float:
	var m := 25.0
	for o: Runner in near:
		if o == r or o.state == &"dnf" or o.state == &"fin": continue
		var dd: float = o.dist - r.dist
		if dd > 0.0 and dd < m and absf(o.lane - lane) < 1.0: m = dd
	return m

static func _event(race: Race, r: Runner, msg: String, type := "") -> void:
	race.events.append({ "t": race.t, "i": r.i, "type": type, "msg": "%s: %s" % [r.h.name, msg] })

static func _injure(race: Race, r: Runner) -> void:
	var tendon := r.T > 41.5 and race.rng.next() < 0.55
	var kind := "superficial digital flexor tendon strain"
	if not tendon:
		kind = ["fetlock/sesamoid injury", "cannon bone (condylar) fatigue fracture", "carpal chip injury"][int(floor(race.rng.next() * 3.0))]
	var serious := race.rng.next() < 0.3
	r.injury = { "type": kind, "serious": serious, "t": race.t }
	if serious:
		r.state = &"pulling"; _event(race, r, "pulled up - " + kind, "injury")
	else:
		r.state = &"eased"; _event(race, r, "lame, eased - " + kind, "injury")


# =============================== STEP ===============================
static func step(race: Race) -> void:
	var opts := race.opts
	var rng := race.rng
	var DTt := DT
	var going: Dictionary = GOING[opts.going]
	TRACK = race.course
	var sfc: Dictionary = SURF[TRACK.surface]
	var isDirt: bool = TRACK.surface == "dirt"
	var sfcCurve: float = sfc.curve
	var sfcHeat: float = sfc.heat
	var sfcInj: float = sfc.inj
	var goingInj: float = going.inj
	var optInj: bool = opts.injuries
	var optEiph: bool = opts.eiph
	var optRisk: float = opts.risk
	var Df := race.distF
	var trR := race.cR
	var trW := race.cW
	var trFin := race.cFinish
	var trC := race.cC
	var trC1 := race.cCurves[2]
	var trStraight := race.cStraight
	var runners := race.runners
	var hasLull := race.hasLull
	var near: Array[Runner] = []
	var leader: Runner = null
	for r: Runner in runners:
		if (r.state == &"run" or r.state == &"eased") and race.t >= r.t0 and (leader == null or r.dist > leader.dist): leader = r
	var leadEffort := leader.ve / maxf(1.0, leader.csEff) if leader != null else 1.0
	for r: Runner in runners:
		if r.state == &"dnf": continue
		if r.state == &"fin":   # pull up gradually after the post (visual only)
			r.v = maxf(6.0, r.v - 0.8 * DTt)
			r.dist += r.v * DTt * (trR / (trR + r.lane) if _rc(race, r.dist) else 1.0)
			r.strides += (r.v / maxf(r.sl, 3.0)) * DTt
			r.hr += (150.0 - r.hr) * DTt / 8.0
			continue
		var p := r.p
		if race.t < r.t0: continue
		# runners within 25 m (widest window used below), in field order
		near.clear()
		var rd := r.dist
		for o: Runner in runners:
			if o != r and absf(o.dist - rd) < 25.5: near.append(o)
		var s: float = race.startS + r.dist
		var curve := _rc(race, r.dist)
		var gr: float = _grade_fast(race, s)
		var rem: float = Df - r.dist
		var R: float = trR + r.lane if curve else INF

		# ---- 1. effort ("equivalent speed") ----
		var ve: float = r.v
		if gr > 0.0: ve += r.v * gr * 7.0 * (1.0 - 0.35 * p.str)      # uphill (Self 2012)
		else: ve += r.v * gr * 2.5                                      # downhill: small saving
		if curve:
			var ac: float = r.v * r.v / R
			ve += r.v * (sqrt(1.0 + pow(ac / G, 2)) - 1.0) * 4.0 * (1.0 - 0.5 * p.agi) * sfcCurve   # leg force on bends (Tan & Wilson 2011)
		ve *= 1.0 + 0.6 * ((r.carried - 55.0) / 500.0) * (1.0 - 0.4 * p.str)
		r.draft = false
		for o: Runner in near:
			if o == r or o.state == &"dnf" or race.t < o.t0: continue
			var dd: float = o.dist - r.dist
			if dd > 0.8 and dd < 4.0 and absf(o.lane - r.lane) < 1.1:
				r.draft = true
				break
		if r.draft:
			ve -= DRAG_SHARE * 0.13 * r.v * pow(r.v / 16.0, 2); r.draftTime += DTt      # -13% drag (Spence 2012)
			if isDirt: ve += r.v * 0.01 * (1.3 - p.temper)                              # kickback on dirt
		var pulling := race.t > r.pullStart and race.t < r.pullStart + r.pullDur and rem > 600.0
		if r.front and not r.conceded and r.dist < race.firstCorner + 200.0 and r.dist > 50.0:
			for o: Runner in near:
				if o != r and o.front and not o.conceded and o.state == &"run" and absf(o.dist - r.dist) < 2.5:
					ve += r.v * 0.012 * CONTK * clampf(350.0 / maxf(100.0, race.firstCorner), 0.6, 2.5); r.contest += DTt
					break
		if pulling:
			ve += 0.8
			if not r.pullLogged:
				r.pullLogged = true; _event(race, r, "pulling hard, fighting the jockey", "pull")
		r.ve = ve
		var ratio: float = ve / r.v if r.v > 2.0 else 1.0
		r.ratio = ratio
		var ratioA: float = pow(ratio, PACE_A) if PACE_A != 1.0 else ratio
		var ratioD: float = pow(ratio, PACE_D) if PACE_D != 1.0 else ratio

		# ---- 2. energy: critical speed + anaerobic reserve ----
		if r.ve > r.csEff and r.csEff > 0.0: r.csLoss = minf(0.08, r.csLoss + (r.ve / r.csEff - 1.0) * SLOWK * (1.2 - 0.4 * p.stam) * DTt)
		var cs: float = p.cs * (1.0 - EIPH_CS_LOSS[r.eiph]) * (1.0 - r.csLoss) * (1.0 - TFAT_K * maxf(0.0, race.t - r.t0 - TFAT_T0) * (1.0 - 0.6 * p.stam))
		r.csEff = cs
		if ve > cs: r.D -= (ve - cs) * DTt
		else: r.D = minf(p.d0, r.D + 0.25 * (cs - ve) * DTt)
		if not r.driving_started:
			var vk: float = 0.95 * p.vmax
			var Dav0: float = maxf(0.0, r.D) + r.G * 0.75
			var tEnd: float = race.distF / 16.3   # rough race length: allow for the aerobic fatigue still to come
			var csAhead: float = cs * (1.0 - TFAT_PROJ * TFAT_K * maxf(0.0, tEnd - maxf(race.t - r.t0, TFAT_T0)) * (1.0 - 0.6 * p.stam))
			var need: float = Dav0 * vk / maxf(0.3, vk * r.ratio - csAhead) * (1.0 + 4.0 * r.judg)
			var kickD: float = maxf(r.kick, minf(950.0, race.lullTo) - 50.0 + (100.0 if r.closer else 0.0)) if hasLull else r.kick
			if rem < minf(1150.0 if hasLull else 1000.0, maxf(kickD, need)):
				r.driveFrom = r.dist; r.driving_started = true
		var driving := r.driving_started and r.state == &"run"
		if r.D < 0.0 and driving and r.G > 0.0:
			r.G += r.D; r.D = 0.0
			if r.G < 0.0:
				r.D = r.G; r.G = 0.0
		if driving and rem < 400.0 and r.G > 0.0:
			r.D += r.G; r.G = 0.0                       # guts: last reserve in the final 400 m
		r.D = maxf(r.D, -p.d0 * 0.2)
		var f: float = clampf(r.D / p.d0, 0.0, 1.0)
		var empty := r.D <= 0.0 and r.G <= 0.01

		# ---- 3. speed limits (reachable top speed falls as the reserve empties) ----
		var fTot: float = (maxf(0.0, r.D) + r.G) / (p.d0 + p.gutsRes)
		var fat: float = minf(1.0, FAT0 + 0.02 * p.guts + (1.0 - FAT0) * fTot / FATK)
		var vmaxEff: float = p.vmax * fat
		if gr < 0.0: vmaxEff *= 1.0 + gr * 1.5 * (1.0 - 0.4 * p.agi)

		# ---- 4. tactics (target speed) ----
		var vt: float
		if not driving:
			var spend: float = maxf(0.0, r.D - r.sKf * p.d0)
			var span: float = maxf(150.0, rem - r.kick)
			var k: float = 1.0 / maxf(0.5, 1.0 - spend / span) * (1.0 + r.judg)
			if r.dist < r.sDashLen: k += r.sDash * DASH
			elif r.dist < r.sEarlyLen: k += r.sEarly
			if r.dist > r.sEarlyLen and rem > 900.0: k -= LONGK * clampf((Df - 1800.0) / 1600.0, 0.0, 1.0)
			var behindL: float = (leader.dist - r.dist) / LENGTH_M if leader != null else 0.0
			if r.front and rem > 700.0 and r.dist > 150.0:
				var rival := false
				for o: Runner in near:
					if o != r and o.front and o.state == &"run" and absf(o.dist - r.dist) < 3.6:
						rival = true
						break
				if r.conceded: k -= 0.02
				elif rival or behindL > 0.5:
					k += 0.03 * (1.0 - 0.7 * p.jtac) * (1.2 - p.temper); r.duelT += DTt
				if not r.conceded and r.duelT > 3.0 and behindL > 0.3 and r.dist > minf(race.firstCorner, 500.0) * 0.5 and rng.next() < DTt * (0.15 + 0.35 * p.jtac):
					r.conceded = true
			var dashing: bool = r.dist < r.sDashLen
			if dashing: k += r.early
			vt = minf(cs * k / ratioA, p.vmax if dashing else p.vmax * 0.94)
			if hasLull and r.dist > race.lullFrom and rem > race.lullTo and leader != null:
				var nc := 0
				for o: Runner in runners:
					if o.state == &"run" and absf(o.dist - leader.dist) < 2.5 and o.front: nc += 1
				var lullV: float = leader.p.cs * (1.0 - race.lullFrac * (0.4 if nc >= 2 else 1.0)) / maxf(0.9, leader.ratio)
				if r == leader: vt = minf(vt, lullV)
				else: vt = minf(vt, maxf(lullV, leader.v + ((leader.dist - r.dist) / LENGTH_M - r.sGap) * 0.12))
			if not r.front and r != leader and r.dist > 250.0 and leader != null:
				var tgt: float = r.sGap + (4.0 * p.jpace if leadEffort > 1.05 else 0.0) - (2.0 * p.jpace if leadEffort < 1.0 else 0.0)
				var vFollow: float = leader.v + clampf((behindL - tgt) * 0.12, -0.6, 0.6)
				var effCap: float = cs * (1.04 + GAPK * (1.0 - p.jpace)) / ratioA
				if behindL > tgt + 1.0: vt = maxf(vt, minf(vFollow, effCap))
				elif behindL < tgt - 2.0: vt = minf(vt, vFollow)
		else:
			var Dav: float = maxf(0.0, r.D) + (r.G if rem < 450.0 else r.G * 0.5)
			var over: float = OVERPUSH * (1.2 - p.jpace)
			vt = cs / maxf(0.05, 1.0 - Dav / maxf(rem, 1.0)) / ratioD * (1.0 + r.judg + over)
		if pulling: vt *= 1.04
		if empty: vt = minf(vt, r.v * (cs / maxf(ve, 0.1)) * (0.95 + 0.04 * p.guts))
		var blocker: Runner = null
		var bdd := 0.0
		for o: Runner in near:
			if o == r or o.state == &"dnf" or o.state == &"fin" or race.t < o.t0: continue
			var dd2: float = o.dist - r.dist
			if dd2 > 0.0 and dd2 < 9.0 and absf(o.lane - r.lane) < 1.0:
				if blocker == null or dd2 < bdd:
					blocker = o; bdd = dd2
		# a jockey sees trouble coming: the allowed closing speed shrinks steadily with the gap, so the horse
		# behind eases off over several strides instead of snatching up on the heels
		var vFol: float = blocker.v + (bdd - 2.6) * 0.5 if blocker != null else INF
		if blocker != null and vt > vFol:
			vt = minf(vt, vFol)
			if bdd < 5.0: r.blocked += DTt
		else: r.blocked = 0.0
		var checking := blocker != null and bdd < 2.8 and r.v > blocker.v
		if r.state == &"eased": vt = minf(vt, 11.0)
		if r.state == &"pulling": vt = 0.0
		if r.eiph >= 4 and r.state == &"run":
			r.state = &"pulling"; _event(race, r, "pulled up - epistaxis (severe EIPH, grade 4)", "injury"); vt = 0.0
		vt = minf(vt, vmaxEff)

		# ---- 5. speed update (force-velocity on true top speed) ----
		if vt > r.v:
			var a: float = p.a0 * (1.0 - r.v / p.vmax) * sqrt(535.0 / p.mass) - G * maxf(0.0, gr) * 0.5
			r.v = minf(vt, r.v + maxf(a, 0.05) * DTt)
		else:
			# real horses shed speed over several strides; only a jockey checking right on the heels brakes hard
			var dmax: float = DEC_PULL if r.state == &"pulling" else (DEC_CHECK if checking else (DEC_EASED if r.state == &"eased" else (DEC_EMPTY if empty else DEC_EASE)))
			var dec: float = minf(dmax, maxf(0.12, (r.v - vt) * 0.9))
			r.v = maxf(vt, r.v - dec * DTt)
		r.peakV = maxf(r.v, r.peakV - 0.03 * DTt)

		# ---- 6. lanes ----
		var wantIn: float = r.sLane
		var react: float = 0.15 + 0.8 * (1.0 - p.jtac)
		var finalTurn: bool = rem < trFin + (trC - trC1) + 60.0 and rem > trFin * 0.6
		if not r.posMove and finalTurn and r.midOrCloser and _clear_ahead(near, r, r.lane) < 8.0 and rng.next() < (0.03 + 0.1 * p.jtac):
			r.posMove = true
			for c in [r.lane + 1.3, r.lane + 2.6, r.lane + 3.9]:
				if _free_lane(near, trW, r, c):
					r.targetLane = c
					break
		var inStraight: bool = (trStraight or fposmod(race.startS + r.dist, trC) < trFin) and rem <= trFin
		if driving and inStraight and r.state == &"run" and race.t >= r.nextLook and absf(r.targetLane - r.lane) < 0.3:
			r.nextLook = race.t + 0.3 + 0.6 * (1.0 - p.jtac)
			var cur: float = _clear_ahead(near, r, r.lane)
			if cur < 12.0:
				var best := -1.0
				var bestScore := cur + 2.0
				var c2 := maxf(0.8, r.lane - 2.4)
				while c2 <= minf(trW - 1.0, r.lane + 4.8):
					if absf(c2 - r.lane) >= 0.5:
						var sc: float = _clear_ahead(near, r, c2) - absf(c2 - r.lane) * 0.8
						if sc > bestScore and _free_lane(near, trW, r, r.lane + signf(c2 - r.lane) * 1.0, true):
							bestScore = sc; best = c2
					c2 += 1.2
				if best >= 0.0: r.targetLane = best
		var behind0: float = (leader.dist - r.dist) / LENGTH_M if leader != null else 0.0
		if (r.blocked > react and (driving or rem < 900.0)) or (r.blocked > 1.0 + react and behind0 > r.sGap + 1.0):
			if absf(r.targetLane - r.lane) < 0.2:
				var best2 := -1.0
				var bestScore2 := _clear_ahead(near, r, r.lane) + 3.0
				for c3 in [r.lane - 1.2, r.lane + 1.2, r.lane + 2.4, r.lane - 2.4]:
					if not _free_lane(near, trW, r, c3): continue
					var sc2: float = _clear_ahead(near, r, c3) - absf(c3 - r.lane) * (3.0 if curve else 1.5)
					if sc2 > bestScore2:
						bestScore2 = sc2; best2 = c3
				if best2 >= 0.0: r.targetLane = best2
		elif not driving and r.lane > wantIn + 0.3 and absf(r.targetLane - r.lane) < 0.2 and _free_lane(near, trW, r, r.lane - 0.6, true):
			r.targetLane = maxf(wantIn, r.lane - 0.6)
		if r.state != &"run": r.targetLane = maxf(r.targetLane, r.lane)
		# sideways movement has inertia: a ~500 kg horse builds up and sheds lateral speed gradually
		var latV: float = 0.6 + 0.5 * p.agi if driving else 0.3 + 0.25 * p.agi
		var latA: float = LAT_A * (0.6 + 0.8 * p.agi) * sqrt(535.0 / p.mass) * (1.0 if driving else 0.75)
		var err: float = r.targetLane - r.lane
		var want: float = signf(err) * minf(latV, sqrt(1.6 * latA * absf(err))) if absf(err) > 0.02 else 0.0
		r.lv = move_toward(r.lv, want, latA * DTt)
		if r.lv != 0.0:
			var nl: float = r.lane + r.lv * DTt
			var ok := true
			for o: Runner in near:
				if o == r or o.state == &"dnf" or o.state == &"fin": continue
				var dd3: float = o.dist - r.dist
				var ol: float = o.lane if driving else (o.lane + o.targetLane) / 2.0
				if absf(dd3) < (2.4 if driving else 2.8) and absf(ol - nl) < (0.78 if driving else 1.05) and absf(ol - nl) < absf(ol - r.lane):
					ok = false
					break
			if ok: r.lane = nl
			else:
				r.targetLane = r.lane; r.lv = move_toward(r.lv, 0.0, 3.0 * latA * DTt)
		if r.state == &"run" or r.state == &"eased":
			var sig: float = DRIFT * (1.15 - p.agi) * (1.2 if driving else 0.4) * (1.0 + (1.0 - f)) * sqrt(535.0 / p.mass)
			if race.t - r.t0 < 3.0: sig *= 1.0 + 3.0 * (1.1 - p.temper)
			r.drift = r.drift * (1.0 - DTt / 2.0) + race.gauss() * sig * sqrt(DTt)
			r.driftS += (r.drift - r.driftS) * DTt / 0.7
			r.lane = clampf(r.lane + r.driftS * DTt, 0.5, trW - 0.5)
		if (r.lane <= 0.5 and r.lv < 0.0) or (r.lane >= trW - 0.5 and r.lv > 0.0): r.lv = 0.0     # against the rail
		# contact (bumping): heavier/stronger horse pushes the other away; both lose speed and a little energy
		for o: Runner in near:
			if o == r or o.state == &"dnf" or o.state == &"fin" or race.t < o.t0: continue
			var dd4: float = o.dist - r.dist
			var dl2: float = o.lane - r.lane
			if absf(dd4) > 1.3 or absf(dl2) > 0.75: continue
			var ov: float = 0.75 - absf(dl2)
			var wr: float = p.mass * (0.6 + 0.8 * p.str)
			var wo: float = o.p.mass * (0.6 + 0.8 * o.p.str)
			var sg := -1.0 if dl2 >= 0.0 else 1.0
			r.lane = clampf(r.lane + sg * ov * 0.06 * wo / (wr + wo), 0.5, trW - 0.5)
			o.lane = clampf(o.lane - sg * ov * 0.06 * wr / (wr + wo), 0.5, trW - 0.5)
			r.lv = clampf(r.lv + sg * ov * 0.6 * wo / (wr + wo) * DTt / 0.05, -1.0, 1.0)
			o.lv = clampf(o.lv - sg * ov * 0.6 * wr / (wr + wo) * DTt / 0.05, -1.0, 1.0)
			r.drift *= 0.5; o.drift *= 0.5; r.driftS *= 0.5; o.driftS *= 0.5
			var key := "%d-%d" % [mini(r.i, o.i), maxi(r.i, o.i)]
			if float(race.cool.get(key, -9.0)) > race.t: continue
			race.cool[key] = race.t + 1.5
			var sev: float = clampf(ov / 0.75, 0.0, 1.0) * minf(1.0, r.v / 14.0)
			var lr: float = sev * (wo / (wr + wo)) * (1.3 - 0.6 * p.temper)
			var lo: float = sev * (wr / (wr + wo)) * (1.3 - 0.6 * o.p.temper)
			r.v = maxf(0.0, r.v - lr * 0.5); o.v = maxf(0.0, o.v - lo * 0.5); r.D -= sev * 3.0; o.D -= sev * 3.0
			r.bumps += 1; o.bumps += 1
			if sev > 0.3:
				var loser: Runner = r if lr >= lo else o
				var winner: Runner = o if lr >= lo else r
				race.events.append({ "t": race.t, "i": loser.i, "type": "bump", "msg": "%s bumped by %s" % [loser.h.name, winner.h.name] })
			if optInj and rng.next() < sev * 0.0006 * optRisk * maxf(r.p.injMul, o.p.injMul): _injure(race, r if lr >= lo else o)

		# ---- 7. progress ----
		var railRatio: float = trR / (trR + r.lane) if curve else 1.0
		var ds: float = r.v * DTt * railRatio
		var prev: float = r.dist
		r.dist += ds
		if curve: r.wideMeters += r.v * DTt - ds
		var tEnd: float = race.t + DTt
		var vr: float = maxf(r.v * railRatio, 0.01)
		if prev < 0.0 and r.dist >= 0.0:
			var tc: float = tEnd - r.dist / vr
			if race.clock0 < 0.0 or tc < race.clock0: race.clock0 = tc
		var c0 := 0.0 if race.clock0 < 0.0 else race.clock0
		for m in race.marks:
			if prev < m and r.dist >= m:
				var tm: float = tEnd - (r.dist - m) / vr - c0
				r.splits.append({ "m": m, "t": tm })
				if not race.lead.has(m) or tm < race.lead[m]: race.lead[m] = tm

		# ---- 8. physiology outputs ----
		r.sl = p.slmax * pow(clampf(r.v / p.vmax, 0.01, 1.05), 0.35) * (1.0 - 0.03 * (1.0 - f)) * (0.65 + 0.27 * minf(1.0, r.strides / 12.0) + 0.08 * clampf((r.strides - 12.0) / (p.nStart - 12.0), 0.0, 1.0))
		r.sf = r.v / r.sl if r.v > 0.5 else 0.0
		r.strides += r.sf * DTt
		var hrT: float = minf(226.0, 70.0 + 140.0 * clampf(ve / cs, 0.0, 1.12))
		r.hr += (hrT - r.hr) * DTt / 4.0
		r.hct = 35.0 + 27.0 * minf(1.0, (race.t - r.t0) / 20.0)                     # splenic contraction
		r.T += DTt * (0.055 * pow(r.v / 16.0, 2) * ratio * goingInj * sfcHeat - 0.006 * (r.T - 38.0))   # SDFT core temp

		# ---- 9. injury hazard (per stride) ----
		if optInj and r.injury.is_empty() and r.v > 8.0:
			var mS: float = exp(1.6 * (0.5 - p.sound))
			var mF: float = 1.0 + 2.0 * pow(1.0 - f, 2)
			var drop: float = maxf(0.0, (r.peakV - r.v) / 0.1) if r.D <= 0.2 * p.d0 else 0.0
			var mW: float = minf(5.0, pow(1.18, drop))                                   # speed drop -> risk (Wong 2023)
			var mT: float = exp(0.35 * maxf(0.0, r.T - 41.0))
			var mV: float = pow(r.v / 16.0, 4)
			var haz: float = INJ_BASE * p.injMul * optRisk * mS * mF * mW * mT * mV * goingInj * sfcInj * r.sf * DTt
			if rng.next() < haz: _injure(race, r)
		# ---- 10. EIPH ----
		if optEiph and r.eiph < 4 and r.state == &"run":
			var e: float = maxf(0.0, ve / cs - 0.92)
			r.eiphDose += DTt * e * (1.0 + 60.0 * maxf(0.0, gr)) * (1.5 - p.wind) * (r.hct / 60.0)
			if r.eiphDose > r.eiphThr:
				var u: float = pow(rng.next(), 0.6 + 0.8 * p.wind)
				var gg := 1 if u < 0.55 else (2 if u < 0.84 else (3 if u < 0.992 else 4))
				if gg > r.eiph:
					r.eiph = gg
					if gg < 4: _event(race, r, "lung bleeding (EIPH grade %d)" % gg, "eiph")
				r.eiphThr += -log(1.0 - rng.next()) * 60.0 / maxf(0.01, optRisk)

		# ---- finish / stop ----
		if r.dist >= Df and r.state != &"dnf":
			r.finishT = tEnd - (r.dist - Df) / vr - maxf(0.0, race.clock0); r.state = &"fin"; r.finishV = r.v; race.order.append(r)
		elif r.state == &"pulling" and r.v <= 0.01:
			r.state = &"dnf"; r.v = 0.0
	race.t += DTt
	var all_done := true
	for r in race.runners:
		if r.state != &"fin" and r.state != &"dnf":
			all_done = false
			break
	if all_done or race.t > 900.0: race.done = true


# =============================== RESULTS ===============================
static func margin_text(l: float) -> String:
	if l < 0.02: return "Dead heat"
	if l < 0.1: return "Nose"
	if l < 0.2: return "Head"
	if l < 0.35: return "Neck"
	if l < 0.6: return "1/2"
	if l < 0.85: return "3/4"
	if l >= 10.0: return "Distance"
	if l >= 2.0:
		var hh := roundf(l * 2.0) / 2.0
		return str(int(floor(hh))) + (" 1/2" if fmod(hh, 1.0) != 0.0 else "")
	var q := roundf(l * 4.0) / 4.0
	var w := int(floor(q))
	var fr := q - w
	return str(w) + (" 1/4" if fr == 0.25 else (" 1/2" if fr == 0.5 else (" 3/4" if fr == 0.75 else "")))

static func fmt_time(t: float) -> String:
	if t < 0.0: return "-"
	var m := int(floor(t / 60.0))
	return "%d:%04.1f" % [m, fmod(t, 60.0)]

static func results(race: Race) -> Dictionary:
	var fin := SimUtil.stable_sort(race.order, func(a, b): return a.finishT - b.finishT)
	var rows: Array = []
	for k in fin.size():
		var r: Runner = fin[k]
		var l := 0.0
		if k > 0: l = (r.finishT - fin[k - 1].finishT) * r.finishV / LENGTH_M
		var last3f := -1.0
		for x in r.splits:
			if x.m == race.opts.dist - 600: last3f = r.finishT - x.t
		var notes: PackedStringArray = []
		if r.badBreak: notes.append("missed break")
		if not r.injury.is_empty(): notes.append("injury: " + r.injury.type)
		if r.eiph > 0: notes.append("EIPH g%d" % r.eiph)
		if r.pullLogged: notes.append("pulled hard")
		if r.bumps > 2: notes.append("bumped %dx" % r.bumps)
		rows.append({ "pos": k + 1, "r": r, "name": r.h.name, "time": r.finishT, "margin": margin_text(l) if k > 0 else "", "last3f": last3f, "notes": "; ".join(notes) })
	for r in race.runners:
		if r.state == "dnf":
			var why := "pulled up"
			if not r.injury.is_empty(): why = "pulled up: " + r.injury.type
			elif r.eiph >= 4: why = "pulled up: epistaxis"
			rows.append({ "pos": -1, "r": r, "name": r.h.name, "time": -1.0, "margin": "", "last3f": -1.0, "notes": why })
	# race laps: time of the leader at each pole (JRA style)
	var laps: Array = []
	var pt := 0.0
	for m in race.marks:
		if not race.lead.has(m): break
		laps.append(race.lead[m] - pt); pt = race.lead[m]
	var wlaps: Array = []
	if not fin.is_empty():
		var q := 0.0
		for x in fin[0].splits:
			wlaps.append(x.t - q); q = x.t
	var D: int = race.opts.dist
	var f1000 := float(race.lead[1000]) if race.lead.has(1000) else -1.0
	var l3 := float(race.lead[D] - race.lead[D - 600]) if race.lead.has(D) and race.lead.has(D - 600) else -1.0
	return { "rows": rows, "laps": laps, "wlaps": wlaps, "first1000": f1000, "raceL3F": l3 }

static func race_clock(race: Race) -> float:
	return 0.0 if race.clock0 < 0.0 else maxf(0.0, race.t - race.clock0)

static func run_headless(field: Array, opts: Dictionary) -> Race:
	var race := create_race(field, opts)
	while not race.done: step(race)
	return race

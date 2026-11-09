class_name Bloodlines
extends RefCounted
## Real horse names for the stud book (Step 3). Names, birth years and pedigrees are real; every stat, gene and
## breeding value is a GAME ESTIMATE made up from the horse's race record (not real data).
## Sources for 2026 fees: Shadai Stallion Station 2026 fee list (announced 25 Nov 2025); other studs where known
## (marked ~ = estimate). Overseas: Thoroughbred Racing "ten most expensive sires for 2026".

## Historic horses (ancestors), oldest first: [name, sex, born, sire, dam, q (class 50–95), MSTN gene, dirt 0–100, line root]
## q is used to make up stats: 95 = all-time great, 88 = champion, 82 = G1 winner, 76 = graded winner, 65 = broodmare.
const HIST := [
	["Native Dancer", "M", 1950, null, null, 90, "CT", 50, false],
	["Nearctic", "M", 1954, null, null, 80, "CT", 50, false],
	["Turn-To", "M", 1951, null, null, 78, "CT", 50, false],
	["Natalma", "F", 1957, "Native Dancer", null, 72, "CT", 50, false],
	["Northern Dancer", "M", 1961, "Nearctic", "Natalma", 90, "CT", 45, true],
	["Hail to Reason", "M", 1958, "Turn-To", null, 82, "CT", 45, false],
	["Raise a Native", "M", 1961, "Native Dancer", null, 84, "CC", 60, false],
	["Nijinsky", "M", 1967, "Northern Dancer", null, 94, "TT", 35, false],
	["Halo", "M", 1969, "Hail to Reason", null, 80, "CT", 50, false],
	["Roberto", "M", 1969, "Hail to Reason", null, 86, "CT", 40, true],
	["Mr. Prospector", "M", 1970, "Raise a Native", null, 80, "CC", 70, true],
	["Lyphard", "M", 1969, "Northern Dancer", null, 84, "CT", 35, false],
	["Northern Taste", "M", 1971, "Northern Dancer", null, 80, "CT", 40, false],
	["Danzig", "M", 1977, "Northern Dancer", null, 78, "CC", 55, false],
	["Nureyev", "M", 1977, "Northern Dancer", null, 84, "CT", 35, false],
	["Storm Bird", "M", 1978, "Northern Dancer", null, 82, "CT", 50, false],
	["Sadler's Wells", "M", 1981, "Northern Dancer", null, 86, "TT", 25, false],
	["Kris S.", "M", 1977, "Roberto", null, 74, "CT", 50, false],
	["Silver Hawk", "M", 1979, "Roberto", null, 80, "TT", 35, false],
	["Brian's Time", "M", 1985, "Roberto", null, 80, "TT", 55, false],
	["Maruzensky", "M", 1974, "Nijinsky", null, 88, "CT", 45, false],
	["Tony Bin", "M", 1983, null, null, 88, "TT", 30, false],
	["Sakura Yutaka O", "M", 1982, null, null, 84, "CT", 40, false],
	["Mejiro McQueen", "M", 1987, null, null, 90, "TT", 40, false],
	["Dancing Brave", "M", 1983, "Lyphard", null, 92, "CT", 30, false],
	["Storm Cat", "M", 1983, "Storm Bird", null, 80, "CC", 65, false],
	["Danehill", "M", 1986, "Danzig", null, 80, "CC", 45, false],
	["Unbridled", "M", 1987, "Mr. Prospector", null, 84, "CT", 85, false],
	["Seeking the Gold", "M", 1985, "Mr. Prospector", null, 80, "CT", 80, false],
	["Miesque", "F", 1984, "Nureyev", null, 90, "CT", 30, false],
	["Urban Sea", "F", 1989, null, null, 86, "CT", 30, false],
	["Kingmambo", "M", 1990, "Mr. Prospector", "Miesque", 84, "CT", 50, false],
	["Sunday Silence", "M", 1986, "Halo", null, 94, "CT", 45, true],
	["Grass Wonder", "M", 1995, "Silver Hawk", null, 88, "CT", 40, false],
	["Sakura Bakushin O", "M", 1989, "Sakura Yutaka O", null, 87, "CC", 40, false],
	["King Halo", "M", 1995, "Dancing Brave", null, 80, "CC", 35, false],
	["Unbridled's Song", "M", 1993, "Unbridled", null, 82, "CC", 85, false],
	["Galileo", "M", 1998, "Sadler's Wells", "Urban Sea", 90, "TT", 20, false],
	["Dubai Millennium", "M", 1996, "Seeking the Gold", null, 92, "CT", 60, false],
	["Symboli Kris S", "M", 1999, "Kris S.", null, 88, "TT", 40, false],
	["Wind in Her Hair", "F", 1991, null, null, 80, "CT", 30, false],
	["Deep Impact", "M", 2002, "Sunday Silence", "Wind in Her Hair", 95, "CT", 30, false],
	["Black Tide", "M", 2001, "Sunday Silence", "Wind in Her Hair", 78, "CT", 35, false],
	["Irish Dance", "F", 1990, "Tony Bin", null, 74, "TT", 30, false],
	["Heart's Cry", "M", 2001, "Sunday Silence", "Irish Dance", 89, "TT", 35, false],
	["Stay Gold", "M", 1994, "Sunday Silence", null, 82, "TT", 35, false],
	["Campaign Girl", "F", 1987, "Maruzensky", null, 62, "CT", 40, false],
	["Special Week", "M", 1995, "Sunday Silence", "Campaign Girl", 90, "TT", 35, false],
	["Fuji Kiseki", "M", 1992, "Sunday Silence", null, 84, "CC", 45, false],
	["Daiwa Major", "M", 2001, "Sunday Silence", null, 86, "CT", 45, false],
	["Gold Allure", "M", 1999, "Sunday Silence", null, 85, "CT", 90, false],
	["Agnes Tachyon", "M", 1998, "Sunday Silence", null, 86, "CT", 40, false],
	["Manhattan Cafe", "M", 1998, "Sunday Silence", null, 87, "TT", 35, false],
	["Manfath", "F", 1991, null, null, 64, "CT", 40, false],
	["King Kamehameha", "M", 2001, "Kingmambo", "Manfath", 91, "CT", 55, false],
	["Kurofune", "M", 1998, "French Deputy", null, 88, "CT", 85, false],
	["Air Groove", "F", 1993, "Tony Bin", null, 90, "CT", 35, false],
	["Kind", "F", 2001, "Danehill", null, 72, "CC", 30, false],
	["Frankel", "M", 2008, "Galileo", "Kind", 95, "CT", 30, false],
	["Dubawi", "M", 2002, "Dubai Millennium", null, 88, "CT", 45, false],
	["Sea The Stars", "M", 2006, "Cape Cross", "Urban Sea", 95, "CT", 30, false],
	["Henny Hughes", "M", 2003, "Hennessy", null, 84, "CC", 95, false],
	["Screen Hero", "M", 2004, "Grass Wonder", null, 86, "CT", 40, false],
	["Cesario", "F", 2002, "Special Week", null, 86, "CT", 30, false],
	["Lady Blossom", "F", 1996, "Storm Cat", null, 60, "CC", 50, false],
	["Catequil", "F", 1990, "Storm Cat", null, 66, "CC", 50, false],
	["Loves Only Me", "F", 2006, "Storm Cat", null, 60, "CC", 50, false],
	["Sugar Heart", "F", 2005, "Sakura Bakushin O", null, 55, "CC", 40, false],
	["Oriental Art", "F", 1997, "Mejiro McQueen", null, 66, "CT", 40, false],
	["Duramente", "M", 2012, "King Kamehameha", null, 91, "CT", 40, false],
]
## parents that only appear as names (no record of their own pedigree here)
const STUBS := { "French Deputy": ["M", 1992, 82, "CT", 85], "Cape Cross": ["M", 1994, 82, "CT", 40], "Hennessy": ["M", 1993, 80, "CC", 90] }

## Historic sires whose foals are still racing: covering seasons [from, to]
const DEAD_SIRES := {
	"Deep Impact": [2007, 2019], "King Kamehameha": [2005, 2018], "Heart's Cry": [2007, 2022], "Duramente": [2017, 2021],
	"Black Tide": [2008, 2024], "Daiwa Major": [2008, 2022], "Manhattan Cafe": [2003, 2015], "Kurofune": [2003, 2021],
	"Henny Hughes": [2008, 2025], "Gold Allure": [2004, 2016], "Stay Gold": [1999, 2014], "Special Week": [2000, 2017],
	"Symboli Kris S": [2005, 2018], "Fuji Kiseki": [1996, 2011], "Agnes Tachyon": [2003, 2008], "Sakura Bakushin O": [1995, 2010],
}

## Stallions in Japan in 2026: [name, born, sire, dam (null = unnamed mare), damsire, fee ¥M 2026 (negative = estimate),
##                             q, MSTN gene, dirt, first season at stud]
const JP := [
	["Kitasan Black", 2012, "Black Tide", "Sugar Heart", "Sakura Bakushin O", 25.0, 91, "TT", 30, 2018],
	["Equinox", 2019, "Kitasan Black", null, "King Halo", 25.0, 94, "CT", 30, 2024],
	["Kizuna", 2010, "Deep Impact", "Catequil", "Storm Cat", 20.0, 86, "CT", 45, 2016],
	["Contrail", 2017, "Deep Impact", null, "Unbridled's Song", 18.0, 91, "CT", 35, 2022],
	["Epiphaneia", 2010, "Symboli Kris S", "Cesario", "Special Week", 15.0, 88, "CT", 35, 2016],
	["Lord Kanaloa", 2008, "King Kamehameha", "Lady Blossom", "Storm Cat", 12.0, 91, "CC", 50, 2014],
	["Swarve Richard", 2014, "Heart's Cry", null, "Unbridled's Song", 12.0, 86, "CT", 40, 2019],
	["Saturnalia", 2016, "Lord Kanaloa", "Cesario", "Special Week", 10.0, 84, "CT", 35, 2021],
	["Do Deuce", 2019, "Heart's Cry", null, "Vindication", 10.0, 89, "CT", 30, 2025],
	["Real Steel", 2012, "Deep Impact", "Loves Only Me", "Storm Cat", 10.0, 83, "CT", 60, 2017],
	["Drefong", 2013, "Gio Ponti", null, "Ghostzapper", 8.0, 84, "CC", 95, 2018],
	["Nadal", 2017, "Blame", null, "Pulpit", 8.0, 82, "CT", 95, 2021],
	["Maurice", 2011, "Screen Hero", null, "Caerleon", 6.0, 90, "CT", 40, 2017],
	["Admire Mars", 2016, "Daiwa Major", null, "Medaglia d'Oro", 5.0, 84, "CC", 40, 2021],
	["Rulership", 2007, "King Kamehameha", "Air Groove", "Tony Bin", 4.0, 84, "CT", 50, 2013],
	["Efforia", 2018, "Epiphaneia", null, "Heart's Cry", 4.0, 89, "CT", 35, 2023],
	["Siskin", 2017, "First Defence", null, "Oasis Dream", 4.0, 82, "CC", 45, 2021],
	["Orfevre", 2008, "Stay Gold", "Oriental Art", "Mejiro McQueen", 3.5, 92, "TT", 50, 2014],
	["Schnell Meister", 2018, "Kingman", null, "Soldier Hollow", 3.5, 84, "CT", 35, 2024],
	["Chrysoberyl", 2016, "Gold Allure", null, "El Prado", 2.5, 87, "CT", 100, 2021],
	["Rey de Oro", 2014, "King Kamehameha", null, "Symboli Kris S", 2.0, 86, "CT", 40, 2019],
	["Shahryar", 2018, "Deep Impact", null, "Essence of Dubai", 2.0, 85, "CT", 30, 2024],
	["Mind Your Biscuits", 2013, "Posse", null, "Toccet", 2.0, 82, "CC", 95, 2019],
	["Gold Ship", 2009, "Stay Gold", null, "Mejiro McQueen", -2.0, 88, "TT", 40, 2016],
	["Isla Bonita", 2011, "Fuji Kiseki", null, "Cozzene", 1.5, 82, "CT", 45, 2016],
	["Grenadier Guards", 2017, "Frankel", null, null, 1.5, 80, "CC", 40, 2021],
	["Hot Rod Charlie", 2018, "Oxbow", null, "Indian Charlie", 1.5, 82, "CT", 95, 2023],
	["Asia Express", 2011, "Henny Hughes", null, "Running Stag", 1.2, 78, "CC", 95, 2016],
	["Indy Champ", 2015, "Stay Gold", null, "Kingmambo", 1.2, 83, "CT", 40, 2022],
	["Danon Kingly", 2016, "Deep Impact", null, "Storm Cat", 1.0, 82, "CT", 35, 2023],
	["Satono Crown", 2012, "Marju", null, "Rossini", 1.0, 82, "CT", 40, 2018],
	["Fast Force", 2016, "Lord Kanaloa", null, "Sakura Bakushin O", 1.0, 80, "CC", 45, 2022],
	["Rion Diez", 2013, "King Kamehameha", "Cesario", "Special Week", -6.0, 80, "CT", 50, 2017],
	["Mozu Ascot", 2014, "Frankel", null, "Hennessy", -1.5, 83, "CT", 75, 2021],
]
## parents of JP stallions who only appear as names
const JP_STUBS := {
	"Vindication": ["M", 2000, 80, "CT", 80], "Gio Ponti": ["M", 2005, 84, "CT", 30], "Ghostzapper": ["M", 2000, 88, "CT", 90],
	"Blame": ["M", 2006, 86, "TT", 90], "Pulpit": ["M", 1994, 78, "CT", 85], "Caerleon": ["M", 1980, 84, "CT", 35],
	"Medaglia d'Oro": ["M", 1999, 84, "CT", 70], "First Defence": ["M", 2004, 76, "CC", 60], "Oasis Dream": ["M", 2000, 84, "CC", 40],
	"Kingman": ["M", 2011, 90, "CT", 35], "Soldier Hollow": ["M", 2000, 80, "TT", 30], "El Prado": ["M", 1989, 76, "CT", 40],
	"Essence of Dubai": ["M", 1999, 74, "CT", 70], "Posse": ["M", 2000, 76, "CC", 85], "Toccet": ["M", 2000, 76, "CT", 80],
	"Cozzene": ["M", 1980, 82, "CT", 50], "Harlan's Holiday": ["M", 1999, 80, "CT", 85], "Oxbow": ["M", 2010, 80, "CT", 90],
	"Indian Charlie": ["M", 1995, 78, "CC", 90], "Running Stag": ["M", 1994, 76, "CT", 80], "Marju": ["M", 1988, 80, "CT", 30],
	"Rossini": ["M", 1997, 74, "CC", 35],
}

## Overseas stallions (2026 fee converted at about ¥195/£, ¥165/€, ¥150/$): [name, born, sire, fee ¥M, country, q, gene, dirt]
const OVERSEAS := [
	["Frankel", 2008, "Galileo", 68.0, "UK", 95, "CT", 30],
	["Dubawi", 2002, "Dubai Millennium", 68.0, "UK", 88, "CT", 45],
	["Sea The Stars", 2006, "Cape Cross", 50.0, "Ireland", 95, "CT", 30],
	["Lope De Vega", 2007, "Shamardal", 33.0, "Ireland", 86, "CT", 35],
	["Night Of Thunder", 2011, "Dubawi", 33.0, "Ireland", 86, "CT", 40],
	["Gun Runner", 2013, "Candy Ride", 37.5, "USA", 92, "CT", 100],
	["Into Mischief", 2005, "Harlan's Holiday", 37.5, "USA", 80, "CC", 100],
	["Not This Time", 2014, "Giant's Causeway", 37.5, "USA", 80, "CC", 95],
	["Curlin", 2004, "Smart Strike", 34.0, "USA", 92, "CT", 100],
]
const OS_STUBS := { "Shamardal": ["M", 2002, 88, "CT", 40], "Candy Ride": ["M", 1999, 86, "CT", 90], "Giant's Causeway": ["M", 1997, 88, "CT", 50], "Smart Strike": ["M", 1992, 80, "CT", 85] }

## Broodmare sires for the world's mares: [name, weight]. Mares aged 7–14 in 2027 (born 2013–2020).
const BMS := [
	["Deep Impact", 18], ["King Kamehameha", 12], ["Heart's Cry", 9], ["Symboli Kris S", 4], ["Manhattan Cafe", 4], ["Daiwa Major", 4],
	["Kurofune", 5], ["Stay Gold", 3], ["Special Week", 4], ["Fuji Kiseki", 3], ["Agnes Tachyon", 4], ["Sakura Bakushin O", 3],
	["Gold Allure", 4], ["Henny Hughes", 3], ["Storm Cat", 2], ["Unbridled's Song", 2], ["Galileo", 2], ["Danehill", 1],
	["Black Tide", 2], ["Brian's Time", 2], ["Grass Wonder", 2], ["Duramente", 2], ["Sunday Silence", 3], ["Tony Bin", 1],
]
## damsires of the second dam (the mares' maternal grandsires)
const BMS2 := [["Sunday Silence", 10], ["Northern Taste", 3], ["Tony Bin", 3], ["Brian's Time", 4], ["Storm Cat", 3], ["Sadler's Wells", 2],
	["Mr. Prospector", 2], ["Danzig", 2], ["Nureyev", 1], ["Sakura Yutaka O", 1], ["Maruzensky", 1], ["Mejiro McQueen", 2], ["Dancing Brave", 1]]

## male lines of horses whose own sire isn't in the book (JRA convention: Sunday Silence / Roberto / Mr. Prospector /
## Northern Dancer / Nasrullah ... lines)
const LINE_OF := {
	"Gio Ponti": "Northern Dancer", "Blame": "Roberto", "First Defence": "Mr. Prospector", "Kingman": "Northern Dancer",
	"Posse": "Northern Dancer", "Oxbow": "Northern Dancer", "Marju": "Northern Dancer", "French Deputy": "Northern Dancer",
	"Hennessy": "Northern Dancer", "Cape Cross": "Northern Dancer", "Shamardal": "Northern Dancer", "Candy Ride": "Mr. Prospector",
	"Giant's Causeway": "Northern Dancer", "Smart Strike": "Mr. Prospector", "Harlan's Holiday": "Northern Dancer",
	"Tony Bin": "Nasrullah", "Sakura Yutaka O": "Nasrullah", "Mejiro McQueen": "Herod", "Turn-To": "Royal Charger",
	"Native Dancer": "Native Dancer", "Nearctic": "Northern Dancer", "Vindication": "Bold Ruler", "Ghostzapper": "Northern Dancer",
	"Pulpit": "Bold Ruler", "Caerleon": "Northern Dancer", "Medaglia d'Oro": "Hail to Reason", "Oasis Dream": "Northern Dancer",
	"Soldier Hollow": "Northern Dancer", "El Prado": "Northern Dancer", "Essence of Dubai": "Mr. Prospector", "Toccet": "Hail to Reason",
	"Cozzene": "Grey Dawn", "Indian Charlie": "Bold Ruler", "Running Stag": "Bold Ruler", "Rossini": "Mr. Prospector",
}

## real coat colours of famous horses (others get a random colour from their genes)
const COAT := {
	"Gold Ship": "grey", "Mejiro McQueen": "grey", "Native Dancer": "grey", "Orfevre": "chestnut", "Duramente": "chestnut",
	"Chrysoberyl": "chestnut", "Kitasan Black": "bay", "Deep Impact": "bay", "Lord Kanaloa": "bay", "Heart's Cry": "bay",
	"King Kamehameha": "bay", "Frankel": "bay", "Galileo": "bay", "Sea The Stars": "bay", "Dubawi": "bay", "Do Deuce": "bay",
	"Epiphaneia": "bay", "Saturnalia": "bay", "Maurice": "bay", "Danehill": "bay", "Northern Dancer": "bay", "Mr. Prospector": "bay",
	"Sakura Bakushin O": "bay", "Equinox": "dark bay", "Sunday Silence": "dark bay", "Contrail": "dark bay", "Kizuna": "dark bay",
	"Stay Gold": "dark bay", "Storm Cat": "dark bay", "Black Tide": "dark bay", "Hail to Reason": "dark bay", "Halo": "dark bay",
}
const COAT_G := {
	"grey": { "E": "Ee", "A": "Aa", "G": "Gg", "dark": false }, "chestnut": { "E": "ee", "A": "Aa", "G": "gg", "dark": false },
	"bay": { "E": "Ee", "A": "Aa", "G": "gg", "dark": false }, "dark bay": { "E": "Ee", "A": "Aa", "G": "gg", "dark": true },
}

## real race records [starts, wins, G1 wins] (only where well documented)
const RECORD := {
	"Kitasan Black": [20, 12, 7], "Equinox": [10, 8, 6], "Kizuna": [14, 7, 1], "Contrail": [11, 8, 5], "Epiphaneia": [14, 6, 2],
	"Lord Kanaloa": [19, 13, 6], "Orfevre": [21, 12, 6], "Gold Ship": [28, 13, 6], "Maurice": [18, 11, 6], "Efforia": [11, 6, 3],
	"Deep Impact": [14, 12, 7], "Duramente": [9, 5, 2], "Heart's Cry": [19, 5, 2], "King Kamehameha": [8, 7, 2],
	"Sunday Silence": [14, 9, 6], "Frankel": [14, 14, 10], "Sea The Stars": [9, 8, 6],
}

# ------------------------------------------------------------------ building the stud book
static var by_name := {}

## game class from a real-world class: keeps the average stallion near the old founder level (76), so the
## racing calibration (Step 2) still holds
static func game_q(q: float) -> float:
	return 76.0 + (q - 85.5) * 0.7

static func _new(r0: SimRng, name: String, sex: String, born: int, sire: Variant, dam: Variant, q: float, gene: String, dirt: float) -> Dictionary:
	var h := Breeding.founder(r0, sex, game_q(q))
	Breeding.names.erase(h.name)
	h.name = name
	Breeding.names[name] = true
	h.mstn = gene; h.gene = gene
	# shift the performance stats so the horse's rating matches its class
	var delta := game_q(q) - Career.rating(h)
	for k in Breeding.PERF:
		var p := clampf(roundf(float(h.stats[k]) + delta), 1.0, 100.0)
		h.gv[k] = float(h.gv[k]) + Breeding.H2[k] * (p - float(h.stats[k]))
		h.stats[k] = int(p)
	h.dirt = int(dirt); h.gv["dirt"] = Breeding.mu("dirt") + Breeding.H2.dirt * (dirt - Breeding.mu("dirt"))
	h.sire = sire; h.dam = dam
	h.born = born
	h["age"] = 2027 - born
	h["real"] = true
	h["c"] = { "status": "retired", "starts": 12, "wins": 4, "cm": 0.0, "g1": 0, "graded": 0, "earn": 0.0, "history": [], "bigWins": [] }
	if q >= 82.0: h.c.g1 = 1 + int((q - 82.0) / 3.0); h.c.graded = h.c.g1 + 1
	elif q >= 76.0: h.c.graded = 1
	by_name[name] = h
	return h

static func id_of(name: Variant) -> Variant:
	if name == null: return null
	return int(by_name[name].id) if by_name.has(name) else null

static func _stub(r0: SimRng, name: String, d: Array) -> void:
	if by_name.has(name): return
	_new(r0, name, d[0], d[1], null, null, d[2], d[3], d[4])

## an unnamed dam: "(mare by X)"
static func _anon_dam(r0: SimRng, damsire: Variant, born: int) -> Variant:
	var nm := "(mare by %s)" % damsire if damsire != null else "(unnamed mare)"
	var m := _new(r0, nm, "F", born, id_of(damsire), null, 64, "CT", 50)
	m["anon"] = true
	by_name.erase(nm)                 # several horses can share this label; only real names are looked up
	return int(m.id)

## creates all real horses; returns { jp: [...stallions], dead: [...], overseas: [...] }
static func build(r0: SimRng) -> Dictionary:
	by_name = {}
	for n in STUBS: _stub(r0, n, STUBS[n])
	for n in JP_STUBS: _stub(r0, n, JP_STUBS[n])
	for n in OS_STUBS: _stub(r0, n, OS_STUBS[n])
	for e in HIST:
		var h := _new(r0, e[0], e[1], e[2], id_of(e[3]), id_of(e[4]), e[5], e[6], e[7])
		if e[8]: h["lineRoot"] = true
	var out := { "jp": [], "dead": [], "overseas": [] }
	for e in JP:
		var dam = id_of(e[3]) if e[3] != null else _anon_dam(r0, e[4], int(e[1]) - 7)
		if e[3] != null and e[4] != null and by_name.has(e[3]) and by_name[e[3]].sire == null: by_name[e[3]].sire = id_of(e[4])
		var s := _new(r0, e[0], "M", e[1], id_of(e[2]), dam, e[6], e[7], e[8])
		s["retired"] = true
		s.c.status = "stud"
		var sd := Stud.stud(s)
		sd.since = int(e[9]); sd.fee = absf(e[5]); sd["realFee"] = absf(e[5]); sd["feeEst"] = e[5] < 0.0
		out.jp.append(s)
	for n in DEAD_SIRES:
		var h: Dictionary = by_name[n]
		h["coverWin"] = DEAD_SIRES[n]
		out.dead.append(h)
	for e in OVERSEAS:
		var s: Dictionary
		if by_name.has(e[0]): s = by_name[e[0]]
		else: s = _new(r0, e[0], "M", e[1], id_of(e[2]), null, e[5], e[6], e[7])
		s.c.status = "abroad"
		var sd := Stud.stud(s)
		sd.fee = e[3]; sd["realFee"] = e[3]; sd["country"] = e[4]; sd.since = 2000; sd.cap = 999
		s["abroad"] = e[4]
		out.overseas.append(s)
	for n in LINE_OF:
		if by_name.has(n): by_name[n]["line"] = LINE_OF[n]
	for n in RECORD:
		if by_name.has(n):
			var h: Dictionary = by_name[n]
			h["rec"] = RECORD[n]; h.c.starts = RECORD[n][0]; h.c.wins = RECORD[n][1]; h.c.g1 = RECORD[n][2]; h.c.graded = maxi(int(h.c.graded), RECORD[n][2])
	for n in COAT:
		if by_name.has(n):
			var h: Dictionary = by_name[n]
			h.coatG = COAT_G[COAT[n]].duplicate(); h.coat = COAT[n]; h.coatColor = Breeding.COAT_RGB[COAT[n]]
	Breeding.clear_memo()
	return out

static func weighted(r0: SimRng, table: Array) -> String:
	var tot := 0.0
	for e in table: tot += float(e[1])
	var u := r0.next() * tot
	for e in table:
		u -= float(e[1])
		if u <= 0.0: return e[0]
	return table[0][0]

## shipping, boarding and vet costs for covering abroad (¥M)
const ABROAD_COST := 4.0

# ------------------------------------------------------------------ progeny calibration
## What each stallion's foals actually do. [turf share of wins, avg winning distance turf, dirt, growth (2yo winner-rate based,
## 50 = normal), temperament tendency (foal mean, 60 = normal), going (50 = neutral, higher = better on soft), real data?]
## Real data (JRA, netkeiba sire pages, cumulative to Nov 2026): turf share = turf wins / all wins, average winning distances.
## Growth: 2025 2-year-old winner rate (Maurice 36.1%, Epiphaneia 35.6%, Kizuna 30.7%, Lord Kanaloa 26.2%, Kitasan Black 20.8%).
## Temperament and going: reputation-based game estimates.
const PROGENY := {
	"Kizuna": [0.649, 1822, 1708, 62, 62, 50, true], "Kitasan Black": [0.759, 1823, 1698, 37, 68, 55, true],
	"Lord Kanaloa": [0.668, 1533, 1444, 50, 64, 42, true], "Epiphaneia": [0.861, 1817, 1684, 74, 50, 55, true],
	"Drefong": [0.193, 1590, 1553, 62, 58, 50, true], "Maurice": [0.748, 1652, 1505, 75, 56, 55, true],
	"Gold Ship": [0.870, 2040, 1791, 35, 42, 68, true], "Rulership": [0.655, 1872, 1678, 40, 55, 55, true],
	# game estimates from the stallion's own career and reputation
	"Equinox": [0.85, 1900, 1750, 52, 64, 42, false], "Contrail": [0.80, 1800, 1700, 55, 62, 45, false],
	"Swarve Richard": [0.82, 1850, 1700, 42, 60, 50, false], "Saturnalia": [0.80, 1750, 1650, 55, 60, 48, false],
	"Do Deuce": [0.85, 1900, 1750, 50, 60, 45, false], "Real Steel": [0.55, 1700, 1650, 55, 62, 50, false],
	"Nadal": [0.15, 1600, 1600, 58, 60, 50, false], "Admire Mars": [0.62, 1500, 1450, 65, 60, 48, false],
	"Efforia": [0.85, 1900, 1750, 60, 60, 52, false], "Siskin": [0.62, 1450, 1400, 65, 60, 48, false],
	"Orfevre": [0.70, 2000, 1800, 40, 42, 68, false], "Schnell Meister": [0.80, 1650, 1600, 55, 60, 50, false],
	"Chrysoberyl": [0.10, 1700, 1700, 48, 60, 50, false], "Rey de Oro": [0.72, 1900, 1750, 45, 60, 52, false],
	"Shahryar": [0.85, 2000, 1800, 50, 62, 45, false], "Mind Your Biscuits": [0.10, 1350, 1350, 62, 60, 50, false],
	"Isla Bonita": [0.60, 1600, 1500, 58, 62, 50, false], "Grenadier Guards": [0.60, 1400, 1350, 62, 60, 48, false],
	"Hot Rod Charlie": [0.15, 1700, 1700, 52, 60, 50, false], "Asia Express": [0.08, 1400, 1400, 58, 60, 50, false],
	"Indy Champ": [0.75, 1600, 1500, 55, 60, 52, false],
	# overseas stallions — their runners in JRA (netkeiba, cumulative to Nov 2026): turf share of wins, average winning
	# distances. Frankel 96 wins, Into Mischief 86, Curlin 40, Dubawi 31, Gun Runner 28, Sea The Stars 16. Lope De Vega,
	# Night Of Thunder and Not This Time have too few runners in Japan: game estimates from their European/US records.
	"Frankel": [0.865, 1624, 1623, 56, 52, 60, true], "Dubawi": [0.677, 1438, 1310, 56, 58, 58, true],
	"Sea The Stars": [0.875, 1886, 1650, 40, 60, 62, true], "Gun Runner": [0.071, 1500, 1623, 52, 62, 50, true],
	"Into Mischief": [0.14, 1500, 1411, 62, 60, 50, true], "Curlin": [0.175, 1886, 1662, 45, 60, 50, true],
	"Lope De Vega": [0.90, 1700, 1500, 55, 58, 62, false], "Night Of Thunder": [0.88, 1500, 1400, 60, 56, 58, false],
	"Not This Time": [0.10, 1300, 1350, 62, 60, 50, false], "Danon Kingly": [0.75, 1700, 1600, 55, 62, 48, false],
	"Satono Crown": [0.80, 2000, 1800, 45, 60, 62, false], "Fast Force": [0.60, 1250, 1200, 60, 60, 48, false],
	"Rion Diez": [0.55, 1650, 1550, 55, 52, 52, false], "Mozu Ascot": [0.35, 1500, 1450, 55, 60, 50, false],
}
const ENTRY_SD := 12.0     # spread of foals' dirt aptitude around their family mean (approx.)

## sets each real stallion's breeding values so foals out of an average mare match the targets above
static func calibrate(mares: Array) -> void:
	if mares.is_empty(): return
	var n := float(mares.size())
	var pc := 0.0
	var sb := 0.0
	var mm := {}
	for m in mares:
		pc += (2.0 if m.mstn == "CC" else (1.0 if m.mstn == "CT" else 0.0)) / 2.0
		sb += float(m.gv.stamina) - float(m.gv.burst)
		for k in ["dirt", "grow", "going", "temper"]: mm[k] = float(mm.get(k, 0.0)) + float(m.gv.get(k, Breeding.mu(k)))
	pc /= n; sb /= n
	for k in mm: mm[k] /= n
	# merit: the average stallion standing in Japan sets the scale; stallions with real progeny records are moved to it
	var ref := 0.0
	var nref := 0
	for e in JP:
		if by_name.has(e[0]): ref += perf_mean(by_name[e[0]]); nref += 1
	ref /= maxf(1.0, float(nref))
	for name in SIRE_EI:
		if not by_name.has(name): continue
		var s: Dictionary = by_name[name]
		var e: Array = SIRE_EI[name]
		var lei := log(float(e[0])) * float(e[1]) / (float(e[1]) + 30.0)
		var shift := ref + 2.0 * EI_K * lei - perf_mean(s)
		for k in Breeding.PERF: s.gv[k] = float(s.gv[k]) + shift
	for name in PROGENY:
		if not by_name.has(name): continue
		var s: Dictionary = by_name[name]
		var t: Array = PROGENY[name]
		# surface: P(foal dirt aptitude < 50) = turf share
		var foal_dirt := 50.0 - ENTRY_SD * _probit(clampf(float(t[0]), 0.03, 0.97))
		s.gv.dirt = clampf(2.0 * foal_dirt - float(mm.dirt), -20.0, 120.0)
		# distance: MSTN genotype + stamina–burst balance so the foals' mean best distance is the real winning distance
		var target := float(t[0]) * float(t[1]) + (1.0 - float(t[0])) * float(t[2])
		# in the game world a horse's wins spread around its best trip (fields, race programme), so the foals' mean
		# winning distance moves only ~0.6 m per metre of best distance (progeny test) — stretch the target to match
		target = 1700.0 + (target - 1700.0) * DIST_SPREAD
		var best_g := "CT"
		var best_sb := 1e9
		for g in ["CC", "CT", "TT"]:
			var sc := 1.0 if g == "CC" else (0.5 if g == "CT" else 0.0)
			var cc := sc * pc
			var tt := (1.0 - sc) * (1.0 - pc)
			var base := 1350.0 * cc + 1850.0 * (1.0 - cc - tt) + 2400.0 * tt
			var need := 2.0 * (target - base) / 12.0 - sb
			if absf(need) < absf(best_sb): best_sb = need; best_g = g
		s.mstn = best_g; s.gene = best_g
		var avg := (float(s.gv.stamina) + float(s.gv.burst)) / 2.0
		s.gv.stamina = avg + best_sb / 2.0
		s.gv.burst = avg - best_sb / 2.0
		s.gv.grow = clampf(2.0 * float(t[3]) - float(mm.grow), -20.0, 120.0)
		s.gv.temper = clampf(2.0 * float(t[4]) - float(mm.temper), 0.0, 110.0)
		s.gv.going = clampf(2.0 * float(t[5]) - float(mm.going), -20.0, 120.0)
		s["progenyData"] = "real" if t[6] else "estimate"
		# the stallion's own displayed preferences follow his breeding values
		s.grow = int(clampf(Breeding.mu("grow") + (float(s.gv.grow) - Breeding.mu("grow")) / Breeding.H2.grow * 0.6, 0.0, 100.0))
		s.going = int(clampf(Breeding.mu("going") + (float(s.gv.going) - Breeding.mu("going")) / Breeding.H2.going * 0.6, 0.0, 100.0))

## Earnings index of the stallion's runners, JRA leading sire table 2023 (E·I; 1.00 = average earnings per runner) and the
## share of runners that won that year (勝馬率): Kitasan Black 2.90 / 41.7%, Kizuna 1.59 / 35.3%, Lord Kanaloa 1.43 / 28.0%,
## Maurice 1.41 / 29.5%, Drefong 1.12 / 34.2%, Gold Ship 1.05 / 24.4%, Rulership 1.01 / 25.1%, Epiphaneia 0.89 / 25.3%.
## Used for the stallion's overall genetic merit (racing class passed on), relative to the average stallion in Japan.
const SIRE_EI := {   # [E·I, runners in the sample]
	"Kitasan Black": [2.90, 144], "Kizuna": [1.59, 303], "Lord Kanaloa": [1.43, 411], "Maurice": [1.41, 271], "Drefong": [1.12, 234],
	"Gold Ship": [1.05, 180], "Rulership": [1.01, 287], "Epiphaneia": [0.89, 328],
	# overseas stallions: their imported runners in JRA, cumulative to Nov 2026 (netkeiba). Small, hand-picked samples
	# (expensive imports), so the E·I is shrunk towards 1.00 by runners / (runners + 30).
	"Frankel": [2.29, 83], "Into Mischief": [2.26, 43], "Dubawi": [1.55, 27], "Curlin": [1.49, 29], "Gun Runner": [1.34, 24],
	"Night Of Thunder": [1.79, 8], "Lope De Vega": [1.05, 8], "Not This Time": [1.01, 3], "Sea The Stars": [0.95, 24] }
## foal rating points per unit of ln(E·I); real E·I also carries mare quality, so only part of it is the sire's
const EI_K := 5.0
## see calibrate(): best-distance targets are stretched around 1,700 m so the foals' winning distances match the real ones
const DIST_SPREAD := 1.6

## mean genetic value over the performance stats
static func perf_mean(h: Dictionary) -> float:
	var t := 0.0
	for k in Breeding.PERF: t += float(h.gv[k])
	return t / float(Breeding.PERF.size())

## inverse of the standard normal CDF (Acklam's approximation)
static func _probit(p: float) -> float:
	var a := [-39.69683028665376, 220.9460984245205, -275.9285104469687, 138.3577518672690, -30.66479806614716, 2.506628277459239]
	var b := [-54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155211139]
	var c := [-0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783]
	var d := [0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416]
	var q: float
	if p < 0.02425:
		q = sqrt(-2.0 * log(p))
		return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
	if p > 1.0 - 0.02425:
		q = sqrt(-2.0 * log(1.0 - p))
		return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
	q = p - 0.5
	var r := q * q
	return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0)

class_name Weather
## Race-day weather (天候) and the time of the race, for the 3D race and the race card.
##
## JRA reports the weather as 晴 fine, 曇 cloudy, 小雨 light rain, 雨 rain, 小雪 light snow, 雪 snow. The weather is
## picked to agree with the going (a firm track is rarely run in rain; heavy going nearly always is) and with the
## season (snow only in winter weeks). It is a hash of the race, so it never touches the career's random numbers.
##
## Race times: the main race (G1/G2/G3) goes off at about 15:40 (15:25 in mid-winter); lesser races through the day.
## Sun position: Japan, latitude 35° N, longitude 136° E (JST is 135° E), with the equation of time.

const CONDS := ["fine", "cloudy", "light_rain", "rain", "light_snow", "snow"]
const LABEL := { "fine": "Fine 晴", "cloudy": "Cloudy 曇", "light_rain": "Light rain 小雨", "rain": "Rain 雨", "light_snow": "Light snow 小雪", "snow": "Snow 雪" }
const SHORT := { "fine": "Fine", "cloudy": "Cloudy", "light_rain": "Light rain", "rain": "Rain", "light_snow": "Light snow", "snow": "Snow" }
const ICON := { "fine": "☀", "cloudy": "☁", "light_rain": "🌦", "rain": "🌧", "light_snow": "🌨", "snow": "❄" }

## [cond, weight] per going (JRA-like frequencies: most races are fine; rain mostly on soft/heavy days)
const BY_GOING := {
	"firm": [["fine", 70], ["cloudy", 27], ["light_rain", 3]],                        # 良
	"yielding": [["fine", 14], ["cloudy", 44], ["light_rain", 28], ["rain", 14]],     # 稍重
	"soft": [["cloudy", 22], ["light_rain", 33], ["rain", 45]],                        # 重
	"heavy": [["cloudy", 6], ["light_rain", 24], ["rain", 70]],                        # 不良
}

static func _h(x: int) -> float:
	var v := x * 2654435761 % 4294967296
	v = (v ^ (v >> 13)) * 1274126177 % 4294967296
	return float(v % 100000) / 100000.0

static func winter(week: int) -> bool:
	return week <= 9 or week >= 50

static func pick(going: String, week: int, seed: int) -> String:
	var tab: Array = BY_GOING.get(going, BY_GOING.firm)
	var tot := 0.0
	for e in tab: tot += float(e[1])
	var x := _h(seed * 31 + week) * tot
	var c := "fine"
	for e in tab:
		x -= float(e[1])
		if x <= 0.0: c = e[0]; break
	if winter(week) and (c == "light_rain" or c == "rain") and _h(seed * 7 + 3) < 0.22:
		c = "light_snow" if c == "light_rain" else "snow"
	return c

## post time in hours (local)
static func post_time(cls: String, week: int, seed: int) -> float:
	var t := 15.67
	match cls:
		"G1", "G2", "G3": t = 15.42 if winter(week) else 15.67
		"L", "OP", "3W": t = 14.6
		"2W": t = 13.7
		"1W": t = 12.8
		"MDN": t = 10.9
		"NEW": t = 12.3
		_: t = 14.0
	return t + (_h(seed * 13) - 0.5) * 0.5

static func time_text(t: float) -> String:
	var h := int(t); var m := int(round((t - h) * 60.0 / 5.0)) * 5
	if m >= 60: h += 1; m -= 60
	return "%d:%02d" % [h, m]

## sun elevation and azimuth (degrees; azimuth from north, clockwise) at latitude 35 N, local time t, week of year
static func sun(week: int, t: float) -> Vector2:
	var doy := clampf(week * 7.0 - 3.0, 1.0, 365.0)
	var g := TAU / 365.0 * (doy - 1.0 + (t - 12.0) / 24.0)
	var decl := 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
	var eot := 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))   # minutes
	var solar := t * 60.0 + eot + 4.0 * (136.0 - 135.0)      # true solar time, minutes
	var ha := deg_to_rad(solar / 4.0 - 180.0)
	var lat := deg_to_rad(35.0)
	var cz := sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(ha)
	var el := asin(clampf(cz, -1.0, 1.0))
	var az := atan2(sin(ha), cos(ha) * sin(lat) - tan(decl) * cos(lat)) + PI
	return Vector2(rad_to_deg(el), fposmod(rad_to_deg(az), 360.0))

static func season(week: int) -> String:
	if week <= 9 or week >= 49: return "winter"
	if week <= 22: return "spring"
	if week <= 37: return "summer"
	return "autumn"

## fill weather, post time and week into race options that lack them (quick races, old replays)
static func complete(opts: Dictionary) -> Dictionary:
	var o := opts.duplicate()
	var sd := int(o.get("seed", 1))
	if not o.has("week"): o["week"] = 1 + int(_h(sd * 5 + 1) * 52.0)
	if not o.has("weather"): o["weather"] = pick(String(o.get("going", "firm")), int(o.week), sd)
	if not o.has("hour"): o["hour"] = post_time(String(o.get("cls", "G1")), int(o.week), sd)
	return o

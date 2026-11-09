class_name SimUtil
extends RefCounted
## Small helpers that keep GDScript results identical to the JavaScript version.

## JavaScript Math.round (halves round up, also for negatives).
static func js_round(x: float) -> float:
	return floorf(x + 0.5)

## Stable sort (like JavaScript Array.sort). cmp(a, b) returns < 0 if a goes first, > 0 if b goes first, 0 to keep order.
static func stable_sort(arr: Array, cmp: Callable) -> Array:
	var n := arr.size()
	if n < 2: return arr.duplicate()
	var a := arr.duplicate()
	var b := arr.duplicate()
	var width := 1
	while width < n:
		var i := 0
		while i < n:
			var mid := mini(i + width, n)
			var hi := mini(i + 2 * width, n)
			var l := i
			var r := mid
			var k := i
			while l < mid and r < hi:
				if float(cmp.call(a[l], a[r])) <= 0.0:
					b[k] = a[l]; l += 1
				else:
					b[k] = a[r]; r += 1
				k += 1
			while l < mid:
				b[k] = a[l]; l += 1; k += 1
			while r < hi:
				b[k] = a[r]; r += 1; k += 1
			i += 2 * width
		var tmp := a
		a = b
		b = tmp
		width *= 2
	return a

## Turn whole-number floats back into ints after JSON parsing (JSON has no int type).
static func json_ints(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15: return int(f)
		return f
	if v is Array:
		var out := []
		for x in v: out.append(json_ints(x))
		return out
	if v is Dictionary:
		var d := {}
		for k in v: d[k] = json_ints(v[k])
		return d
	return v

## Dictionary with numeric string keys ("12") -> int keys, order kept.
static func int_keys(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d: o[int(k) if (k is String and k.is_valid_int()) else k] = d[k]
	return o

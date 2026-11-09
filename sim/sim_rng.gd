class_name SimRng
extends RefCounted
## Deterministic RNG: mulberry32, bit-identical to the JavaScript version (same seed -> same sequence).

const M32 := 0xFFFFFFFF
var state: int = 0

func _init(seed_value: int = 1) -> void:
	state = seed_value & M32

static func imul(x: int, y: int) -> int:
	# low 32 bits of x*y for 32-bit unsigned inputs, without 64-bit overflow
	x &= M32
	y &= M32
	var xl := x & 0xFFFF
	var xh := x >> 16
	return (xl * y + (((xh * y) & 0xFFFF) << 16)) & M32

func next() -> float:
	state = (state + 0x6D2B79F5) & M32
	var a := state
	var t := imul(a ^ (a >> 15), 1 | a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & M32) ^ t
	return float((t ^ (t >> 14)) & M32) / 4294967296.0

## Standard normal (Box-Muller), same call order as the JS gauss()
func gauss() -> float:
	var u := 0.0
	while u == 0.0:
		u = next()
	var v := next()
	return sqrt(-2.0 * log(u)) * cos(2.0 * PI * v)

class_name Saves
## Step 4A — save slots. Each save is a .sav file (Career.save_data) with a small .json beside it
## (name, role, date, money) so the Load screen can list saves without opening them.
##   user://saves/slot_1 … slot_10   manual saves
##   user://saves/auto_1 … auto_3    autosaves (auto_1 is the newest), written every week
##   user://career.sav               the single save from before Step 4 (still loads)
## Step 6D — safe saves: a save is written to a temporary file, checked, and only then put in place; the previous
## version of each save is kept as <name>.bak and loaded instead if the save turns out damaged. Saves carry the
## game's save version: older saves are brought up to date (migrate), saves from a newer game are refused.

const DIR := "user://saves/"
const SLOTS := 10
const AUTOS := 3
const OLD := "user://career.sav"
const VERSION := 3          # 3: Step 5 world (rivals, race plans, caution) · 2: Step 4 · 1: before Step 4
static var last_note := ""  # what the last load had to do (backup used, save updated, refused) — shown by the UI

static func _ensure() -> void:
	if not DirAccess.dir_exists_absolute(DIR): DirAccess.make_dir_recursive_absolute(DIR)

static func meta() -> Dictionary:
	var W := Career.W
	var p: Dictionary = W.get("player", {})
	return {
		"v": VERSION, "stable": String(W.get("stable_name", "")), "name": String(p.get("name", "")),
		"role": String(p.get("role", "owner")), "job": String(p.get("job", "")), "year": int(W.year), "week": int(W.week),
		"money": float(W.get("money", 0.0)), "saved": int(Time.get_unix_time_from_system()), "label": String(W.get("saveLabel", "")),
	}

static func write(base: String) -> Error:
	_ensure()
	Career.W["v"] = VERSION
	var data := Career.save_data()
	# 1. write beside the old save, 2. read it back and check it, 3. keep the old save as .bak, 4. move into place
	var tmp := base + ".sav.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_buffer(data)
	f.close()
	var back := FileAccess.get_file_as_bytes(tmp)
	if back.size() != data.size() or back != data:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	var old_sha := String(read_meta(base).get("sha", ""))
	if FileAccess.file_exists(base + ".sav"):
		if FileAccess.file_exists(base + ".bak"): DirAccess.remove_absolute(base + ".bak")
		DirAccess.rename_absolute(base + ".sav", base + ".bak")
	var err := DirAccess.rename_absolute(tmp, base + ".sav")
	if err != OK: return err
	var md := meta()
	md["sha"] = sha(data)                 # fingerprint: a save changed on disk afterwards is recognised as damaged
	md["bakSha"] = old_sha
	var m := FileAccess.open(base + ".json", FileAccess.WRITE)
	if m != null:
		m.store_string(JSON.stringify(md))
		m.close()
	return OK

static func save_slot(i: int, label := "") -> Error:
	if label != "": Career.W["saveLabel"] = label
	Career.W["slot"] = i
	return write(DIR + "slot_%d" % i)

## rotate auto_3 ← auto_2 ← auto_1 ← now
static func autosave() -> Error:
	_ensure()
	var d := DirAccess.open(DIR)
	for i in range(AUTOS, 1, -1):
		for ext in [".sav", ".json"]:
			var src := "auto_%d%s" % [i - 1, ext]
			var dst := "auto_%d%s" % [i, ext]
			if d.file_exists(src):
				if d.file_exists(dst): d.remove(dst)
				d.rename(src, dst)
	return write(DIR + "auto_1")

## quick save: back into the slot this career was last saved to (or the first free slot)
static func quick_save() -> Error:
	var i := int(Career.W.get("slot", 0))
	if i <= 0: i = first_free()
	return save_slot(i)

static func first_free() -> int:
	for i in range(1, SLOTS + 1):
		if not FileAccess.file_exists(DIR + "slot_%d.sav" % i): return i
	return SLOTS

static func read_meta(base: String) -> Dictionary:
	if not FileAccess.file_exists(base + ".json"): return {}
	var o = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	return o if o is Dictionary else {}

## every save on disk, newest first: [{ path, kind, slot, meta }]
static func list() -> Array:
	var out: Array = []
	for i in range(1, SLOTS + 1):
		var b := DIR + "slot_%d" % i
		if FileAccess.file_exists(b + ".sav"): out.append({ "path": b + ".sav", "kind": "slot", "slot": i, "meta": read_meta(b) })
	for i in range(1, AUTOS + 1):
		var b := DIR + "auto_%d" % i
		if FileAccess.file_exists(b + ".sav"): out.append({ "path": b + ".sav", "kind": "auto", "slot": i, "meta": read_meta(b) })
	if FileAccess.file_exists(OLD): out.append({ "path": OLD, "kind": "old", "slot": 0, "meta": {} })
	out.sort_custom(func(a, b): return int(a.meta.get("saved", 0)) > int(b.meta.get("saved", 0)))
	return out

static func any() -> bool: return not list().is_empty()

static func sha(data: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(data)
	return hc.finish().hex_encode()

## a save's contents if it can be read and is a game save; null if damaged (want = its recorded fingerprint, if any)
static func _decode(path: String, want := "") -> Variant:
	if not FileAccess.file_exists(path): return null
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < 8: return null
	if want != "" and sha(data) != want: return null
	var n := data.decode_u32(0)
	if n <= 0 or n > 2_000_000_000: return null
	var raw := data.slice(4).decompress(n, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != n: return null
	var o = bytes_to_var(raw)
	if not (o is Dictionary) or not o.has("W") or not o.has("book") or not (o.W is Dictionary): return null
	return data

static func load_path(path: String) -> bool:
	last_note = ""
	var md := read_meta(path.get_basename())
	var data = _decode(path, String(md.get("sha", "")))
	var bak := path.get_basename() + ".bak"
	if data == null and path.ends_with(".sav"):
		data = _decode(bak, String(md.get("bakSha", "")))
		if data != null: last_note = "This save was damaged — the previous version (backup) was loaded instead."
	if data == null:
		last_note = "This save could not be read (the file is damaged) and has no usable backup."
		return false
	# a save from a newer version of the game: don't load it into an older game
	var peek = bytes_to_var((data as PackedByteArray).slice(4).decompress((data as PackedByteArray).decode_u32(0), FileAccess.COMPRESSION_ZSTD))
	if int(peek.W.get("v", 0)) > VERSION:
		last_note = "This save was made by a newer version of the game (save version %d; this game reads up to %d)." % [int(peek.W.get("v", 0)), VERSION]
		return false
	Career.load_data(data)
	var was := int(Career.W.get("v", 1))
	migrate()
	if was < VERSION and last_note == "": last_note = "Your save was updated to the current game version."
	return true

static func delete(path: String) -> void:
	var base := path.get_basename()
	for ext in [".sav", ".json", ".bak"]:
		if FileAccess.file_exists(base + ext): DirAccess.remove_absolute(base + ext)

## saves from before Step 4: an owner-breeder with the old stable, Normal money
static func migrate() -> void:
	var W := Career.W
	if not W.has("player"):
		var keep_ledger: Array = W.get("ledger", [])
		var stable: Array = W.stable.duplicate()
		Profile.create({ "role": "owner", "diff": "normal", "name": String(W.get("stable_name", "Owner")) })
		W.stable = stable
		W.player.farm = true
		W.player.farmValue = 80.0
		for e in keep_ledger:
			if not e.has("cat"): e["cat"] = "other"
		W.ledger.append_array(keep_ledger)
		Career.log_msg("Your save was updated for Step 4: you are an owner-breeder with a farm and ¥300M to start.", null)
	if not W.has("jockeys"):          # saves from before Step 4B: real jockeys and trainers join the world
		People.build(int(W.year))
	if not W.has("owners"):           # saves from before Step 4 owners: CPU owners take over the other horses
		Owners.build()
	if int(W.get("v", 1)) < 3:        # saves from before Step 5: the rest of Japan's open horses join the world
		if not W.has("rivalCrops"):
			Career._pick_cache = {}
			for age in range(1, 7): Rivals.make_crop(int(W.year) - age, age, Career.R)
			Career._pick_cache = null
	W["v"] = VERSION

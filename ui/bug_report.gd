class_name BugReport
## Step 6F — one click puts everything needed to look into a problem in a single zip:
## the Godot logs (latest + a few older), the settings, the current career (saved fresh, when one is open),
## the newest autosave, and a short system report (game/save version, Godot, OS, graphics card, screen).
## The zip goes to user://bug_reports/ and the folder is opened, ready to send to Claude or ChatGPT.

const DIR := "user://bug_reports/"
const MAX_LOGS := 4

static func make(note := "") -> String:
	if not DirAccess.dir_exists_absolute(DIR): DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := DIR + "report_%s.zip" % stamp
	var z := ZIPPacker.new()
	if z.open(path) != OK: return ""
	_add_text(z, "system.txt", _system(note))
	# logs: the newest few
	var logs := _files("user://logs", ".log")
	logs.sort_custom(func(a, b): return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b))
	for f in logs.slice(0, MAX_LOGS): _add_file(z, "logs/" + f.get_file(), f)
	if FileAccess.file_exists(Settings.PATH): _add_file(z, "settings.cfg", Settings.PATH)
	# the career as it is now (when one is open), and the newest autosave
	if not Career.W.is_empty() and Game.mode == "career":
		_add_bytes(z, "saves/current.sav", Career.save_data())
	if FileAccess.file_exists(Saves.DIR + "auto_1.sav"): _add_file(z, "saves/auto_1.sav", Saves.DIR + "auto_1.sav")
	z.close()
	return path

static func _system(note: String) -> String:
	var W := Career.W
	var lines := PackedStringArray([
		"Horse Racing Simulation — bug report",
		"Made: %s" % Time.get_datetime_string_from_system(),
		"Note: %s" % (note if note != "" else "-"),
		"",
		"Godot: %s" % Engine.get_version_info().string,
		"OS: %s %s" % [OS.get_name(), OS.get_version()],
		"CPU: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()],
		"Graphics: %s · %s · driver %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()],
		"Screen: %s · window %s" % [str(DisplayServer.screen_get_size()), str(DisplayServer.window_get_size())],
		"",
		"Save version: %d" % Saves.VERSION,
		"Mode: %s" % Game.mode,
	])
	if not W.is_empty():
		lines.append("Career: %s · %s · %s" % [String(W.get("stable_name", "")), Profile.role() if W.has("player") else "-", Game.now_text()])
		lines.append("World: %d horses in the stud book, %d racing, crop %d" % [Breeding.book.size(), Career.active().size(), int(W.get("crop", 0))])
	lines.append("")
	lines.append("Settings: %s" % JSON.stringify(Settings.S))
	return "\n".join(lines)

static func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null: return out
	for f in d.get_files():
		if f.ends_with(ext): out.append(dir.path_join(f))
	return out

static func _add_text(z: ZIPPacker, name: String, text: String) -> void:
	_add_bytes(z, name, text.to_utf8_buffer())

static func _add_file(z: ZIPPacker, name: String, path: String) -> void:
	_add_bytes(z, name, FileAccess.get_file_as_bytes(path))

static func _add_bytes(z: ZIPPacker, name: String, b: PackedByteArray) -> void:
	z.start_file(name)
	z.write_file(b)
	z.close_file()

## the dialog: an optional note, then the zip; its folder opens so it can be sent straight away
static func open_dialog(parent: Node) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Create a bug report"
	dlg.ok_button_text = "Create report"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UiTheme.label("What went wrong? (optional)", 13))
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(460, 110)
	te.placeholder_text = "e.g. the race froze after the 3rd corner in the Japan Cup replay"
	v.add_child(te)
	v.add_child(UiTheme.dim_label("The report holds the game logs, your settings, the current career and the newest autosave.", 11))
	dlg.add_child(v)
	parent.add_child(dlg)
	dlg.confirmed.connect(func():
		var p := make(te.text.strip_edges())
		var done := AcceptDialog.new()
		done.title = "Bug report"
		if p == "":
			done.dialog_text = "The report could not be written."
		else:
			var full := ProjectSettings.globalize_path(p)
			done.dialog_text = "Saved:\n%s\n\nThe folder opens now — send this zip to Claude or ChatGPT." % full
			OS.shell_open(ProjectSettings.globalize_path(DIR))
		parent.add_child(done)
		done.popup_centered(Vector2i(560, 0)))
	dlg.popup_centered(Vector2i(500, 0))

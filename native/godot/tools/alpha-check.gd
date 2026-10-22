extends SceneTree
## The alpha's infrastructure (native/ALPHA-1.0-REPORT.md): the version and its label, the About screen and the problem
## report, the testing tools left on offer, and saves that are checked before they are loaded: damaged, foreign and cut-short files
## are refused with a message and kept, and real saves from earlier versions still load.
var errors: Array[String] = []
var passed := 0
var w: Node
const BuildInfo := preload("res://scripts/build_info.gd")
const Diagnostics := preload("res://scripts/diagnostics.gd")
const Cheats := preload("res://scripts/cheats.gd")
const SaveScript := preload("res://scripts/save.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func texts(node: Node, out := []) -> Array:
	for c in node.get_children():
		if c is Label or c is Button: out.append(c.text)
		texts(c, out)
	return out

func run() -> void:
	seed(61)
	# The newest campaign save on this machine decides the setup, so that it can be loaded whole below.
	var config := {"map": "island", "players": 3, "nation": 0}
	var slot := ""
	var newest := 0
	var dir := DirAccess.open("user://saves")
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".json") and file.begins_with("Campaign") and FileAccess.get_modified_time("user://saves/" + file) > newest:
				var data = JSON.parse_string(FileAccess.get_file_as_string("user://saves/" + file))
				if data is Dictionary and data.get("match_config") is Dictionary and str(data.get("map", "")).ends_with("map-seed1.json"):
					newest = FileAccess.get_modified_time("user://saves/" + file)
					slot = file.get_basename()
					config = data.match_config
	set_meta("match_config", config)
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w.menu._root == null: w.menu.setup(w)
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)

	# ---- version
	check(BuildInfo.version() == "1.0.3" and BuildInfo.label() == "ALPHA", "the build is 1.0.3 with the label ALPHA (%s)" % BuildInfo.full())
	check(BuildInfo.title() == "DOMINION  1.0.3 ALPHA", "the window title says so (%s)" % BuildInfo.title())
	check(BuildInfo.older("0.9.101", "1.0.0") and BuildInfo.older("1.0.0", "1.0.1") and not BuildInfo.older("1.0.0", "1.0.0") and not BuildInfo.older("1.2.0", "1.0.9"), "versions compare by number, not text")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(preset.contains('file_version="1.0.3.0"') and preset.contains('product_version="1.0.3.0"'), "the export preset carries 1.0.3.0")
	check(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false) == true, "the engine's log is written to a file for testers")

	# ---- the opening screen and About
	w.menu.open_main()
	await process_frame
	var main_text := texts(w.menu._root)
	check(main_text.any(func(t): return str(t).contains("1.0.3 ALPHA")), "the opening screen shows the version and the label")
	check(main_text.any(func(t): return str(t).contains("About / report a problem")), "and a link to About under the menu")
	w.menu.open_about()
	await process_frame
	var about := texts(w.menu._root)
	check(about.any(func(t): return str(t).contains("ALPHA")) and about.any(func(t): return str(t).strip_edges() == "Report a problem") and about.any(func(t): return str(t).strip_edges() == "Back"), "About shows the version, what an alpha is, Report a problem and Back")
	w.menu.close()

	# ---- the problem report
	var report := Diagnostics.report(w)
	check(report.contains("Version: 1.0.3 ALPHA") and report.contains("System:") and report.contains("Video:") and report.contains("Match:") and report.contains("Your nation:"), "a report says the version, the machine and the match")
	w.hud.notice("A message for the report")
	check(Diagnostics.report(w).contains("A message for the report"), "and the last messages")
	var folder := Diagnostics.send(w)
	check(FileAccess.file_exists("user://logs/report.txt") and FileAccess.get_file_as_string("user://logs/report.txt").contains("DOMINION problem report") and (DisplayServer.get_name() == "headless" or DisplayServer.clipboard_get().contains("DOMINION problem report")), "sending it writes the file and copies it (%s)" % folder)
	check(texts(w.hud._help).has("Report a problem"), "Help has a Report a problem button")

	# ---- the testing tools stay available to the alpha's testers, off until they switch them on
	check(not bool(w.testing_tools) or Cheats.allowed(w), "the testing tools are off until a tester switches them on in Settings")
	w.menu.open_settings()
	w.menu.settings_tab = "game"
	w.menu.open_settings()
	await process_frame
	check(texts(w.menu._root).any(func(t): return str(t).contains("Testing tools")), "Settings, Game, offers the Testing tools switch to the alpha's testers")
	w.menu.close()

	# ---- saves
	var S: Script = SaveScript
	check(S.problem_with(null) != "" and S.problem_with("x") != "" and S.problem_with({}) != "" and S.problem_with({"format": "other"}) != "", "a non-save is refused")
	var good: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(S.problem_with(good) == "", "a save made now is accepted (%s)" % S.problem_with(good))
	check(str(good.get("game_version")) == "1.0.3", "and it records the game version")
	for key in ["ai", "buildings", "units", "edges", "economy", "diplomacy", "camera", "game_time", "map"]:
		var cut: Dictionary = good.duplicate()
		cut.erase(key)
		check(S.problem_with(cut) != "", "a save without \"%s\" is refused with a reason" % key)
	var broken: Dictionary = good.duplicate(true)
	broken.ai = "no list"
	check(S.problem_with(broken) != "", "damaged lists are refused")
	broken = good.duplicate(true)
	broken.economy.erase("res")
	check(S.problem_with(broken) != "", "a damaged economy is refused")
	# A damaged file on disk: refused, kept, not listed, no script error.
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open("user://saves/alpha-broken.json", FileAccess.WRITE)
	f.store_string('{"format":"dominion-save","map":"x"')
	f.close()
	var log0: int = w.hud.notice_log.size()
	var ok: bool = w.saves.load_slot("alpha-broken")
	check(not ok and str(w.hud.notice_log[-1]).contains("cannot be loaded") and FileAccess.file_exists("user://saves/alpha-broken.bad.json"), "a damaged file is refused with a message and kept as .bad.json")
	check(not w.menu.list_saves().any(func(s): return str(s.name).ends_with(".bad")), "the kept copy is not offered in the Load list")
	DirAccess.remove_absolute("user://saves/alpha-broken.json")
	DirAccess.remove_absolute("user://saves/alpha-broken.bad.json")

	# ---- real saves from earlier versions (the machine's own, when there are any)
	var older := 0
	var refused := 0
	dir = DirAccess.open("user://saves")
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".json") and not file.ends_with(".bad.json") and not file.begins_with("alpha-") and file != "test.json":
				var data = JSON.parse_string(FileAccess.get_file_as_string("user://saves/" + file))
				older += 1
				if S.problem_with(data) != "":
					refused += 1
					print("   refused: ", file, " ", S.problem_with(data))
	check(refused == 0, "every saved game on this machine passes the check (%d files)" % older)
	if slot != "":
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://saves/" + slot + ".json"))
		var loaded: bool = w.saves.load_slot(slot)
		check(loaded and w.units.size() > 0 and w.buildings.size() > 0, "an earlier save (%s, made by %s) loads: %d units, %d buildings" % [slot, str(data.get("game_version", "an earlier version")), w.units.size(), w.buildings.size()])
		for i in range(30): await physics_frame
		check(w.hud.notice_log.size() > 0 and w.units.size() > 0, "and the match runs on")
	else:
		print("   (no campaign save from an earlier version on this machine: the load is not exercised)")
	print("ALPHA %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("ALPHA %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)

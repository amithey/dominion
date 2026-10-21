extends RefCounted
## Shared by the audit tools (native/ALPHA-1.0-REPORT.md): boots a match, catches every engine and script error as it
## happens (so a failure is laid at the door of the element being tried), keeps a table of ok / WARN / FAIL rows and
## writes it to res://build/audit/<area>.txt. Usage:
##   var K = preload("res://tools/audit_kit.gd").new(self, "units")
##   await K.boot({"map": "island", "players": 4, "nation": 0})
##   K.ok("unit", "tank", "trained and fired")      K.warn(...)      K.fail(...)
##   K.finish()     # prints AUDIT <area> ok=N warn=N fail=N and quits with 0 when nothing failed

## A Logger that remembers every error message the engine reports (script errors included).
class Catcher extends Logger:
	var errors: Array = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _backtraces: Array) -> void:
		mutex.lock()
		errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])
		mutex.unlock()

var tree: SceneTree
var area: String
var w: Node
var catcher := Catcher.new()
var rows: Array = []
var counts := {"ok": 0, "WARN": 0, "FAIL": 0}
var verbose := "--verbose" in OS.get_cmdline_user_args()   ## print the WARN rows too (the file has every row; run-tests reads "fail" anywhere in the log as a failure)

func _init(scene_tree: SceneTree, area_name: String) -> void:
	tree = scene_tree
	area = area_name
	OS.add_logger(catcher)
	# A script error in a tool stops its coroutine and would leave the game running for ever: report and leave.
	var budget := 1500.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--budget="): budget = float(a.split("=")[1])
	tree.create_timer(budget, true, false, true).timeout.connect(func():
		var errs := take_errors()
		print("AUDIT TIMEOUT after %d s in '%s'; errors: %s" % [int(budget), area, " || ".join(PackedStringArray(errs.slice(0, 3)))])
		fail("audit", "timeout", "did not finish within %d s (a script error stopped it, or the machine was busy or asleep)" % int(budget))
		finish()
		tree.quit(3))

## Errors reported since the last call (and clears them).
func take_errors() -> Array:
	catcher.mutex.lock()
	var out: Array = catcher.errors.duplicate()
	catcher.errors.clear()
	catcher.mutex.unlock()
	return out

## Boots the world scene with `config` and starts a match; returns the world.
func boot(config: Dictionary, difficulty := "easy", keep_systems := true) -> Node:
	tree.set_meta("match_config", config)
	tree.change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await tree.process_frame
		if tree.current_scene != null and tree.current_scene.get("nav_ready") == true and tree.current_scene.get("menu") != null:
			w = tree.current_scene
			break
	if w == null:
		fail("boot", "world", "the world scene did not become ready")
		return null
	if w.menu._root == null:
		w.menu.setup(w)
	w.start_match(difficulty)
	w.menu.close()
	w.saves.autosave_every = 0
	if not keep_systems:
		preload("res://tools/test_kit.gd").quiet(w)
	take_errors()
	return w

func frames(n := 4) -> void:
	for i in range(n):
		await tree.process_frame

func _row(status: String, kind: String, name: String, detail: String) -> void:
	counts[status] += 1
	var line := "%s | %s | %s | %s" % [status, kind, name, detail]
	rows.append(line)
	if status == "FAIL" or (status == "WARN" and verbose):
		print("AUDIT ", line)

func ok(kind: String, name: String, detail := "") -> void:
	_row("ok", kind, name, detail)

func warn(kind: String, name: String, detail := "") -> void:
	_row("WARN", kind, name, detail)

func fail(kind: String, name: String, detail := "") -> void:
	_row("FAIL", kind, name, detail)

## Asserts `cond`: ok, or FAIL with `detail`.
func expect(cond: bool, kind: String, name: String, detail := "") -> bool:
	if cond:
		ok(kind, name)
	else:
		fail(kind, name, detail)
	return cond

## Any errors since the last look become one FAIL row against `name`; true when there were none.
func clean(kind: String, name: String) -> bool:
	var errs := take_errors()
	if errs.is_empty():
		return true
	fail(kind, name, "error: " + " || ".join(PackedStringArray(errs.slice(0, 3))))
	return false

## Writes the table and prints the totals; returns the process exit code.
func finish() -> int:
	DirAccess.make_dir_recursive_absolute("res://build/audit")
	var f := FileAccess.open("res://build/audit/%s.txt" % area, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(PackedStringArray(rows)) + "\n")
		f.close()
	print("AUDIT %s ok=%d warnings=%d failures=%d" % [area, counts.ok, counts.WARN, counts.FAIL])   # (not "fail=": run-tests reads the word FAIL anywhere as a failure)
	print("AUDIT_%s %s" % [area.to_upper(), "PASS" if counts.FAIL == 0 else "FAIL"])
	return 0 if counts.FAIL == 0 else 1

# ---------------------------------------------------------------- UI helpers

## Visible, enabled-or-not buttons under `node`, in tree order.
func buttons_in(node: Node, only_enabled := false) -> Array:
	var out := []
	for b in node.find_children("*", "BaseButton", true, false):
		if b.is_visible_in_tree() and not (only_enabled and b.disabled):
			out.append(b)
	return out

func label_of(b: Node) -> String:
	if b is Button and str(b.text).strip_edges() != "":
		return str(b.text).strip_edges()
	for l in b.find_children("*", "Label", true, false):
		if str(l.text).strip_edges() != "":
			return str(l.text).strip_edges()
	return str(b.name)

## All visible text under `node`.
func texts_in(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for c in node.find_children("*", "", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree() and str(c.text).strip_edges() != "":
			out.append(str(c.text).strip_edges())
	return out

## A cheap fingerprint of what the player can see and what the world holds, to tell a press that did something
## from one that did nothing.
func signature() -> int:
	var parts := PackedStringArray()
	parts.append(str(w.hud.notice_log.size()) + (str(w.hud.notice_log[-1]) if not w.hud.notice_log.is_empty() else ""))   # (the log is capped: its length alone stops changing)
	parts.append(str(w.order_mode) + str(w.landing_aim) + str(w.land_buyer != null))
	parts.append(str(w.units.size()))
	parts.append(str(w.buildings.size()))
	parts.append("%d" % int(w.economy.res.money))
	parts.append(str(w.missile_aim) + str(w.placing) + str(w.game_speed))
	parts.append(str(w.hud._win.visible if w.hud.get("_win") != null else ""))
	parts.append(",".join(texts_in(w.hud)))
	if w.menu != null and w.menu._root != null and w.menu._root.is_visible_in_tree():
		parts.append(",".join(texts_in(w.menu._root)))
	parts.append(str(w.diplomacy.score).substr(0, 80))
	return hash("|".join(parts))

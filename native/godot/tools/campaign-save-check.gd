extends SceneTree

class RecordingSaves extends Node:
	var slots: Array[String] = []
	var succeed := true
	var collision := false
	var queries := 0
	func path_of(_slot: String) -> String:
		queries += 1
		return "res://project.godot" if collision and queries == 1 else "res://build/no-such-campaign-save.json"
	func save(slot: String) -> bool:
		slots.append(slot)
		return succeed

class StubWorld extends Node:
	var saves: RecordingSaves

class RecordingMenu extends "res://scripts/menu.gd":
	var closed := false
	func close() -> void:
		closed = true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var w := StubWorld.new()
	w.saves = RecordingSaves.new()
	w.add_child(w.saves)
	root.add_child(w)
	var m := RecordingMenu.new()
	w.add_child(m)
	m.world = w
	m._panel = VBoxContainer.new()
	m.add_child(m._panel)
	var checks := {}
	m.save_campaign()
	checks["Save Game creates a separate readable campaign slot instead of replacing QuickSave"] = w.saves.slots.size() == 1 and w.saves.slots[0].begins_with("Campaign ") and w.saves.slots[0] != "quicksave" and not ":" in w.saves.slots[0] and m.closed
	w.saves.collision = true
	w.saves.queries = 0
	m.closed = false
	m.save_campaign()
	checks["an existing timestamped slot is preserved using a second filename"] = w.saves.slots.back().ends_with(" (2)") and m.closed
	w.saves.succeed = false
	w.saves.collision = false
	m.closed = false
	m.save_campaign()
	checks["failed storage leaves the campaign menu open"] = not m.closed
	checks["failed storage explains recovery without claiming success"] = m._panel.get_child_count() > 0 and m._panel.get_child(0).text.begins_with("Save failed.")
	for key in checks:
		print("%s %s" % ["ok" if checks[key] else "FAIL", key])
	var failures: Array = checks.keys().filter(func(key): return not checks[key])
	print("CAMPAIGN_SAVE: %d checks, %d failures" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

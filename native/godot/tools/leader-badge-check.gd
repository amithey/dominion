extends SceneTree
const Gallery = preload("res://scripts/leader_gallery.gd")
const Factions = preload("res://scripts/factions.gd")
class NationWorld extends Node:
	var map := {"nations": []}
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: failed += 1
func run() -> void:
	var world := NationWorld.new()
	root.add_child(world)
	var hud = preload("res://scripts/hud.gd").new()
	world.add_child(hud)
	hud.world = world
	hud._id_face = Button.new()
	hud.add_child(hud._id_face)
	for index in range(Factions.IDS.size()):
		var nation: Dictionary = Factions.nation(index, true)
		# JSON is how saved nations return; player slot zero can be any country.
		world.map.nations = [JSON.parse_string(JSON.stringify(nation)), Factions.nation((index + 1) % Factions.IDS.size())]
		hud._dress_face()
		var icon: Texture2D = hud._id_face.icon
		check(icon != null and icon is AtlasTexture and icon.atlas.resource_path == Gallery.portrait(Factions.LEADERS[index]), "%s HUD uses its chosen leader artwork after loading" % Factions.IDS[index])
		check(icon != null and icon.get_width() == icon.get_height() and hud._id_face.tooltip_text.contains(Factions.LEADERS[index]), "%s has square close-up and correct identity" % Factions.IDS[index])
	var old_names := ["President E. Hale", "Chairman K. Volkov", "President L. Moreau", "President R. Qadir"]
	for index in range(4):
		for identifier in ["id", "arsenal", "color"]:
			var nation: Dictionary = Factions.nation(index, true)
			nation.people.president = old_names[index]
			for other in ["id", "arsenal", "color"]:
				if other != identifier: nation.erase(other)
			world.map.nations = [nation]
			hud._dress_face()
			var icon: Texture2D = hud._id_face.icon
			check(icon is AtlasTexture and icon.atlas.resource_path == Gallery.portrait(Factions.LEADERS[index]) and nation.people.president == old_names[index], "%s legacy save resolves by %s without altering game state" % [Factions.IDS[index], identifier])
	var successor: Dictionary = Factions.nation(0, true)
	successor.people.president = "President New Successor"
	world.map.nations = [successor]
	hud._dress_face()
	check(hud._id_face.icon == null and hud._id_face.tooltip_text.contains("New Successor"), "unknown successor is not misidentified as the former leader")
	world.queue_free()
	await process_frame
	print("LEADER_BADGE: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

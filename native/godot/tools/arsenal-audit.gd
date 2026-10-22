extends SceneTree
## Dumps what the game says each nation fields (build/arsenal-audit.txt) to check against reality.
var w: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var F = preload("res://scripts/factions.gd")
	var NV = preload("res://scripts/national_variants.gd")
	var n: int = F.IDS.size()
	var lines := []
	var batch := 6
	var first := 0
	while first < n:
		var ids := range(first, mini(first + batch, n))
		var rivals := []
		for i in ids.slice(1): rivals.append(i)
		for i in range(n):
			if rivals.size() >= batch - 1: break
			if i != ids[0] and not i in rivals: rivals.append(i)
		set_meta("match_config", {"map": "frontier", "players": batch, "nation": ids[0], "rivals": rivals, "style": "sandbox", "fog": false})
		change_scene_to_file("res://world.tscn")
		w = null
		for k in range(40000):
			await process_frame
			if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
				w = current_scene
				break
		w.start_match("easy")
		var roster: Array = [ids[0]] + rivals
		for owner in range(w.map.nations.size()):
			var nid: String = F.identity(w, owner)
			if not (F.IDS.find(nid) in ids): continue
			var out := []
			for key in w.unit_defs.keys():
				if key in ["worker", "soldier"]: continue
				if w.unit_allowed(owner, key):
					out.append("%s=%s" % [key, NV.name_for(w, owner, key)])
			out.sort()
			lines.append("## %s
%s
" % [nid, ", ".join(out)])
		first += batch
		print("AUDIT batch done ", first)
	var f := FileAccess.open("res://build/arsenal-audit2.txt", FileAccess.WRITE)
	f.store_string("
".join(lines))
	f.close()
	print("AUDIT done")
	quit()

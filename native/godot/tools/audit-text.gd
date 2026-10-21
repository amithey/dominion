extends SceneTree
## Audit of every player-visible text (native/ALPHA-1.0-REPORT.md): the runtime definitions of every unit, building,
## missile, discovery, track, era, world event, crisis, UN measure, espionage operation and national power, plus every
## literal message in the scripts (`notice("...")`, `_say(...)`, `hud.ask/choose`). Checks on each string:
##   FAIL  a year or a dated event (the standing rule: no years, no "as X did in YEAR"), American spelling, a leaked
##         placeholder (%s, %d, null, nan, inf, {}, TODO), a doubled word, an empty or one-word description
##   WARN  longer than the limit for its kind, a lower-case first letter, doubled spaces, unbalanced brackets,
##         a number in the text that disagrees with the definition (income -30% against the real multiplier)
## Table: res://build/audit/text.txt
const Kit := preload("res://tools/audit_kit.gd")
const Factions := preload("res://scripts/factions.gd")
const Crisis := preload("res://scripts/crisis.gd")
const Brief := preload("res://scripts/brief.gd")
var K
var w: Node
var year_re := RegEx.new()
var us_re := RegEx.new()
var leak_re := RegEx.new()
var dup_re := RegEx.new()
var seen := {}
var texts := 0
func _initialize() -> void: call_deferred("run")

func check(kind: String, name: String, text: String, limit := 400, allow_percent := false) -> void:
	texts += 1
	var t := text.strip_edges()
	var problems := PackedStringArray()
	var notes := PackedStringArray()
	if t == "":
		problems.append("empty")
	else:
		var m := year_re.search(t)
		if m != null: problems.append("a year: '%s'" % m.get_string())
		m = us_re.search(t)
		if m != null: problems.append("American spelling: '%s'" % m.get_string())
		m = leak_re.search(t)
		if m != null and not (allow_percent and m.get_string().begins_with("%")): problems.append("leaked placeholder: '%s'" % m.get_string())
		m = dup_re.search(t)
		if m != null: problems.append("doubled word: '%s'" % m.get_string())
		if t.length() > limit: notes.append("%d characters (limit %d)" % [t.length(), limit])
		if t.length() < 12 and kind in ["unit-desc", "building-desc", "discovery-desc", "missile-help"]: problems.append("too short to explain anything")
		if t.contains("  "): notes.append("doubled spaces")
		if t.count("(") != t.count(")"): notes.append("unbalanced brackets")
		var first := t.substr(0, 1)
		if first != first.to_upper() and first.is_valid_int() == false and not t.begins_with("%"): notes.append("starts with a lower-case letter")
		if t.contains("..") and not t.contains("..."): notes.append("two dots")
	var key := name + " | " + t.substr(0, 90).replace("\n", " / ")
	if not problems.is_empty():
		K.fail(kind, name, "; ".join(problems) + " | " + t.substr(0, 150).replace("\n", " / "))
	elif not notes.is_empty():
		K.warn(kind, name, "; ".join(notes) + " | " + t.substr(0, 110).replace("\n", " / "))
	else:
		K.ok(kind, name, "%d characters" % t.length())

func run() -> void:
	year_re.compile("(?<![\\$\\d.,-])\\b(19[0-9]{2}|20[0-4][0-9])\\b(?![\\d%])")
	us_re.compile("\\b(Center|Centers|center|centers|Armor|armor|Armored|armored|Defense|defense|Color|color|Honor|honor|Neighbor|neighbor|Favorite|favorite|Gray|gray|Program(?:s)? Manager|Aluminum|aluminum|Fueled|Labor|labor|Behavior|behavior|Harbor|harbor|Organization|organization|Recognize|recognize|Analyze|analyze|License|Meter|Liter|Catalog|Check Mark)\\b")
	leak_re.compile("(%[sdif]|%\\.\\d|\\bnull\\b|\\bnan\\b|\\binf\\b|\\bNone\\b|\\bTODO\\b|\\bFIXME\\b|\\{\\}|\\{[a-z_]+\\}|<null>|\\[object)")
	dup_re.compile("\\b([A-Za-z]{3,})\\s+\\1\\b")
	K = Kit.new(self, "text")
	w = await K.boot({"map": "island", "players": 4, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	var Cheats := preload("res://scripts/cheats.gd")
	# every nation's variant names too
	var idents: Array = Factions.IDS.duplicate()
	for id in idents:
		w.map.nations[0]["id"] = id
		w.research._recompute()
		for key in w.unit_defs:
			var n: String = str(w.unit_defs[key].get("name", ""))
			if n.strip_edges() == "" or n.contains("null") or us_re.search(n) != null:
				if not seen.has(id + key):
					seen[id + key] = true
					K.fail("unit-name", "%s as %s" % [key, id], "name '%s'" % n)
	w.map.nations[0]["id"] = "usa"
	w.research._recompute()
	K.ok("text", "variant names", "%d identities x %d units" % [idents.size(), w.unit_defs.size()])

	# ---- definitions
	for key in w.unit_defs:
		var d: Dictionary = w.unit_defs[key]
		check("unit-name", key, str(d.get("name", "")), 60)
		check("unit-desc", key, str(d.get("desc", "")), 400)
		var b: Dictionary = Brief.unit(w, key)
		check("unit-brief", key, Brief.text(b), 330)
	for key in w.building_defs:
		check("building-name", key, str(w.building_defs[key].get("name", "")), 60)
		check("building-desc", key, str(w.building_defs[key].get("desc", "")), 400)
	for key in w.missiles.types():
		var def: Dictionary = w.missiles.def_of(key)
		if def.get("hidden", false): continue
		check("missile-name", key, str(def.get("name", "")), 60)
		check("missile-help", key, preload("res://scripts/weapon_copy.gd").summary(w, key), 520)
		check("missile-tip", key, preload("res://scripts/weapon_copy.gd").tooltip(w, key, false), 900)
	var R: Node = w.research
	for key in R.discoveries:
		check("discovery-name", key, str(R.def_of(key).get("name", "")), 60)
		check("discovery-desc", key, R.desc_of(key), 400)
	for t in R.tracks_cfg:
		check("track-name", t, str(R.tracks_cfg[t].get("name", "")), 60)
	for i in range(R.eras.size()):
		check("era-name", str(i), str(R.eras[i].get("name", "")), 40)
	var ev: RefCounted = w.events if w.events != null else preload("res://scripts/world_events.gd").new(w)
	for key in ev.EVENTS:
		check("event-name", key, str(ev.EVENTS[key].name), 60)
		check("event-why", key, str(ev.EVENTS[key].get("why", "")), 300)
	for key in Crisis.KINDS:
		check("crisis-title", key, str(Crisis.KINDS[key].title), 40)
		check("crisis-text", key, str(Crisis.KINDS[key].text), 300)
	for key in w.un.MEASURES:
		check("un-measure", key, str(w.un.MEASURES[key].name), 60)
	var E = w.espionage
	for key in E.ops():
		check("spy-op-name", key, str(E.ops()[key].get("name", "")), 60)
		check("spy-op-desc", key, str(E.ops()[key].get("desc", "")), 400)
	var FP := preload("res://scripts/faction_powers.gd")
	for id in idents:
		w.map.nations[0]["id"] = id
		var p: Dictionary = FP.power_of(w, 0)
		if not p.is_empty():
			check("power-name", id, str(p.name), 60)
			check("power-desc", id, str(p.desc), 400)
	w.map.nations[0]["id"] = "usa"
	# the nations themselves
	for n in w.map.nations:
		check("nation-name", str(n.get("name", "?")), str(n.get("name", "")), 60)
	for id in idents:
		var profile: Dictionary = preload("res://scripts/national_profile.gd").of_id(id)
		for field in ["strengths", "weaknesses"]:
			for line in profile.get(field, []):
				check("nation-" + field, id, str(line), 200)

	# ---- the reasons a player is told, nation by nation: why a unit, a weapon or a building is closed to them
	var reasons := {}
	var AIData := preload("res://scripts/ai_data.gd")
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for id in idents:
		w.map.nations[0]["id"] = id
		w.research._recompute()
		var why_ai: String = AIData.beyond(w, 0, "aiAutomatedRetaliation")
		if why_ai != "": reasons["ai ceiling (%s)" % id] = why_ai
		var prof: String = str(AIData.profile(w, 0).get("why", ""))
		if prof != "": reasons["ai profile (%s)" % id] = prof
		for key in w.unit_defs:
			var why: String = w.research.unit_locked(key)
			if why != "": reasons["unit %s closed (%s)" % [key, id]] = why
		for key in w.missiles.types():
			if w.missiles.def_of(key).get("hidden", false): continue
			var why2: String = w.missiles.locked(key)
			if why2 != "": reasons["missile %s closed (%s)" % [key, id]] = why2
		for key in w.building_defs:
			var why3: String = preload("res://scripts/national_industry.gd").why(w, 0, key)
			if why3 != "": reasons["building %s closed (%s)" % [key, id]] = why3
		var dossier: String = w.espionage.dossier_text(0) if w.espionage != null else ""
		if dossier != "": reasons["dossier (%s)" % id] = dossier
	w.map.nations[0]["id"] = "usa"
	w.research._recompute()
	var distinct := {}
	for k in reasons:
		distinct[reasons[k]] = k
	K.ok("text", "closed-reasons", "%d reasons, %d distinct" % [reasons.size(), distinct.size()])
	for text in distinct:
		check("closed-reason", str(distinct[text]), str(text), 400)

	# ---- every literal message in the scripts
	var dir := DirAccess.open("res://scripts")
	var strings := {}
	var lit := RegEx.create_from_string("(?:notice|_say|_news|ask|choose|say|warn|record|from_notice|add_report)\\(\\s*\"((?:[^\"\\\\]|\\\\.)+)\"")
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + file)
		for m in lit.search_all(src):
			var s: String = m.get_string(1).replace("\\n", "\n").replace("\\\"", "\"")
			if s.length() < 8:
				continue
			strings[file + ": " + s.substr(0, 60)] = s
	K.ok("text", "messages", "%d literal messages in the scripts" % strings.size())
	for key in strings:
		check("message", key, strings[key], 360, true)
	K.ok("text", "summary", "%d texts checked" % texts)
	quit(K.finish())

extends SceneTree
## Customer round 5, part 1: the picky customer reads the nation screen without playing.
## Every one of the 31 nations is held up against the others: can their colours be told apart on a map,
## do their names, leaders and signatures repeat, does the text a player reads carry a year or a stray
## symbol, do the numbers behind the advantages stay in a believable range, are the pictures there.
## No match is started. Table: res://build/audit/customer5-static.txt (via audit_kit).
const Kit := preload("res://tools/audit_kit.gd")
const Registry := preload("res://scripts/nation_registry.gd")
const NProfile := preload("res://scripts/national_profile.gd")
const AiData := preload("res://scripts/ai_data.gd")
var K
func _initialize() -> void: call_deferred("run")

const REQUIRED := ["id", "group", "name", "leader", "colour", "portrait", "signature", "doctrine"]
var year_re := RegEx.new()
var odd_re := RegEx.new()

## Every string a player can read, found in a nation's data.
func strings_of(v: Variant, out: Array, path := "") -> void:
	if v is String:
		out.append([path, v])
	elif v is Array:
		for i in range(v.size()): strings_of(v[i], out, path + "[%d]" % i)
	elif v is Dictionary:
		for k in v: strings_of(v[k], out, path + "." + str(k))

func distance(a: Color, b: Color) -> float:
	# A weighted RGB distance ("redmean"), close enough to how the eye separates two flags on a map.
	var r := (a.r + b.r) * 0.5
	var dr := (a.r - b.r) * 255.0
	var dg := (a.g - b.g) * 255.0
	var db := (a.b - b.b) * 255.0
	return sqrt((2.0 + r) * dr * dr + 4.0 * dg * dg + (2.0 + 1.0 - r) * db * db)

func run() -> void:
	K = Kit.new(self, "customer5-static")
	year_re.compile("(?<![0-9A-Za-z-])(19[0-9]{2}|20[0-9]{2})(?![0-9A-Za-z-])")
	odd_re.compile("(  |\\bnull\\b|\\bNone\\b|\\bTODO\\b|\\bXXX\\b|\\{|\\}|<[a-z/]|\\bundefined\\b|\\.\\.|,,| ,|\\( | \\))")
	var all: Array = []
	for script in Registry.ORDER: all.append(script.DATA)
	K.ok("nations", "count", "%d nations in the roster" % all.size())

	# --- each nation alone
	for d in all:
		var id := str(d.get("id", "?"))
		var missing := PackedStringArray()
		for f in REQUIRED:
			if not d.has(f) or (d[f] is String and str(d[f]).strip_edges() == ""): missing.append(f)
		if missing.is_empty(): K.ok("fields", id, "all required fields")
		else: K.fail("fields", id, "missing " + ", ".join(missing))

		var name_s := str(d.get("name", ""))
		var leader := str(d.get("leader", ""))
		if name_s != name_s.strip_edges() or name_s.length() < 3:
			K.fail("name", id, "the nation's name '%s' is empty or padded" % name_s)
		elif name_s.length() > 24:
			K.warn("name", id, "'%s' is %d letters: long for a button or a table cell" % [name_s, name_s.length()])
		else: K.ok("name", id, name_s)
		if leader.length() < 8 or leader.length() > 60 or not leader.contains(" "):
			K.fail("leader", id, "leader '%s' does not read like a title and a name" % leader)
		else: K.ok("leader", id, leader)

		var doctrine := str(d.get("doctrine", ""))
		if doctrine.length() < 80: K.warn("doctrine", id, "a short doctrine (%d letters)" % doctrine.length())
		elif doctrine.length() > 520: K.warn("doctrine", id, "a long doctrine (%d letters): it will need scrolling" % doctrine.length())
		else: K.ok("doctrine", id, "%d letters" % doctrine.length())

		# What the player reads: no year, no stray symbol, no doubled space.
		var texts: Array = []
		for key in ["doctrine", "force_names", "leader", "name", "signature"]:
			if d.has(key): strings_of(d[key], texts, key)
		strings_of(NProfile.of_id(id), texts, "profile")
		var years := PackedStringArray()
		var odd := PackedStringArray()
		for t in texts:
			if year_re.search(t[1]) != null: years.append("%s: %s" % [t[0], str(t[1]).substr(0, 60)])
			var m := odd_re.search(t[1])
			if m != null: odd.append("%s has '%s'" % [t[0], m.get_string()])
		if years.is_empty(): K.ok("text", id + " years", "no year in what the player reads")
		else: K.fail("text", id + " years", " | ".join(years.slice(0, 3)))
		if odd.is_empty(): K.ok("text", id + " symbols", "no stray symbol")
		else: K.fail("text", id + " symbols", " | ".join(odd.slice(0, 3)))

		var prof: Dictionary = NProfile.of_id(id)
		var strengths: Array = prof.get("strengths", [])
		var weaknesses: Array = prof.get("weaknesses", [])
		if strengths.size() < 2 or weaknesses.size() < 1: K.fail("profile", id, "%d strengths and %d weaknesses: the comparison screen looks empty" % [strengths.size(), weaknesses.size()])
		elif strengths.size() > 6 or weaknesses.size() > 6: K.warn("profile", id, "%d strengths and %d weaknesses: too long to scan" % [strengths.size(), weaknesses.size()])
		else: K.ok("profile", id, "%d strengths, %d weaknesses" % [strengths.size(), weaknesses.size()])
		var longest := 0
		for s in strengths + weaknesses: longest = maxi(longest, str(s).length())
		if longest > 130: K.warn("profile", id + " line", "a profile line of %d letters" % longest)
		else: K.ok("profile", id + " line", "longest line %d letters" % longest)

		# The advantages must be believable numbers.
		var bonus: Dictionary = prof.get("bonus", {})
		var odd_bonus := PackedStringArray()
		for k in bonus:
			var v := float(bonus[k])
			if absf(v) > 0.6 and k.ends_with("Pct"): odd_bonus.append("%s=%s" % [k, v])
			if k == "happiness" and absf(v) > 10.0: odd_bonus.append("%s=%s" % [k, v])
		if odd_bonus.is_empty(): K.ok("bonus", id, "advantages within range")
		else: K.fail("bonus", id, "extreme: " + ", ".join(odd_bonus))
		var growth := float(prof.get("growth", 1.0))
		if growth < 0.4 or growth > 1.8: K.fail("growth", id, "population growth x%s is extreme" % growth)
		else: K.ok("growth", id, "x%s" % growth)
		var total := 0.0
		for k in bonus:
			if k.ends_with("Pct"): total += float(bonus[k])
		if total > 0.55: K.warn("balance", id, "advantages add to +%d%%: a nation that is simply better" % int(total * 100))
		else: K.ok("balance", id, "advantages add to %+d%%" % int(total * 100))

		# Pictures
		var portrait := str(d.get("portrait", ""))
		var found := false
		for ext in [".png", ".jpg", ".svg", ".webp"]:
			for folder in ["res://ui/leaders/", "res://ui/leaders/portraits/"]:
				if ResourceLoader.exists(folder + portrait + ext) or ResourceLoader.exists(folder + portrait + "-v2" + ext): found = true
		var flag_ok := ResourceLoader.exists("res://ui/leaders/%s-emblem.svg" % portrait) or ResourceLoader.exists("res://ui/leaders/%s-emblem.png" % portrait)
		if found or flag_ok: K.ok("picture", id, "portrait '%s' on disk" % portrait)
		else: K.warn("picture", id, "no file for portrait '%s' under ui/leaders" % portrait)

		# AI block
		var ai: Dictionary = AiData.entry(id)
		var ai_bad := PackedStringArray()
		for f in ["compute", "models", "autonomy", "cyber", "ceiling"]:
			if not ai.has(f): ai_bad.append("no " + f)
			elif int(ai[f]) < 0 or int(ai[f]) > 6: ai_bad.append("%s=%s" % [f, ai[f]])
		if int(ai.get("ceiling", 0)) > 0 and int(ai.get("compute", 0)) == 0 and int(ai.get("models", 0)) == 0: ai_bad.append("an AI ceiling with no compute and no models")
		if ai_bad.is_empty(): K.ok("ai", id, "ceiling %s" % ai.get("ceiling"))
		elif ai_bad.size() == 1 and ai_bad[0].begins_with("an AI ceiling"): K.warn("ai", id, ai_bad[0] + " (reached by imports only?)")
		else: K.fail("ai", id, ", ".join(ai_bad))

	# --- the nations against each other
	var seen_name := {}
	var seen_leader := {}
	var seen_sig := {}
	var seen_id := {}
	var seen_portrait := {}
	for d in all:
		for pair in [[seen_name, "name"], [seen_leader, "leader"], [seen_id, "id"], [seen_portrait, "portrait"]]:
			var key := str(d.get(pair[1], "")).to_lower()
			if pair[0].has(key): K.fail("unique", pair[1], "'%s' is used by %s and %s" % [key, pair[0][key], d.id])
			else: pair[0][key] = d.id
		var sig := str(d.get("signature", "")).to_lower()
		if seen_sig.has(sig): K.warn("unique", "signature", "'%s' is the signature of both %s and %s" % [sig, seen_sig[sig], d.id])
		else: seen_sig[sig] = d.id
	K.ok("unique", "scan", "names, leaders, ids, portraits and signatures compared")

	# Colours: the first thing a customer asks is "which one am I and which is my enemy".
	var close_pairs := 0
	var worst: Array = []
	for i in range(all.size()):
		for j in range(i + 1, all.size()):
			var a := Color(str(all[i].colour))
			var b := Color(str(all[j].colour))
			var dist := distance(a, b)
			var label := "%s / %s" % [all[i].id, all[j].id]
			if dist < 60.0:
				K.fail("colour", label, "distance %d: the two flags cannot be told apart on the map" % int(dist))
				close_pairs += 1
			elif dist < 110.0:
				K.warn("colour", label, "distance %d: easy to mistake at a glance" % int(dist))
			else:
				K.ok("colour", label, "distance %d" % int(dist))
	K.ok("colour", "summary", "%d pairs too close of %d" % [close_pairs, all.size() * (all.size() - 1) / 2])

	# Saved order frozen: the first 28 are the legacy order the saves rely on.
	var legacy := ["usa", "china", "germany", "iran", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "saudi", "brazil", "indonesia", "ukraine", "north_korea", "egypt", "australia", "pakistan", "iraq", "syria", "afghanistan", "yemen", "houthis", "ethiopia", "nigeria", "sudan", "south_sudan"]
	var order_ok := true
	for i in range(legacy.size()):
		if str(all[i].id) != legacy[i]: order_ok = false
	if order_ok: K.ok("order", "saved order", "the first 28 keep their saved positions")
	else: K.fail("order", "saved order", "a saved game would load the wrong nation")
	quit(K.finish())

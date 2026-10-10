extends SceneTree
## Each nation's real reach in artificial intelligence and nuclear weapons
## (ai_data.gd ceilings, defcon.gd, diplomatic_contacts.gd): Afghanistan fields
## no AI and threatens no one with a bomb; Iran gets applied AI only and can
## threaten to leave the NPT, not to strike; the United States keeps the
## frontier and its deterrent. Research: native/NATIONAL-AI-NUCLEAR-RESEARCH-2026-10-10.md.
var errors: Array[String] = []
var passed := 0
var w: Node
const Factions := preload("res://scripts/factions.gd")
const AIData := preload("res://scripts/ai_data.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func idx(id: String) -> int:
	return Factions.IDS.find(id)

func begin(cfg: Dictionary) -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("normal")
	w.menu._root.hide()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)

## Every AI discovery done, as far as the nation may go, and a long run of compute.
func climb() -> void:
	for k in ["microchips", "machineLearning", "militaryAI", "frontierModels"]:
		if AIData.beyond(w, 0, k) == "":   # past the eras and the queue: only the nation's own limit counts here
			w.research.progress[k] = {"stage": 3, "work": 0, "paid": false}
	var a = w.directorate
	for owner in a.st.keys():
		a.st[owner].train = 1.0e9
	for i in range(12):
		a.update(1.0)

func escalation(n: int) -> String:
	var c = w.diplomacy.contacts
	c.session = {"nation": n, "channel": "call", "phase": "talking", "used": [], "counter": {}, "results": []}
	return c._stance_eligibility("escalation")

func run() -> void:
	# ---- the data: every nation has a researched ceiling and a reason
	for id in Factions.IDS:
		var row: Dictionary = AIData.PROFILE.get(id, {})
		check(row.has("ceiling") and str(row.get("why", "")) != "", "%s has an AI ceiling (%s) and a reason" % [id, str(row.get("ceiling", "?"))])
	check(int(AIData.PROFILE.usa.ceiling) == 5 and int(AIData.PROFILE.china.ceiling) == 5, "only the two frontier powers can reach general intelligence")
	check(int(AIData.PROFILE.afghanistan.ceiling) == 0 and int(AIData.PROFILE.iraq.ceiling) <= 1 and int(AIData.PROFILE.syria.ceiling) <= 1, "Afghanistan none; Iraq and Syria next to none")
	check(int(AIData.PROFILE.iran.ceiling) == 2 and int(AIData.PROFILE.north_korea.ceiling) == 2, "Iran and North Korea: applied AI under sanctions, no military AI at scale")
	for txt in AIData.PROFILE.values().map(func(r): return str(r.why)):
		if txt.contains("19") or txt.contains("20"):
			check(false, "no dates in the game's text: %s" % txt)

	# ---- Afghanistan
	await begin({"map": "crown", "players": 3, "nation": idx("afghanistan"), "rivals": [0, idx("pakistan")]})
	var r: Node = w.research
	check(r.blocker("machineLearning").begins_with("Beyond your nation's AI capacity"), "Afghanistan cannot pursue Machine Learning: %s" % r.blocker("machineLearning"))
	check(r.enqueue("machineLearning") != "", "and the research queue refuses it")
	climb()
	check(w.directorate.cap(0) == 0 and w.directorate.level(0) == 0, "its AI level stays at none")
	check(not w.directorate.researched(0, "militaryAI"), "no military AI")
	check(not w.defcon.nuclear(0), "no nuclear weapons")
	check(escalation(1).contains("no nuclear weapons"), "no escalation warning to make: %s" % escalation(1))
	w.diplomacy.declare_war(1, 0)
	var t0: float = w.defcon.tension
	w.defcon.raise_posture()
	w.defcon.raise_posture()
	var said: String = w.defcon.raise_posture()
	check(int(w.defcon.posture[0]) == 2, "it can still mobilise its forces (DEFCON 2)")
	check(not said.contains("Nuclear release"), "but nothing says its nuclear release is authorised: %s" % said)
	check(w.defcon.release_blocked() == "Your nation has no nuclear weapons.", "there is nothing to release")
	check(float(w.defcon.floor_now()[0]) < 65.0 and not str(w.defcon.cause()).contains("your forces' alert"), "its mobilisation does not set the world's nuclear tension (floor %d)" % int(w.defcon.floor_now()[0]))
	check(w.defcon.tension <= maxf(t0, 45.0), "nor raise it to the brink (%d)" % int(w.defcon.tension))
	var rival_id: int = idx("pakistan")
	check(w.directorate.cap(2) <= 2, "Pakistan, a rival here, never trains past applied AI (cap %d)" % w.directorate.cap(2))

	# ---- Iran
	await begin({"map": "crown", "players": 3, "nation": idx("iran"), "rivals": [0, idx("israel")]})
	r = w.research
	check(r.blocker("machineLearning") == "" or not r.blocker("machineLearning").begins_with("Beyond"), "Iran may pursue Machine Learning")
	check(r.blocker("militaryAI").begins_with("Beyond") and r.blocker("frontierModels").begins_with("Beyond"), "but not military AI at scale or frontier models")
	climb()
	check(w.directorate.cap(0) == 2, "its AI stops at applied machine learning (cap %d)" % w.directorate.cap(0))
	check(not w.defcon.nuclear(0), "Iran has no bomb")
	check(w.diplomacy.contacts._escalation_means() == "threshold", "as a threshold state it can threaten to leave the NPT")
	check(escalation(1) == "" or escalation(1).begins_with("Not in"), "so the warning is offered (at war or in a cold spell)")
	w.diplomacy.declare_war(1, 0)
	check(escalation(1) == "", "and at war it may make it")

	# ---- the United States
	await begin({"map": "crown", "players": 3, "nation": 0, "rivals": [idx("afghanistan"), idx("iran")]})
	r = w.research
	check(r.blocker("frontierModels") == "" or not r.blocker("frontierModels").begins_with("Beyond"), "the United States may pursue frontier models")
	climb()
	check(w.directorate.cap(0) == 4, "and reach the frontier (cap %d)" % w.directorate.cap(0))
	check(w.defcon.nuclear(0) and w.diplomacy.contacts._escalation_means() == "armed", "a nuclear power: its warnings are backed")
	check(w.defcon.posture_text(2, true).contains("Nuclear release authorised") and not w.defcon.posture_text(2, false).contains("Nuclear"), "only an armed nation's mobilisation authorises release")
	for n in w.ai.nations:
		n.tech = 10.0   # rivals at the height of technology
	check(w.directorate._research_cap(1) >= 4, "(their technology alone would allow the frontier)")
	check(w.directorate.cap(1) == 0, "rival Afghanistan's AI stays at none, whatever its technology (cap %d)" % w.directorate.cap(1))
	check(w.directorate.cap(2) <= 2, "rival Iran's at applied AI (cap %d)" % w.directorate.cap(2))

	print("NATIONAL_REALISM %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("NATIONAL_REALISM %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)

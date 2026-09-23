extends SceneTree
## Firm language in leader contacts: the right statements for peacetime,
## a cold war and war, and each has its consequence.
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func talk(c: Node, n: int) -> void:
	c.cooldowns.clear()
	c.session = {}
	for channel in ["visit", "phone", "mediator"]:
		if c.start_reason(n, channel) == "":
			c.begin(n, channel)
			break
	for i in range(400):
		c.advance(1)
		if c.session.get("phase", "") == "talking":
			break
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(2000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	w.start_match("easy")
	paused = true
	var c: Node = w.diplomacy.contacts
	var d: Node = w.diplomacy
	w.economy.res.money = 50000.0
	# Peacetime.
	d.set_score(0, 1, 10)
	check(c.relation_state(1) == "peace", "relations +10 read as peacetime")
	talk(c, 1)
	check(c.session.get("phase", "") == "talking", "a state visit reaches the table")
	var before: float = d.rel(0, 1)
	c.propose("condemn")
	check(d.rel(0, 1) <= before - 10.0, "a public condemnation costs relations")
	check(c.topic_reason("expel") != "", "expelling diplomats is not for peacetime")
	# Cold war.
	d.set_score(0, 2, -50)
	check(c.relation_state(2) == "cold", "relations -50 read as a cold war")
	talk(c, 2)
	before = d.rel(0, 2)
	c.propose("hotline")
	check(d.rel(0, 2) > before, "a de-escalation hotline eases tension")
	var enemy_next: float = w.espionage.enemy_next
	c.propose("expel")
	check(w.espionage.enemy_next > enemy_next, "expelling their diplomats stalls their spying")
	# War.
	d.declare_war(0, 3)
	check(c.relation_state(3) == "war", "war reads as war")
	talk(c, 3)
	check(c.topic_reason("protest") != "", "a formal protest is not for wartime")
	before = d.rel(0, 3)
	c.propose("prisoners")
	check(d.rel(0, 3) > before and d.at_war(0, 3), "a prisoner exchange warms relations and the war goes on")
	check(c.session.results.size() > 0 and c.title("prisoners") == "Prisoner exchange", "the communique records the statement")
	print("FIRM_DIPLOMACY %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)

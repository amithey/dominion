extends RefCounted
## Shared by the test tools: switches off the systems a check does not test,
## so a new system cannot break an old check that never meant to measure it
## (the war costs, the home front and the world events each broke unrelated
## checks once). Usage, after w.start_match():
##     preload("res://tools/test_kit.gd").quiet(w)              # all of them off
##     preload("res://tools/test_kit.gd").quiet(w, ["fog"])     # all but the fog
## Systems: "fog" (fog_of_war.gd), "support" (war_support.gd), "events"
## (world_events.gd), "victory" (victory.gd), "un" (un.gd), "wmd" (wmd.gd: fallout,
## gas, outbreaks and rivals' chemical attacks), "generals" (generals.gd: rivals'
## generals' traits), "defcon" (defcon.gd: nuclear release, rivals' nuclear use),
## "costs" (war_costs.gd: the
## player and every rival funded so shots, fuel and interceptors never run dry).

static func quiet(w: Node, keep := []) -> void:
	if not "fog" in keep and w.get("fog") != null:
		w.fog.enabled = false
		RenderingServer.global_shader_parameter_set("fog_on", false)
		for u in w.units: u.node.visible = true
		for b in w.buildings: b.root.visible = true
		for d in w.deposits: d.node.visible = true
	if not "support" in keep:
		w.support = null
	if not "events" in keep:
		w.events = null
	if not "victory" in keep:
		w.victory = null
	if not "un" in keep and w.get("un") != null:
		w.un = null
	if not "wmd" in keep and w.get("wmd") != null:
		w.wmd = null
	if not "generals" in keep and w.get("generals") != null:
		for u in w.units: u.erase("general")
		w.generals = null
	if not "defcon" in keep and w.get("defcon") != null:
		w.defcon = null
	if not "tests" in keep and w.get("tests") != null:
		w.tests = null
	if not "directorate" in keep and w.get("directorate") != null:
		w.directorate = null   # AI (ai_directorate.gd): autonomy incidents, AI cyber campaigns
	if not "costs" in keep:
		fund(w)
	if w.research != null:
		w.research._recompute()

## Plenty of money and oil for the player and every rival.
static func fund(w: Node) -> void:
	if w.economy != null:
		w.economy.res.money = maxf(float(w.economy.res.get("money", 0.0)), 1000000.0)
		w.economy.res.oil = maxf(float(w.economy.res.get("oil", 0.0)), 100000.0)
	if w.ai != null:
		for n in w.ai.nations:
			n.money = maxf(float(n.money), 10000000.0)

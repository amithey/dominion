extends RefCounted
## For testing the game (F10, or "Testing: everything" in the pause menu):
## every era reached, every discovery your nation fields complete, every
## research track at its last level, $1,000,000 more, every store filled (and
## the limits raised to 99,999 for good, as with F8), every home filled and
## 200 more army capacity. A discovery only another nation fields (the F-35,
## Iron Dome...) stays theirs: your nation's technology stays its own.
## Units already in the field keep their stats; what is trained next has it all.

const MONEY := 1000000.0

## The testing shortcuts (F8, F10, the Cheats button and screen) exist when
## running from the editor, with --testing, or once "Testing tools" is
## switched on in Settings, Game (world.testing_tools, saved with the settings).
static func allowed(w: Node = null) -> bool:
	if w != null and bool(w.get("testing_tools")):
		return true
	return OS.has_feature("editor") or "--testing" in OS.get_cmdline_user_args() or "--testing" in OS.get_cmdline_args()

static func everything(w: Node) -> String:
	var r: Node = w.research
	var opened := 0
	if r != null:
		r.era = r.eras.size() - 1
		for key in r.discoveries:
			if preload("res://scripts/national_arsenal.gd").foreign(w, r.def_of(key).get("nation", "")) != "":
				continue   # another nation's own
			if not r.done(key):
				opened += 1
			r.progress[key] = {"stage": 3, "work": 0.0, "paid": false}
		for key in r.tracks_cfg:
			r.tracks[key] = int(r.tracks_cfg[key].max)
			r.progress.erase("track:" + key)
		r.queue.clear()
		r._recompute()
		r.changed.emit()
	var eco: Node = w.economy
	eco.grant_test_resources()   # (after the research: its bonuses raise the limits it fills)
	eco.res.money += MONEY - 100000.0
	eco.changed.emit()
	return "Testing: every era, all %d of your discoveries complete (%d just now), every research track maxed; +$1,000,000, every store filled, +200 army capacity." % [r.completed_count() if r != null else 0, opened]

## +$100,000, every store filled (limits 99,999) and +200 army capacity (F8).
static func resources(w: Node) -> String:
	w.economy.grant_test_resources()
	return "Testing: +$100,000, every store filled (limits 99,999), +200 army capacity."

## The next era at once, with its reward.
static func next_era(w: Node) -> String:
	var r: Node = w.research
	if r == null or r.era + 1 >= r.eras.size():
		return "Testing: already in the last era."
	r.era += 1
	var reward: Dictionary = r.eras[r.era].reward
	w.economy.res.money += float(reward.get("money", 0))
	r.points += float(reward.get("research", 0))
	r._recompute()
	r.changed.emit()
	return "Testing: the %s." % r.eras[r.era].name

## Every building of yours under construction finished, and every unit or
## missile in training delivered on the next step.
static func finish_all(w: Node) -> String:
	var built := 0
	var queued := 0
	for b in w.buildings.duplicate():
		if int(b.owner) != 0 or b.dead:
			continue
		if not b.built:
			w.finish_building(b)
			built += 1
		if not b.get("queue", []).is_empty():
			b.queue_prog = 0.999
			queued += 1
	return "Testing: %d building%s finished, %d production line%s delivering." % [built, "" if built == 1 else "s", queued, "" if queued == 1 else "s"]

## The fog of war lifted (or laid again).
static func toggle_fog(w: Node) -> String:
	var fog = w.get("fog")
	if fog == null:
		return "Testing: no fog of war in this match."
	fog.enabled = not fog.enabled
	RenderingServer.global_shader_parameter_set("fog_on", fog.enabled)
	fog.refresh()
	return "Testing: the fog of war is %s." % ("back" if fog.enabled else "lifted: you see the whole map")

## Peace with every nation at war with you.
static func peace(w: Node) -> String:
	var d: Node = w.diplomacy
	var ended := 0
	for i in range(1, d.n):
		if d.at_war(0, i):
			d.make_peace(0, i)
			ended += 1
	return "Testing: peace with %d nation%s." % [ended, "" if ended == 1 else "s"]

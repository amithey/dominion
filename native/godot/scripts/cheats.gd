extends RefCounted
## For testing the game (F10, or "Testing: everything" in the pause menu):
## every era reached, every discovery your nation fields complete, every
## research track at its last level, $1,000,000 more, every store filled (and
## the limits raised to 99,999 for good, as with F8), every home filled and
## 200 more army capacity. A discovery only another nation fields (the F-35,
## Iron Dome...) stays theirs: your nation's technology stays its own.
## Units already in the field keep their stats; what is trained next has it all.

const MONEY := 1000000.0

## The testing shortcuts (F8, F10 and the pause-menu button) exist only when
## running from the editor, or with --testing; an installed game hides them.
static func allowed() -> bool:
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

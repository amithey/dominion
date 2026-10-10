extends RefCounted
## Each nation's standing in artificial intelligence (ai_directorate.gd), 0..5:
##   compute    the computing power its industry already has (chips, data
##              centres, power): national compute a second, before any AI Data
##              Center the player or a rival builds
##   models     how good its models are: training runs cost less
##   autonomy   how far its forces already field autonomous weapons: the
##              military effects of its AI are stronger
##   cyber      its cyber services: AI cyber campaigns succeed more often, and
##              hostile ones fail more often
## and "lean", the doctrine a rival chooses at war: "in" (a human approves every
## strike), "on" (machines act, a human may stop them) or "out" (no human in the
## loop once the weapon is launched); and "signs", the AI treaties it signs at
## the start ("laws": the Treaty on Autonomous Weapons, which most of the world
## backs and the large military powers do not; "nuclear": the declaration that
## humans keep control of nuclear weapons, which about sixty states signed).
## Sources (comments only, never in the game's text): native/AI-RESEARCH-2026-10-06.md
## (frontier compute shares, national AI rankings, battlefield autonomy reports).
## A nation added later reads "ai_profile" from its map entry, or DEFAULT.

const Factions := preload("res://scripts/factions.gd")

## "ceiling": the highest AI level the nation can reach at all, whatever it
## researches or builds (its chips, compute, power, talent and access to the
## world's clouds), and "why", the reason in a sentence for the AI tab and the
## research list. 5 frontier, 4 near-frontier, 3 military AI, 2 applied
## machine learning, 1 little more than imported software, 0 none.
## Research per nation (comments only): native/NATIONAL-AI-NUCLEAR-RESEARCH-2026-10-10.md.
const PROFILE := {
	"usa":         {"compute": 5, "models": 5, "autonomy": 5, "cyber": 5, "lean": "on", "signs": ["nuclear"], "ceiling": 5,
		"why": "Most of the world's frontier compute and the leading AI laboratories."},
	"china":       {"compute": 3, "models": 5, "autonomy": 4, "cyber": 5, "lean": "on", "signs": [], "ceiling": 5,
		"why": "Frontier models of its own and the second-largest compute, despite chip controls."},
	"uk":          {"compute": 2, "models": 4, "autonomy": 3, "cyber": 4, "lean": "in", "signs": ["nuclear"], "ceiling": 4,
		"why": "World-class laboratories and research, but a fraction of the leaders' compute."},
	"eu":          {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in", "signs": ["laws", "nuclear"], "ceiling": 4,
		"why": "Strong research and new public AI factories, but few frontier laboratories."},
	"israel":      {"compute": 1, "models": 3, "autonomy": 5, "cyber": 5, "lean": "on", "signs": [], "ceiling": 4,
		"why": "A dense AI industry and battle-tested military AI, but little compute of its own."},
	"russia":      {"compute": 1, "models": 2, "autonomy": 4, "cyber": 4, "lean": "out", "signs": [], "ceiling": 3,
		"why": "Domestic models and battlefield autonomy, but cut off from advanced chips."},
	"ukraine":     {"compute": 1, "models": 2, "autonomy": 5, "cyber": 3, "lean": "on", "signs": ["nuclear"], "ceiling": 3,
		"why": "The most battle-tested drone autonomy in the world, and almost no compute."},
	"south_korea": {"compute": 2, "models": 3, "autonomy": 3, "cyber": 3, "lean": "in", "signs": ["nuclear"], "ceiling": 4,
		"why": "It makes the memory chips AI runs on and is building a national GPU fleet."},
	"japan":       {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in", "signs": ["nuclear"], "ceiling": 4,
		"why": "Large public supercomputers and chip-making tools; its models trail the leaders."},
	"india":       {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in", "signs": [], "ceiling": 4,
		"why": "A deep pool of engineers and a national GPU mission, though compute is still scarce."},
	"saudi":       {"compute": 3, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in", "signs": ["laws"], "ceiling": 3,
		"why": "It buys compute at scale, but has few researchers and no leading models."},
	"turkiye":     {"compute": 1, "models": 2, "autonomy": 3, "cyber": 2, "lean": "on", "signs": [], "ceiling": 3,
		"why": "Autonomous drones from its own defence industry; modest compute."},
	"australia":   {"compute": 1, "models": 2, "autonomy": 3, "cyber": 3, "lean": "in", "signs": ["nuclear"], "ceiling": 3,
		"why": "Good research and uncrewed combat aircraft built with allies; modest compute."},
	"brazil":      {"compute": 1, "models": 1, "autonomy": 1, "cyber": 2, "lean": "in", "signs": ["laws"], "ceiling": 3,
		"why": "A funded national AI plan and public supercomputers; a young AI industry."},
	"indonesia":   {"compute": 1, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in", "signs": ["laws"], "ceiling": 2,
		"why": "Sovereign AI centres are being built with foreign partners; its forces buy rather than build AI."},
	"iran":        {"compute": 0, "models": 1, "autonomy": 2, "cyber": 3, "lean": "on", "signs": ["laws"], "ceiling": 2,
		"why": "Applied AI in its drones and missiles, but sanctions bar advanced chips and foreign clouds."},
	"pakistan":    {"compute": 0, "models": 1, "autonomy": 2, "cyber": 3, "lean": "in", "signs": ["laws"], "ceiling": 2,
		"why": "A first national AI policy and a few thousand GPUs; power and connectivity fall short."},
	"egypt":       {"compute": 0, "models": 1, "autonomy": 1, "cyber": 2, "lean": "in", "signs": ["laws"], "ceiling": 2,
		"why": "A national AI strategy, but little compute and no large cloud provider in the country."},
	"north_korea": {"compute": 0, "models": 1, "autonomy": 1, "cyber": 4, "lean": "out", "signs": [], "ceiling": 2,
		"why": "AI-guided drones shown to the press, but no access to modern chips."},
	"iraq":        {"compute": 0, "models": 0, "autonomy": 0, "cyber": 1, "lean": "in", "signs": ["laws"], "ceiling": 1,
		"why": "Its first modern data centre is still being built, and the grid fails in the summer heat."},
	"syria":       {"compute": 0, "models": 0, "autonomy": 0, "cyber": 1, "lean": "in", "signs": ["laws"], "ceiling": 1,
		"why": "A power grid being rebuilt after the war; electricity for only part of the day."},
	"afghanistan": {"compute": 0, "models": 0, "autonomy": 0, "cyber": 0, "lean": "in", "signs": ["laws"], "ceiling": 0,
		"why": "No data centres, an internet the authorities switch off, and women barred from study."},
}
const DEFAULT := {"compute": 1, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in", "signs": ["laws"], "ceiling": 2,
	"why": "Imported AI services and a little compute of its own."}
## The AI level each discovery leads to: a nation whose ceiling is lower does
## not pursue it (research.gd blocker), and rivals never train past it.
const NEEDS := {"machineLearning": 1, "militaryAI": 3, "collaborativeCombatAircraft": 3, "frontierModels": 4, "agiProject": 4}
## The chip supply chain: nations that can deny advanced chips to another
## (export controls on AI chips and the machines that make them), and those
## that make the chips (they sell more in a shortage).
const CONTROLLERS := ["usa", "eu", "japan", "south_korea", "uk"]
const CHIP_MAKERS := ["south_korea", "japan", "usa", "china"]

## The profile of nation `owner` (a map entry's "ai_profile" overrides it).
static func profile(w: Node, owner: int) -> Dictionary:
	var row: Dictionary = PROFILE.get(Factions.identity(w, owner), DEFAULT).duplicate()
	if owner >= 0 and owner < w.map.nations.size():
		row.merge(w.map.nations[owner].get("ai_profile", {}), true)
	return row

static func rating(w: Node, owner: int, field: String) -> int:
	return int(profile(w, owner).get(field, 1))

## The highest AI level nation `owner` can reach (its profile's ceiling).
static func ceiling(w: Node, owner: int) -> int:
	return int(profile(w, owner).get("ceiling", 2))

## Why `owner` may not pursue AI discovery `key` ("" when it may).
static func beyond(w: Node, owner: int, key: String) -> String:
	if not NEEDS.has(key) or ceiling(w, owner) >= int(NEEDS[key]):
		return ""
	return "Beyond your nation's AI capacity: %s" % str(profile(w, owner).get("why", ""))

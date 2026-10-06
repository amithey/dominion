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
## loop once the weapon is launched).
## Sources (comments only, never in the game's text): native/AI-RESEARCH-2026-10-06.md
## (frontier compute shares, national AI rankings, battlefield autonomy reports).
## A nation added later reads "ai_profile" from its map entry, or DEFAULT.

const Factions := preload("res://scripts/factions.gd")

const PROFILE := {
	"usa":         {"compute": 5, "models": 5, "autonomy": 5, "cyber": 5, "lean": "on"},
	"china":       {"compute": 3, "models": 5, "autonomy": 4, "cyber": 5, "lean": "on"},
	"uk":          {"compute": 2, "models": 4, "autonomy": 3, "cyber": 4, "lean": "in"},
	"eu":          {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in"},
	"israel":      {"compute": 1, "models": 3, "autonomy": 5, "cyber": 5, "lean": "on"},
	"russia":      {"compute": 1, "models": 2, "autonomy": 4, "cyber": 4, "lean": "out"},
	"ukraine":     {"compute": 1, "models": 2, "autonomy": 5, "cyber": 3, "lean": "on"},
	"south_korea": {"compute": 2, "models": 3, "autonomy": 3, "cyber": 3, "lean": "in"},
	"japan":       {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in"},
	"india":       {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in"},
	"saudi":       {"compute": 3, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in"},
	"turkiye":     {"compute": 1, "models": 2, "autonomy": 3, "cyber": 2, "lean": "on"},
	"australia":   {"compute": 1, "models": 2, "autonomy": 3, "cyber": 3, "lean": "in"},
	"iran":        {"compute": 0, "models": 1, "autonomy": 2, "cyber": 3, "lean": "on"},
	"north_korea": {"compute": 0, "models": 1, "autonomy": 1, "cyber": 4, "lean": "out"},
	"syria":       {"compute": 0, "models": 0, "autonomy": 0, "cyber": 1, "lean": "in"},
	"afghanistan": {"compute": 0, "models": 0, "autonomy": 0, "cyber": 0, "lean": "in"},
}
const DEFAULT := {"compute": 1, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in"}

## The profile of nation `owner` (a map entry's "ai_profile" overrides it).
static func profile(w: Node, owner: int) -> Dictionary:
	var row: Dictionary = PROFILE.get(Factions.identity(w, owner), DEFAULT).duplicate()
	if owner >= 0 and owner < w.map.nations.size():
		row.merge(w.map.nations[owner].get("ai_profile", {}), true)
	return row

static func rating(w: Node, owner: int, field: String) -> int:
	return int(profile(w, owner).get(field, 1))

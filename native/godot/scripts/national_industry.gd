extends RefCounted
## Which nations have the industrial base for the buildings that need one.
## Research and sources: native/NATIONAL-INDUSTRY-RESEARCH-2026-10-13.md.
##
## A militia government does not build a semiconductor fab or a hyperscale data
## centre, and a country without a power reactor does not field a Nuclear Reactor
## because the build menu lists it. national_variants.builds() asks here:
##   Chip Fab         front-end wafer fabrication: the United States, China,
##                    the EU, the UK, Japan, South Korea, Israel, India, Russia
##   AI Data Centre,  a domestic compute and technology industry: AI ceiling 2 or
##   Technology Park  more (ai_data.gd), so not the war-torn or the newly rebuilt
##   Targeting        a military AI programme: AI ceiling 3 or more
##   Fusion Cell
##   Nuclear Reactor  a civil nuclear programme (operating, commissioning or
##                    under construction): not Australia or Indonesia (research
##                    reactors only); Iraq, Syria, Afghanistan and the regional
##                    entities are barred elsewhere
## A nation that cannot build a Chip Fab reaches the era's "compute" goal with
## universities instead (research.era_requirements).

const Factions := preload("res://scripts/factions.gd")
const CHIP_FAB := ["usa", "china", "germany", "france", "uk", "japan", "south_korea", "israel", "india", "russia"]
const NO_REACTOR := ["australia", "indonesia"]
const DATA_CENTRE_CEILING := 2

const WHY := {
	"chipFab": "No semiconductor fabrication industry: chips are imported.",
	"techPark": "No domestic technology sector to build a park around.",
	"aiDataCenter": "No domestic compute industry for a data centre: AI services are imported.",
	"fusionCell": "No military AI programme to fuse targets with.",
	"nuclearReactor": "No civil nuclear power programme.",
}

## Whether nation `owner` has the industrial base for building `key`.
static func allowed(w: Node, owner: int, key: String) -> bool:
	var id: String = Factions.identity(w, owner)
	match key:
		"chipFab": return id in CHIP_FAB
		"techPark", "aiDataCenter": return preload("res://scripts/ai_data.gd").ceiling(w, owner) >= DATA_CENTRE_CEILING
		"fusionCell": return preload("res://scripts/ai_data.gd").ceiling(w, owner) >= 3   # military AI
		"nuclearReactor": return not id in NO_REACTOR
	return true

## Why not, in words for the build card ("" when it may).
static func why(w: Node, owner: int, key: String) -> String:
	return "" if allowed(w, owner, key) else str(WHY.get(key, ""))

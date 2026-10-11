extends RefCounted
## The United Nations' facts, by faction id: the permanent seats, the regional
## groups, the Non-Aligned Movement, whom each permanent member shields, and
## the sanctions regimes in force in 2026. Research and sources:
## native/CBRN-UN-RESEARCH-2026-10-05.md.
##
## A nation added later needs nothing here to take its seat in the General
## Assembly: it may carry "un_region", "nam" or "un" ("member" / "observer")
## on its nation dictionary. Otherwise it is a member with an unassigned region,
## with no assumed Non-Aligned Movement affiliation.

const Factions := preload("res://scripts/factions.gd")

## The five permanent members (Charter Art. 23). The game's European Union
## holds France's seat and arsenal.
const PERMANENT := ["usa", "russia", "china", "uk", "france"]
const PROXY := {"eu": "france"}

## Elected seats by region (General Assembly resolution 1991 A (XVIII), 1963):
## three African, two Asia-Pacific, two Latin American and Caribbean, two
## Western European and Others, one Eastern European.
const SEATS := {"Africa": 3, "Asia-Pacific": 2, "Latin America & Caribbean": 2, "Western Europe & Others": 2, "Eastern Europe": 1}
const REGION := {
	"usa": "Western Europe & Others", "uk": "Western Europe & Others", "eu": "Western Europe & Others", "australia": "Western Europe & Others",
	"turkiye": "Western Europe & Others", "israel": "Western Europe & Others",
	"russia": "Eastern Europe", "ukraine": "Eastern Europe",
	"china": "Asia-Pacific", "japan": "Asia-Pacific", "india": "Asia-Pacific", "iran": "Asia-Pacific", "south_korea": "Asia-Pacific",
	"north_korea": "Asia-Pacific", "pakistan": "Asia-Pacific", "indonesia": "Asia-Pacific", "saudi": "Asia-Pacific", "iraq": "Asia-Pacific",
	"syria": "Asia-Pacific", "afghanistan": "Asia-Pacific",
	"egypt": "Africa",
	"brazil": "Latin America & Caribbean",
}
## Members of the Non-Aligned Movement (they guard sovereignty and shy from
## coercion of one another).
const NAM := ["india", "indonesia", "iran", "egypt", "saudi", "pakistan", "iraq", "syria", "afghanistan", "north_korea"]
const WESTERN := ["usa", "uk", "eu", "australia", "japan", "south_korea", "israel", "turkiye", "ukraine"]
## Whom each permanent member has shielded with its veto or would.
const SHIELDS := {
	"usa": ["israel"],
	"russia": ["iran", "north_korea"],
	"china": ["north_korea", "pakistan", "russia", "iran"],
}
## Sanctions regimes in force when the match begins.
const STANDING := {
	"south_sudan": {"res": "the South Sudan arms embargo (scenario snapshot: renewed through May 2027)", "measures": ["embargo"]},
	"iran": {"res": "its nuclear programme", "measures": ["embargo", "targeted"]},
	"north_korea": {"res": "its nuclear and missile programmes (sectoral restrictions)", "measures": ["embargo", "targeted"]},
	"afghanistan": {"res": "its government's ties to armed groups", "measures": ["targeted"]},
}

static func ident(w: Node, i: int) -> String:
	return Factions.identity(w, i)

static func seat_of(id: String) -> String:
	return PROXY.get(id, id)

static func permanent(w: Node, i: int) -> bool:
	var n: Dictionary = w.map.nations[i] if i >= 0 and i < w.map.nations.size() else {}
	# A seat override represents an existing P5, never creates a sixth veto.
	return str(n.get("un_seat", seat_of(ident(w, i)))) in PERMANENT

static func region(w: Node, i: int) -> String:
	var n: Dictionary = w.map.nations[i] if i >= 0 and i < w.map.nations.size() else {}
	var r := str(n.get("un_region", REGION.get(ident(w, i), "Unassigned")))
	return r if SEATS.has(r) else "Unassigned"

static func nam(w: Node, i: int) -> bool:
	var n: Dictionary = w.map.nations[i] if i >= 0 and i < w.map.nations.size() else {}
	if n.has("nam"):
		return bool(n.nam)
	var id := ident(w, i)
	if id in NAM: return true
	if id in WESTERN or id in PERMANENT or PROXY.has(id) or REGION.has(id): return false
	return false   # unknown identity does not imply a political affiliation

static func status(w: Node, i: int) -> String:
	var n: Dictionary = w.map.nations[i] if i >= 0 and i < w.map.nations.size() else {}
	return str(n.get("un", "member"))

static func shields(w: Node, p5: int, target: int) -> bool:
	return ident(w, target) in SHIELDS.get(ident(w, p5), [])

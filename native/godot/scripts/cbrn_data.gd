extends RefCounted
## Who really has which unconventional weapon, and who is bound by which treaty.
## Research and sources: native/CBRN-UN-RESEARCH-2026-10-05.md.
##
## Everything is keyed by faction id (factions.gd: "usa", "china", "eu" for
## France's arsenal and seat, ...). A nation added later is covered by:
##   1. an entry here (the place to say what it really has), or
##   2. fields on its nation dictionary ("cbrn": [weapon keys], "npt", "cwc",
##      "bwc", "icc", "un_region", "nam"), or
##   3. the rules: a dirty bomb needs only a Nuclear Reactor; chlorine can be
##      improvised by any state; nuclear weapons follow the nuclear-armed list
##      (national_variants.gd) or a nuclear breakout (wmd.gd).
## Absent all three, a new nation is assumed a party to the NPT, the CWC and the
## BWC with no unconventional weapons, and a UN member of the Asia-Pacific group.

const Factions := preload("res://scripts/factions.gd")

## Weapon -> the nations that have it, and why (the evidence, briefly).
const CAPABILITY := {
	# Nuclear. SIPRI 2025: Russia 5,459 warheads, US 5,177, China 600, France 290,
	# UK 225, India 180, Pakistan 170, Israel 90, North Korea 50; all nine field
	# weapons for battlefield or "pre-strategic" use.
	"tacticalNuke": {"ids": ["usa", "russia", "china", "eu", "uk", "india", "pakistan", "israel", "north_korea"],
		"why": "all nine nuclear-armed states: US B61, Russia ~2,000 non-strategic warheads, Pakistan Nasr, North Korea Hwasan-31, France ASMPA, UK low-yield Trident"},
	"nuke": {"ids": ["usa", "russia", "china", "eu", "uk", "india", "pakistan", "israel", "north_korea"], "why": "the nine nuclear-armed states"},
	"hydrogenBomb": {"ids": ["usa", "russia", "china", "eu", "uk", "north_korea"],
		"why": "two-stage weapons tested by the US (1952), USSR (1955), UK (1957), China (1967), France (1968); North Korea's 2017 test (~250 kt) is judged likely thermonuclear. India's 1998 claim is disputed (12-25 kt measured); Israel's is unproven"},
	"tsarBomba": {"ids": ["russia"], "why": "the USSR's 50 Mt AN602, 30 October 1961"},
	"neutronBomb": {"ids": ["usa", "russia", "china", "eu"], "why": "US W70-3/W79 (retired 1992); the USSR, France (1980) and China (1988) tested enhanced-radiation designs"},
	"nuclearEmp": {"ids": ["usa", "russia", "china", "eu", "uk", "india", "pakistan", "israel", "north_korea"],
		"why": "any nuclear-armed state with a missile can burst a warhead at altitude; the EMP Commission named it in Russian, Chinese and North Korean doctrine"},
	"mirv": {"ids": ["usa", "russia", "china", "eu", "uk", "india", "pakistan"],
		"why": "deployed by the US (Trident II), Russia (Yars, Bulava, Sarmat), China (DF-41, DF-5B), the UK and France (M51); tested by India (Agni-V 'Divyastra', March 2024 and May 2026) and Pakistan (Ababeel)"},
	"nuclearGlide": {"ids": ["russia", "china"], "why": "Russia's Avangard (in service 2019); China's orbital glide vehicle test of August 2021 (a fractional orbital bombardment system)"},
	"burevestnik": {"ids": ["russia"], "why": "nuclear-powered cruise missile; Russia claimed a 14,000 km, 15-hour test on 21 October 2025"},
	"poseidon": {"ids": ["russia"], "why": "nuclear-powered, nuclear-armed torpedo launched from a submarine; Russia claimed its first powered test on 28 October 2025"},
	"nuclearAsat": {"ids": ["russia"], "why": "US intelligence (February 2024): Russia is developing a nuclear weapon for orbit; Cosmos 2553 (2022) tested its components"},
	# Electromagnetic.
	"emp": {"ids": ["usa", "china", "russia"], "why": "the US CHAMP (2012) and HiJENKS (2022) microwave missiles; Chinese and Russian high-power microwave programmes"},
	# Chemical. All declared stockpiles were destroyed by July 2023 (OPCW).
	"chemical": {"ids": ["russia", "north_korea", "egypt", "israel"],
		"why": "Russia (Novichok against Skripal 2018 and Navalny 2020; the US assesses an undeclared programme); North Korea (2,500-5,000 t incl. sarin and VX; outside the CWC); Egypt (outside the CWC, used mustard gas in Yemen in the 1960s); Israel (signed but never ratified the CWC; suspected)"},
	"riotAgent": {"ids": ["russia"], "why": "CS, CN and chloropicrin grenades dropped on Ukrainian trenches: more than 13,300 recorded uses by 2026; banned as a method of warfare by the CWC"},
	"incapacitant": {"ids": ["iran", "russia"], "why": "pharmaceutical-based agents: the US found Iran in violation of the CWC for them in 2024; Russia's Kolokol-1 fentanyl aerosol killed 130 hostages in Moscow in 2002"},
	"chlorine": {"rule": "anyone", "why": "a toxic industrial chemical any state can weaponise: Syria's former government dropped chlorine on its own towns (OPCW attributions 2014-2018); the most used chemical weapon of the past decade"},
	# Biological. No state admits a programme; the US compliance reports assess
	# offensive programmes in Russia and North Korea (concerns only for China and Iran).
	"anthrax": {"ids": ["russia", "north_korea"], "why": "spores for area denial: the Soviet Biopreparat programme (the 1979 Sverdlovsk leak killed about 66); US-assessed offensive programmes"},
	"bioweapon": {"ids": ["russia", "north_korea"], "why": "a contagious engineered disease (plague, smallpox): the same US-assessed offensive programmes"},
	# Radiological.
	"dirtyBomb": {"rule": "reactor", "why": "any state with radioactive material: here, any nation with a Nuclear Reactor. No state has ever used one"},
}

## Treaties, by faction id. npt: "nws" (a recognised weapon state), "party",
## "outside" (never joined), "withdrawn". cwc and bwc: "party", "signed"
## (not ratified), "none". icc: true for parties to the Rome Statute.
const TREATIES := {
	"usa": {"npt": "nws", "icc": false}, "russia": {"npt": "nws", "icc": false}, "china": {"npt": "nws", "icc": false},
	"eu": {"npt": "nws", "icc": true}, "uk": {"npt": "nws", "icc": true},
	"india": {"npt": "outside", "icc": false}, "pakistan": {"npt": "outside", "icc": false},
	"israel": {"npt": "outside", "cwc": "signed", "bwc": "none", "icc": false},
	"north_korea": {"npt": "withdrawn", "cwc": "none", "icc": false},
	"egypt": {"cwc": "none", "bwc": "signed", "icc": false}, "syria": {"bwc": "signed", "icc": false},
	"iran": {"icc": false}, "turkiye": {"icc": false}, "saudi": {"icc": false}, "indonesia": {"icc": false}, "iraq": {"icc": false},
	"japan": {"icc": true}, "south_korea": {"icc": true}, "brazil": {"icc": true}, "australia": {"icc": true},
	"ukraine": {"icc": true}, "afghanistan": {"icc": true},
}
## States that could build a bomb within a short time, and on what condition.
const THRESHOLD := {
	"iran": {"after": "", "why": "enriched uranium to 60% (over 400 kg before the strikes of June 2025)"},
	"saudi": {"after": "iran", "why": "its leaders have said it would match an Iranian bomb"},
}

static func ident(w: Node, owner: int) -> String:
	return Factions.identity(w, owner)

static func nation_dict(w: Node, owner: int) -> Dictionary:
	return w.map.nations[owner] if owner >= 0 and owner < w.map.nations.size() else {}

## Treaty status `field` of nation `owner` (with the defaults for a new nation).
static func treaty(w: Node, owner: int, field: String):
	var n := nation_dict(w, owner)
	if n.has(field):
		return n[field]
	var row: Dictionary = TREATIES.get(ident(w, owner), {})
	return row.get(field, {"npt": "party", "cwc": "party", "bwc": "party", "icc": false}.get(field, ""))

## The faction ids that have weapon `key` (no rule-based weapons).
static func ids_for(key: String) -> Array:
	return CAPABILITY.get(key, {}).get("ids", [])

## Faction ids -> arsenal ids (national_arsenal.identity: the original four are
## "blue", "red", "green", "gold"), for a missile's "nation" field.
static func arsenal_ids(ids: Array) -> Array:
	var out := []
	for id in ids:
		var i: int = Factions.IDS.find(id)
		out.append(Factions.ARSENALS[i] if i >= 0 else id)
	return out

## Whether nation `owner` has weapon `key` (data, its own fields, or a rule).
static func has(w: Node, owner: int, key: String) -> bool:
	var row: Dictionary = CAPABILITY.get(key, {})
	match str(row.get("rule", "")):
		"anyone":
			return true
		"reactor":
			return w.buildings.any(func(b): return int(b.owner) == owner and not b.dead and b.key == "nuclearReactor")
	var n := nation_dict(w, owner)
	if n.has("cbrn"):
		return key in n.cbrn
	if ident(w, owner) in row.get("ids", []):
		return true
	# A nuclear breakout gives the basic nuclear weapons (wmd.gd).
	return key in ["nuke", "tacticalNuke", "nuclearEmp"] and w.get("wmd") != null and w.wmd != null and owner in w.wmd.broken_out

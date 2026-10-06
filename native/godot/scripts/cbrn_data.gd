extends RefCounted
## National nuclear capabilities, assessed programmes and separate treaties.
## CAPABILITY lists eligibility; PROGRAMMES requires Future Arsenal research.
## Explicit scenario cbrn lists override evidence defaults. A reactor or treaty
## non-membership alone never grants a chemical/radiological arsenal. New
## countries default to no unconventional weapons and no assigned UN region.
## Evidence: native/ARSENAL-RESEARCH-2026-10-06.md.

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
	"neutronBomb": {"ids": ["usa", "russia", "china", "eu"], "why": "no one fields one today: the US retired the W70-3 and W79 in 1992; the USSR, France (1980) and China (1988) tested designs. A research programme to build them again"},
	"bunkerBuster": {"ids": ["usa"], "why": "the US B61-11 earth penetrator (~400 kt, kept in the stockpile) and the B61-13 (first unit May 2025) for hardened, deeply buried targets; Congress funded a new nuclear bunker-buster prototype in 2026"},
	"nuclearCruise": {"ids": ["usa", "russia", "eu", "pakistan", "israel"],
		"why": "air- and sea-launched nuclear cruise missiles: the US AGM-86B with the W80-1 (the LRSO to follow), Russia's Kh-102, France's ASMPA-R, Pakistan's Ra'ad and Babur, and the missiles Israel's Dolphin submarines are believed to carry"},
	"nuclearEmp": {"ids": ["usa", "russia", "china", "eu", "uk", "india", "pakistan", "israel", "north_korea"],
		"why": "any nuclear-armed state with a missile can burst a warhead at altitude; the EMP Commission named it in Russian, Chinese and North Korean doctrine"},
	"mirv": {"ids": ["usa", "russia", "china", "eu", "uk", "india", "pakistan"],
		"why": "deployed by the US (Trident II), Russia (Yars, Bulava, Sarmat), China (DF-41, DF-5B), the UK and France (M51); tested by India (Agni-V 'Divyastra', March 2024 and May 2026) and Pakistan (Ababeel)"},
	"nuclearGlide": {"ids": ["russia", "china"], "why": "Russia's Avangard (in service 2019); China's orbital glide vehicle test of August 2021 (a fractional orbital bombardment system)"},
	"burevestnik": {"ids": ["russia"], "why": "nuclear-powered cruise missile; Russia claimed a 14,000 km, 15-hour test on 21 October 2025"},
	"poseidon": {"ids": ["russia"], "why": "Russian development programme; North Korean Haeil claims do not establish a deployed equivalent"},
	"nuclearAsat": {"ids": ["russia"], "why": "US intelligence (February 2024): Russia is developing a nuclear weapon for orbit; Cosmos 2553 (2022) tested its components"},
	# Electromagnetic.
	"emp": {"ids": ["usa", "china", "russia"], "why": "the US CHAMP (2012) and HiJENKS (2022) microwave missiles; Chinese and Russian high-power microwave programmes"},
	# Chemical. All declared stockpiles were destroyed by July 2023 (OPCW).
	"chemical": {"ids": ["russia", "north_korea"],
		"why": "Russia (Novichok against Skripal 2018 and Navalny 2020; the US assesses an undeclared programme); North Korea (2,500-5,000 t incl. sarin and VX; outside the CWC); Egypt (outside the CWC, used mustard gas in Yemen in the 1960s); Israel (signed but never ratified the CWC; suspected)"},
	"riotAgent": {"ids": ["russia"], "why": "CS and CN riot-agent munitions; chloropicrin is a chemical warfare agent, not a riot agent dropped on Ukrainian trenches: more than 13,300 recorded uses by 2026; banned as a method of warfare by the CWC"},
	"incapacitant": {"ids": ["iran", "russia"], "why": "pharmaceutical-based agents: the US found Iran in violation of the CWC for them in 2024; Russia's Kolokol-1 fentanyl aerosol killed 130 hostages in Moscow in 2002"},
	"chlorine": {"ids": [], "why": "No default current missile inventory established. Treaty non-membership is not evidence of possession."},
	# Biological. No state admits a programme; the US compliance reports assess
	# offensive programmes in Russia and North Korea (concerns only for China and Iran).
	"anthrax": {"ids": ["russia", "north_korea"], "why": "spores for area denial: the Soviet Biopreparat programme (the 1979 Sverdlovsk leak killed about 66); US-assessed offensive programmes"},
	"bioweapon": {"ids": ["russia", "north_korea"], "why": "a contagious engineered disease (plague, smallpox): the same US-assessed offensive programmes"},
	# Radiological.
	"dirtyBomb": {"ids": [], "rule": "reactor", "why": "No verified national inventory. Explicit scenario capability and a reactor are both required."},
}

## Eligible future/historical/assessed programmes, NOT operational inventory.
const PROGRAMMES := {
	"tsarBomba": ["russia"], "neutronBomb": ["usa", "russia", "china", "eu"],
	"mirv": ["pakistan"], "nuclearGlide": ["china"],
	"nuclearCruise": ["israel"],
	"tacticalNuke": ["china", "india", "israel"],
	"burevestnik": ["russia"], "poseidon": ["russia"], "nuclearAsat": ["russia"],
	"emp": ["usa", "china", "russia"],
	"chemical": ["russia", "north_korea"], "incapacitant": ["iran", "russia"],
	"anthrax": ["russia", "north_korea"], "bioweapon": ["russia", "north_korea"],
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
## NATO nuclear sharing: US B61 bombs in a host's custody, released only by
## the United States (Kleine Brogel, Büchel, Aviano, Ghedi, Volkel, Incirlik,
## and Lakenheath/Marham again since 2025). A host may drop them while it is
## allied with the owner. (The EU and the UK have bombs of their own here.)
const SHARING := {"turkiye": "usa"}
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
	var n := nation_dict(w, owner)
	if str(row.get("rule", "")) == "reactor" and not w.buildings.any(func(b): return int(b.owner) == owner and b.built and not b.dead and b.key == "nuclearReactor"):
		return false
	if n.has("cbrn"):
		return key in n.cbrn
	if ident(w, owner) in row.get("ids", []):
		if ident(w, owner) in PROGRAMMES.get(key, []):
			return load("res://scripts/arsenal_catalog.gd").programme_done(w, owner)
		return true
	# Sharing does not transfer ownership or independent production/release.
	# A nuclear breakout gives the basic nuclear weapons (wmd.gd).
	return key in ["nuke", "tacticalNuke", "nuclearEmp"] and w.get("wmd") != null and w.wmd != null and owner in w.wmd.broken_out

static func blocked(w: Node, owner: int, key: String) -> String:
	if has(w, owner, key): return ""
	var n := nation_dict(w, owner)
	if n.has("cbrn") and key in n.cbrn and key == "dirtyBomb":
		return "Needs a Nuclear Reactor (radioactive material)"
	if not n.has("cbrn") and ident(w, owner) in PROGRAMMES.get(key, []):
		return "Needs Future Arsenal programme"
	return "Not fielded by this nation"

## Whether nation `owner` may build a Strategic Weapons Complex (nuclear) or a
## Special Weapons Laboratory (chemical, biological, radiological).
static func may_build(w: Node, owner: int, key: String) -> bool:
	match key:
		"strategicComplex":
			return has(w, owner, "nuke") or has(w, owner, "tacticalNuke")
		"specialLab":
			for k in ["chemical", "riotAgent", "incapacitant", "anthrax", "bioweapon"]:
				if has(w, owner, k):
					return true
			var n := nation_dict(w, owner)
			return (n.has("cbrn") and "dirtyBomb" in n.cbrn) or ident(w, owner) in PROGRAMMES.get("chemical", []) or ident(w, owner) in PROGRAMMES.get("incapacitant", [])
	return true

## Whether `owner` holds its tactical bombs only through nuclear sharing.
static func shared_only(w: Node, owner: int) -> bool:
	return SHARING.has(ident(w, owner)) and not ident(w, owner) in ids_for("tacticalNuke")

extends RefCounted
## Which nations really field each weapon, and what each calls its own (2025-26).
## The shared units keep their rules; a nation sees its own system's name
## (China's stealth fighter is the J-20, Russia's the Su-57), and a weapon no
## nation of that kind has is not open to it: no heavy bomber outside the three
## nations that fly them, no stealth fighter for Iran, no sixth-generation
## fighter outside the two nations flying one (the F-47 and the J-36; Europe's
## FCAS and the GCAP of Japan, Britain and Italy are left out as programmes
## that have collapsed), nuclear weapons only for the nuclear
## powers (and Israel, undeclared), missile defence and lasers not for Iran.
##
## Arsenal keys (national_arsenal.identity): blue United States, red China,
## green European Union, gold Iran, russia, india, japan, turkiye, israel.
##
## Sources, in brief: IISS Military Balance 2025; SIPRI nuclear forces 2025;
## the F-47 (USAF, March 2025) and J-36 (first flight December 2024); KAAN first flight
## February 2024; AMCA in development; Iron Beam operational 2025; DRDO's laser
## test April 2025; Japan's ship railgun trials (JS Asuka, 2023-25); Epirus
## Leonidas; China's railgun and XLUUV trials.

const ALL := ["blue", "red", "green", "gold", "russia", "india", "japan", "turkiye", "israel"]

## Who fields a shared unit (absent: every nation).
const ONLY := {
	"bomber": ["blue", "red", "russia"],
	"stealthFighter": ["blue", "red", "green", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "australia"],
	"sixthGen": ["blue", "red"],
	"wingman": ["blue", "red"],
	"nuclearSub": ["blue", "red", "green", "russia", "india", "uk"],
	"destroyer": ["blue", "red", "green", "gold", "russia", "india", "japan", "turkiye", "uk", "south_korea", "australia"],
	"laserAD": ["blue", "red", "green", "russia", "india", "japan", "turkiye", "israel"],
	"abmLauncher": ["blue", "red", "green", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "saudi"],
	"hpmVehicle": ["blue", "red", "japan"],
	"railgunShip": ["red", "japan"],
	"orca": ["blue", "red"],
}

## Who may research a discovery (absent: every nation).
const RESEARCH_ONLY := {
	"sixthGeneration": ["blue", "red"],
	"nuclearProgram": ["blue", "red", "green", "russia", "india", "israel", "uk", "north_korea", "pakistan"],
	"railguns": ["red", "japan"],
	"unmannedSubmarines": ["blue", "red"],
	"highPowerMicrowave": ["blue", "red", "japan"],
	"glidePhaseInterceptor": ["blue", "japan"],
	"directedEnergy": ["blue", "red", "green", "russia", "india", "japan", "turkiye", "israel"],
	"missileDefence": ["blue", "red", "green", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "saudi"],
	"activeProtection": ["blue", "red", "green", "russia", "turkiye", "israel"],
}

## Who may build a missile type (absent: every nation).
const MISSILE_ONLY := {
	"nuke": ["blue", "red", "green", "russia", "india", "israel", "uk", "north_korea", "pakistan"],
	"hypersonic": ["blue", "red", "russia", "india", "gold", "japan", "turkiye"],
}

## Shared units a nation does not field although most do (2026): Iraq, Syria
## and Afghanistan. Afghanistan is landlocked and has no air force but a few
## captured helicopters; the new Syrian army lost its jets, attack helicopters,
## navy and strategic air defence to the strikes of December 2024; Iraq has no
## submarines and no guided rocket artillery. See
## native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md. Saudi Arabia has never
## had a submarine, and Ukraine's last one was seized in Crimea in 2014
## (native/UNIT-QUALITY-RESEARCH-2026-10-03.md).
const EXCEPT := {
	"jet": ["syria", "afghanistan"],
	"gunship": ["syria", "afghanistan"],
	"gunboat": ["afghanistan"],
	"corvette": ["syria", "afghanistan"],
	"submarine": ["iraq", "syria", "afghanistan", "saudi", "ukraine"],
	"samLauncher": ["syria", "afghanistan"],
	"himars": ["iraq", "syria", "afghanistan"],
	"seaDrone": ["afghanistan"],
}
## Discoveries a nation does not pursue (2026).
const RESEARCH_EXCEPT := {
	"navalEngineering": ["afghanistan"],
	"ballisticTech": ["iraq", "syria", "afghanistan"],
	"stealthTech": ["iraq", "syria", "afghanistan"],
	"satelliteRecon": ["syria", "afghanistan"],
}
## Buildings a nation does not put up: no nuclear reactor for Iraq (Osirak,
## 1981), Syria (al-Kibar, 2007) or Afghanistan; no missile silo for any of
## the three; no naval shipyard for landlocked Afghanistan.
const BUILD_EXCEPT := {
	"nuclearReactor": ["iraq", "syria", "afghanistan"],
	"missileSilo": ["iraq", "syria", "afghanistan"],
	"shipyard": ["afghanistan"],
}

## Each nation's own system for a shared unit.
const NAMES := {
	"tank": {"iraq": "M1A1M Abrams", "syria": "T-72", "afghanistan": "T-62 (captured)", "blue": "M1A2 SEPv3 Abrams", "red": "Type 99A", "green": "Leopard 2A8", "gold": "Karrar", "russia": "T-90M Proryv", "india": "Arjun Mk1A", "japan": "Type 10", "turkiye": "Altay", "israel": "Merkava Mk 4", "uk": "Challenger 2", "south_korea": "K2 Black Panther", "saudi": "M1A2S Abrams", "brazil": "Leopard 1A5BR", "indonesia": "Leopard 2A4", "ukraine": "T-64BV", "north_korea": "Chonma-216", "egypt": "M1A1 Abrams", "australia": "M1A2 SEPv3 Abrams", "pakistan": "VT-4 Haider"},
	"apc": {"afghanistan": "Humvee (captured)", "blue": "Stryker", "red": "ZBL-08", "green": "Boxer", "gold": "Rakhsh", "russia": "BTR-82A", "india": "WhAP", "japan": "Type 96 APC", "turkiye": "Pars", "israel": "Eitan", "uk": "Boxer", "south_korea": "K21", "saudi": "LAV 700", "brazil": "VBTP Guarani", "indonesia": "Anoa", "ukraine": "BTR-4", "north_korea": "M-2010", "egypt": "M113 / Fahd", "australia": "Boxer CRV", "pakistan": "Saad / M113", "iraq": "BTR-4 / M113", "syria": "BMP-1"},
	"artillery": {"blue": "M109A7 Paladin", "red": "PLZ-05", "green": "PzH 2000", "gold": "Raad-2", "russia": "2S19 Msta-S", "india": "K9 Vajra-T", "japan": "Type 99 SPH", "turkiye": "T-155 Firtina", "israel": "Roem", "uk": "AS-90 / Archer", "south_korea": "K9A1 Thunder", "saudi": "CAESAR", "brazil": "M109A5+ BR", "indonesia": "CAESAR", "ukraine": "2S3 / PzH 2000 / Krab", "north_korea": "M1989 Koksan", "egypt": "M109A5", "australia": "AS9 Huntsman", "pakistan": "M109A5 / SH-15", "iraq": "M109A5", "syria": "2S1 Gvozdika / D-30", "afghanistan": "D-30 (towed)"},
	"mlrs": {"iraq": "BM-21 Grad", "syria": "BM-21 Grad", "afghanistan": "BM-21 Grad", "blue": "M270 MLRS", "red": "PHL-03", "green": "MARS II", "gold": "Fajr-5", "russia": "BM-30 Smerch", "india": "Pinaka", "japan": "M270 (JGSDF)", "turkiye": "T-122 Sakarya", "israel": "Lynx", "uk": "M270A2 MLRS", "south_korea": "K239 Chunmoo", "saudi": "ASTROS II", "brazil": "ASTROS II Mk6", "indonesia": "ASTROS II / RM-70", "ukraine": "BM-27 / HIMARS", "north_korea": "KN-25 / M1991", "egypt": "BM-21 Sakr", "australia": "M142 HIMARS", "pakistan": "A-100 / Fatah-1"},
	"himars": {"blue": "HIMARS", "red": "PCH-191", "green": "EuroPULS", "gold": "Fath-360 launcher", "russia": "Tornado-S", "india": "Guided Pinaka", "japan": "M270 GMLRS", "turkiye": "TRLG-230", "israel": "PULS"},
	"aaVehicle": {"iraq": "Pantsir-S1", "syria": "35 mm air defence gun", "afghanistan": "ZU-23-2", "blue": "M-SHORAD", "red": "PGZ-09", "green": "Skyranger 30", "gold": "ZSU-23-4 Shilka", "russia": "Pantsir-S1", "india": "2K22 Tunguska", "japan": "Type 87 SPAAG", "turkiye": "Korkut", "israel": "Iron Dome battery", "uk": "Stormer HVM", "south_korea": "K30 Biho II", "saudi": "Avenger / Shahine", "brazil": "Gepard 1A2", "indonesia": "Skyshield / RBS 70", "ukraine": "Gepard / Strela-10", "north_korea": "M1992 30 mm", "egypt": "Avenger / Sinai-23", "australia": "RBS 70 (vehicle)", "pakistan": "LY-80 / Oerlikon"},
	"samLauncher": {"iraq": "Cheongung II (KM-SAM)", "blue": "Patriot PAC-3", "red": "HQ-9B", "green": "SAMP/T NG", "gold": "Bavar-373", "russia": "S-400", "india": "Akash-NG", "japan": "Type 03 Chu-SAM", "turkiye": "Hisar-O", "israel": "David's Sling", "uk": "Sky Sabre (CAMM)", "south_korea": "Cheongung II", "saudi": "Patriot PAC-3", "brazil": "RBS 70 NG battery", "indonesia": "NASAMS", "ukraine": "Patriot / IRIS-T / NASAMS", "north_korea": "KN-06 (Pongae-5)", "egypt": "S-300VM / IRIS-T SLM", "australia": "NASAMS", "pakistan": "HQ-9/P"},
	"helicopter": {"iraq": "Mi-17", "syria": "Mi-17", "afghanistan": "UH-60 (captured)", "blue": "UH-60M Black Hawk", "red": "Z-20", "green": "NH90", "gold": "Shabaviz 2-75", "russia": "Mi-8AMTSh", "india": "Dhruv ALH", "japan": "UH-60JA", "turkiye": "T70 Black Hawk", "israel": "UH-60 Yanshuf", "uk": "Merlin HC4", "south_korea": "KUH-1 Surion", "saudi": "UH-60M", "brazil": "H225M", "indonesia": "Bell 412EPI", "ukraine": "Mi-8", "north_korea": "Mi-8", "egypt": "UH-60 / Mi-17", "australia": "UH-60M", "pakistan": "Mi-17"},
	"gunship": {"iraq": "Mi-28NE", "blue": "AH-64E Apache", "red": "Z-10ME", "green": "Tiger", "gold": "Toufan", "russia": "Ka-52M", "india": "LCH Prachand", "japan": "AH-64DJP", "turkiye": "T129 ATAK", "israel": "AH-64 Saraf", "uk": "AH-64E Apache", "south_korea": "AH-64E Apache", "saudi": "AH-64E Apache", "brazil": "AH-2 Sabre (Mi-35)", "indonesia": "AH-64E Apache", "ukraine": "Mi-24", "north_korea": "Mi-24", "egypt": "AH-64D / Ka-52", "australia": "AH-64E Apache", "pakistan": "AH-1F Cobra / Z-10ME"},
	"jet": {"iraq": "F-16IQ Fighting Falcon", "blue": "F-15EX Eagle II", "red": "J-16", "green": "Rafale / Typhoon", "gold": "MiG-29", "russia": "Su-35S", "india": "Su-30MKI", "japan": "F-15J", "turkiye": "F-16 Block 50", "israel": "F-15I Ra'am", "uk": "Typhoon FGR4", "south_korea": "KF-21 Boramae / F-15K", "saudi": "F-15SA", "brazil": "Gripen E", "indonesia": "F-16 Block 52ID", "ukraine": "F-16 / MiG-29", "north_korea": "MiG-29 / MiG-21", "egypt": "Rafale / F-16", "australia": "F/A-18F Super Hornet", "pakistan": "JF-17 Block III / F-16"},
	"bomber": {"blue": "B-52H Stratofortress", "red": "H-6K", "russia": "Tu-160M"},
	"drone": {"iraq": "CH-4B", "blue": "MQ-9 Reaper", "red": "Wing Loong II", "green": "Heron TP", "gold": "Mohajer-6", "russia": "Orion", "india": "TAPAS-BH", "japan": "MQ-9B SeaGuardian", "turkiye": "Bayraktar TB2", "israel": "Hermes 900", "uk": "MQ-9B Protector", "south_korea": "KUS-FS", "saudi": "Wing Loong II / Akinci", "brazil": "Hermes 900", "indonesia": "CH-4B / Anka", "ukraine": "Bayraktar TB2 / domestic", "north_korea": "Saetbyol-4/9", "egypt": "Wing Loong I / CH-4", "australia": "MQ-9B", "pakistan": "Shahpar III / Burraq", "syria": "Shaheen", "afghanistan": "Taliban-built drone"},
	"corvette": {"blue": "Freedom-class LCS", "red": "Type 056A", "green": "K130 Braunschweig", "gold": "Shahid Soleimani-class", "russia": "Karakurt-class", "india": "Kamorta-class", "japan": "Mogami-class", "turkiye": "Ada-class", "israel": "Sa'ar 6", "uk": "Type 31 / River OPV", "south_korea": "Daegu-class", "saudi": "Al Jubail-class", "brazil": "Tamandare-class", "indonesia": "Martadinata-class", "ukraine": "Island-class patrol boat", "north_korea": "Amnok-class", "egypt": "Gowind 2500", "australia": "Anzac-class", "pakistan": "Babur-class (MILGEM)", "iraq": "Musa Ben Nussair-class"},
	"destroyer": {"uk": "Type 45", "south_korea": "Sejong the Great-class", "australia": "Hobart-class", "blue": "Arleigh Burke-class", "red": "Type 055", "green": "Horizon-class", "gold": "Moudge-class", "russia": "Admiral Gorshkov-class", "india": "Visakhapatnam-class", "japan": "Maya-class", "turkiye": "Istanbul-class"},
	"submarine": {"blue": "Virginia-class", "red": "Type 039C", "green": "Type 212CD", "gold": "Fateh-class", "russia": "Improved Kilo", "india": "Kalvari-class", "japan": "Taigei-class", "turkiye": "Reis-class", "israel": "Dolphin II", "uk": "Astute-class", "south_korea": "Dosan Ahn Changho-class", "brazil": "Riachuelo-class", "indonesia": "Nagapasa-class", "north_korea": "Romeo-class", "egypt": "Type 209/1400", "australia": "Collins-class", "pakistan": "Agosta 90B"},
	"nuclearSub": {"uk": "Vanguard-class", "blue": "Ohio-class", "red": "Type 094", "green": "Triomphant-class", "russia": "Borei-A", "india": "Arihant-class"},
	"stealthFighter": {"uk": "F-35B Lightning", "south_korea": "F-35A", "australia": "F-35A", "blue": "F-35A Lightning II", "red": "J-20", "green": "F-35A", "russia": "Su-57", "india": "AMCA", "japan": "F-35A", "turkiye": "KAAN", "israel": "F-35I Adir"},
	"sixthGen": {"blue": "F-47", "red": "J-36"},
	"wingman": {"blue": "YFQ-42A CCA", "red": "FH-97A"},
	"atgmTeam": {"blue": "Javelin team", "red": "HJ-12 team", "green": "MMP team", "gold": "Dehlavieh team", "russia": "Kornet team", "india": "MPATGM team", "japan": "Type 01 LMAT team", "turkiye": "OMTAS team", "israel": "Spike team", "uk": "Javelin / NLAW team", "south_korea": "Raybolt team", "saudi": "TOW-2 / Javelin team", "brazil": "MSS-1.2 team", "indonesia": "Javelin team", "ukraine": "Stugna-P / Javelin team", "north_korea": "Bulsae-4 team", "egypt": "TOW / Kornet team", "australia": "Javelin team", "pakistan": "Baktar-Shikan team", "iraq": "Kornet team", "syria": "Kornet team", "afghanistan": "RPG-29 team"},
	"manpads": {"blue": "Stinger team", "red": "FN-16 team", "green": "Mistral 3 team", "gold": "Misagh-3 team", "russia": "Verba team", "india": "VSHORADS team", "japan": "Type 91 Kin-SAM team", "turkiye": "Sungur team", "israel": "Stinger team", "uk": "Starstreak / Martlet team", "south_korea": "Chiron team", "saudi": "Stinger / Mistral team", "brazil": "RBS 70 NG / Igla-S team", "indonesia": "QW-3 / Mistral team", "ukraine": "Stinger / Piorun team", "north_korea": "HT-16PGJ team", "egypt": "Ain Sakr / Stinger team", "australia": "RBS 70 team", "pakistan": "Anza Mk-III team", "iraq": "Igla team", "syria": "Igla / Strela team", "afghanistan": "Strela-2 team"},
	"loiterer": {"blue": "Switchblade 600", "red": "CH-901", "green": "HX-2", "gold": "Arash", "russia": "Lancet-3", "india": "Nagastra-1", "japan": "Loitering munition", "turkiye": "Kargu-2", "israel": "Hero-120"},
	"ewVehicle": {"russia": "Krasukha-4", "red": "Type 2 EW truck", "turkiye": "KORAL", "israel": "Elbit EW truck"},
	"laserAD": {"blue": "DE M-SHORAD", "red": "Silent Hunter", "green": "Rheinmetall HEL", "russia": "Zadira", "india": "DRDO Mk-II(A) laser", "japan": "ATLA high-energy laser", "turkiye": "ALKA", "israel": "Iron Beam"},
	"abmLauncher": {"blue": "THAAD", "red": "HQ-19", "green": "SAMP/T NG (Aster 30 B1NT)", "russia": "S-500", "india": "PDV / AAD", "japan": "SM-3 / PAC-3 MSE", "turkiye": "SIPER", "israel": "Arrow 3"},
	"hpmVehicle": {"blue": "Leonidas", "red": "Hurricane 3000", "japan": "ATLA microwave weapon"},
	"railgunShip": {"red": "Railgun ship (trials)", "japan": "JS Asuka railgun"},
	"orca": {"blue": "Orca XLUUV", "red": "AJX002"},
	# Russia builds the Shahed-136 at Alabuga as the Geran-2 (some 70,000 long-range drones planned for 2025).
	"shahedLauncher": {"russia": "Geran-2 Launcher"},
	"shahed": {"russia": "Geran-2"},
}

## The kind of unit, where the shared name was one nation's system.
const GENERIC := {"himars": "Guided Rocket Launcher", "sixthGen": "Sixth-Generation Fighter"}

## Descriptions without another nation's systems in them.
const DESCS := {
	"atgmTeam": "Fire-and-forget anti-tank missiles that dive onto a tank's thin roof. Active protection can stop them.",
	"manpads": "Shoulder-launched missiles: infantry that can shoot down helicopters, drones and low jets.",
	"himars": "Wheeled launcher firing pairs of GPS-guided rockets four hexes: precise, deadly to buildings and depots. Shoot and move.",
	"laserAD": "A 100 kW laser: burns drones out of the sky for the price of electricity, hurts aircraft, and stops half the cruise missiles in reach.",
	"abmLauncher": "Ballistic missile defence interceptors: 86% against a ballistic missile, 30% against a hypersonic one, 55% against an ICBM, out to 230 m.",
	"loiterer": "A loitering munition: circles over the front, then dives into its target and explodes. One use. Jammers bring most of them down.",
	"stealthFighter": "Fifth-generation stealth fighter: air defence and enemy fighters only see it at 40% of their range.",
	"seaDrone": "An unmanned explosive boat: fast and low, it rams a warship or a harbour and blows up. One use. Jammers stop most of them.",
	"hpmVehicle": "High-power microwave: every 6 s one pulse destroys every enemy drone within 45 m (Shaheds, loitering munitions, sea drones).",
	"orca": "Extra-large uncrewed submarine: cheap and quiet, it torpedoes ships, and enemies find it only at half their range.",
	"sixthGen": "The next generation: the stealthiest fighter (seen at a fifth of the range), and it takes off with two loyal wingman drones.",
}
const RESEARCH_DESCS := {
	"activeProtection": "Radar and interceptors on your armoured vehicles: half the missiles, rockets and kamikaze drones fired at them are blown up before they hit.",
	"missileDefence": "Unlocks the Missile Defence Battery and gives every air defence +10% to intercept missiles.",
}

## Applies the table to this match's unit, research and missile rules (after
## every arsenal is loaded, before research and missiles are set up).
static func apply(w: Node) -> void:
	var me: String = preload("res://scripts/national_arsenal.gd").identity(w, 0)
	for key in ONLY:
		if w.unit_defs.has(key) and str(w.unit_defs[key].get("nation", "")) == "":
			w.unit_defs[key].nation = ONLY[key].duplicate()
	# A shared unit three nations lack: every other nation fields it.
	var everyone: Array = preload("res://scripts/factions.gd").ARSENALS
	for key in EXCEPT:
		if w.unit_defs.has(key) and str(w.unit_defs[key].get("nation", "")) == "":
			w.unit_defs[key].nation = everyone.filter(func(id): return not id in EXCEPT[key])
	for key in DESCS:
		if w.unit_defs.has(key):
			w.unit_defs[key].desc = DESCS[key]
	for key in NAMES:
		if w.unit_defs.has(key) and NAMES[key].has(me):
			w.unit_defs[key].generic = GENERIC.get(key, w.unit_defs[key].get("generic", w.unit_defs[key].name))
			w.unit_defs[key].name = NAMES[key][me]
			# The kind of unit stays plain: "Tank. Heavy armor, heavy punch."
			w.unit_defs[key].desc = "%s. %s" % [w.unit_defs[key].generic, w.unit_defs[key].get("desc", "")]
	var discoveries: Dictionary = w.map.research.discoveries
	for key in RESEARCH_ONLY:
		if discoveries.has(key) and str(discoveries[key].get("nation", "")) == "":
			discoveries[key].nation = RESEARCH_ONLY[key].duplicate()
	for key in RESEARCH_EXCEPT:
		if discoveries.has(key) and str(discoveries[key].get("nation", "")) == "":
			discoveries[key].nation = everyone.filter(func(id): return not id in RESEARCH_EXCEPT[key])
	for key in RESEARCH_DESCS:
		if discoveries.has(key):
			discoveries[key].desc = RESEARCH_DESCS[key]
	for key in MISSILE_ONLY:
		if w.map.missiles.get("types", {}).has(key):
			w.map.missiles.types[key].nation = MISSILE_ONLY[key].duplicate()

## Whether nation `owner` may put up building `key`.
static func builds(w: Node, owner: int, key: String) -> bool:
	return not preload("res://scripts/national_arsenal.gd").identity(w, owner) in BUILD_EXCEPT.get(key, [])

## Whether a nation field ("" / a key / a list of keys) admits nation `id`.
static func admits(field, id: String) -> bool:
	if field is Array:
		return id in field
	return str(field) == "" or str(field) == id

## Unit `key` as nation `owner` calls it.
static func name_for(w: Node, owner: int, key: String) -> String:
	var id: String = preload("res://scripts/national_arsenal.gd").identity(w, owner)
	var up: Dictionary = preload("res://scripts/unit_quality.gd").upgrade(w, owner, preload("res://scripts/factions.gd").identity(w, owner), key)
	if not up.is_empty():
		return str(up.name)   # its successor, once researched (the M1E3 Abrams)
	if NAMES.has(key) and NAMES[key].has(id):
		return NAMES[key][id]
	var def: Dictionary = w.unit_defs.get(key, {})
	return str(def.get("generic", def.get("name", key)))

## Stand-ins in a starting army for units the chosen nation does not field.
const STAND_IN := {"bomber": "jet", "nuclearSub": "submarine", "destroyer": "corvette", "stealthFighter": "jet", "sixthGen": "jet"}

## Swaps the player's starting units its nation does not have (match_setup):
## a stand-in it does field, else a drone for an aircraft and nothing for a
## warship (landlocked Afghanistan has no navy at all).
static func fix_start(data: Dictionary, arsenal: String) -> void:
	var kept := []
	for u in data.units:
		if int(u.owner) == 0:
			var guard := 0
			while not fields(u.key, arsenal) and guard < 4:
				guard += 1
				var naval: bool = u.key in ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
				var air: bool = u.key in ["jet", "bomber", "stealthFighter", "sixthGen", "gunship"]
				u.key = STAND_IN.get(u.key, "drone" if air else ("gunboat" if naval else "tank"))
			if not fields(u.key, arsenal):
				continue   # (a warship for a nation without a navy)
		kept.append(u)
	data.units = kept

## Whether nation `arsenal` fields shared unit `key` (ONLY and EXCEPT).
static func fields(key: String, arsenal: String) -> bool:
	if ONLY.has(key) and not arsenal in ONLY[key]:
		return false
	return not arsenal in EXCEPT.get(key, [])

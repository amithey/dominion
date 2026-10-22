extends RefCounted
## Italy. Registered in nation_registry.gd; its position there is its saved index.
## Took the rows the Union held for it: native/EU-SPLIT-LEDGER.md.
const DATA := {
	"id": "italy",
	"group": "expansion",
	"arsenal": "italy",
	"name": "Italy",
	"leader": "Prime Minister Giorgia Meloni",
	"colour": "#5f9e7e",
	"portrait": "meloni",
	"signature": "Cavour",
	"doctrine": "The Mediterranean bridge: energy and investment deals with its southern neighbours, a carrier of its own and shipyards that build for others. Almost no oil or gas at home, a public debt above 130% of output and a population that shrinks faster than any other in the region.",
	# Income: GDP a head near $40,000 is three times the world's level: +5% on the table's scale (15 points a
	# tenfold, rounded to 5). Research +5% (a good output of articles, a low research budget). Oil and gas:
	# little is produced at home (-60%). Growth 0.6: the lowest births in the region. Combat damage -3%: a
	# long spell of low spending. Warships 5% cheaper: the yards that build for the navy and for others.
	"profile": {"bonus": {"incomePct": 0.05, "researchPct": 0.05, "dmgAll": -0.03}, "growth": 0.6, "resources": {"oil": 0.4, "gas": 0.4}, "trade": 1.1, "costs": {"naval": 0.95},
		"strengths": ["Income +5%, research +5%, trade income +10%", "Warships 5% cheaper: the yards build for others too", "The Mattei Plan: energy deals with partners"],
		"weaknesses": ["Little oil or gas of its own: output -60%", "A shrinking population: it grows 40% slower", "Low readiness after years of low spending: -3% combat damage"]},
	"power": {"name": "Energy Partnership", "target": true, "hostile": false, "cooldown": 360.0, "duration": 0.0, "costs": {"money": 500}, "needs": [],
		"desc": "$500: Italy invests in a partner's energy sector, in the way of its Mattei Plan. The partner receives the $500 and relations rise 15; the new contracts bring Italy 150 oil and 150 gas. Needs a partner at peace (+10 relations or better)."},
	"ai": {"compute": 2, "models": 1, "autonomy": 1, "cyber": 2, "lean": "in", "signs": ["laws"], "ceiling": 3,
		"why": "A top-ten European supercomputer and a national AI strategy, but a small model industry."},
	"ai_evidence": ["National strategy and a supercomputer", "A national AI strategy and the Leonardo supercomputer support research; defence use is mostly the purchase of allied systems.", ["industry", "administration", "health", "sensors"]],
	"ai_use": {
		"surveillance": ["barred", "A national moratorium on facial recognition in public places and the EU AI Act both bar it."],
		"revenue": ["fielded", "The tax agency mines data to find evasion."]},
	"dossier": {
		"profile": {"land": "Ariete tanks, Dardo and Freccia infantry vehicles and Centauro II wheeled tank destroyers form a compact mechanised force; the Panther and Lynx vehicles are programmes, not fleets.", "air": "Eurofighter and the F-35A and F-35B form the front line, with G550 aircraft for airborne warning and Tornado kept for electronic combat until it is retired.", "sea": "The Cavour carrier and the Trieste assault ship, FREMM frigates, Horizon destroyers and Todaro submarines give a navy built for the Mediterranean.", "fires": "PzH 2000 howitzers and M270 rockets are the artillery; SAMP/T and Aster missiles give layered air defence.", "support": "Allied bases on its soil and a large shipbuilding industry support the fleet, but spares and ammunition stocks are the central uncertainty.", "limits": "Public sources show the types in service, not stocks or readiness, and an order is not a delivered unit; Italy has no nuclear weapons of its own.", "watch": ["The GCAP fighter and the Panther and Lynx vehicle programmes, and the Tornado's retirement date: timing remains uncertain"], "sources": ["sipri"]},
		"sources": {},
		"roster": {},
	},
	"force_names": {
		"carrier": "Cavour",
		"asFrigate": "FREMM",
		"ewJet": "Tornado ECR",
		"aewc": "G550 CAEW",
		"maritimePatrol": "P-72A",
		"landingShip": "San Giorgio-class",
		"navalHelicopter": "NH90 NFH",
		"heavyLift": "CH-47F Chinook",
		"ifv": "Dardo IFV",
		"reconVehicle": "Centauro II",
	},
	"capabilities": {
		"units": ["stealthFighter", "sixthGen", "destroyer", "abmLauncher"],
		"research": ["sixthGeneration", "missileDefence"],
		"names": {
			"tank": "Ariete", "apc": "VBM Freccia", "artillery": "PzH 2000", "mlrs": "M270 MLRS", "aaVehicle": "SIDAM 25", "samLauncher": "SAMP/T NG",
			"helicopter": "NH90", "gunship": "AW129 Mangusta", "jet": "Eurofighter Typhoon", "drone": "MQ-9A Reaper", "corvette": "Minerva-class",
			"destroyer": "Horizon-class", "submarine": "Todaro-class (Type 212A)", "stealthFighter": "F-35A", "atgmTeam": "Spike LR team",
			"manpads": "Stinger team", "abmLauncher": "SAMP/T NG (Aster 30 B1NT)", "sixthGen": "GCAP programme",
		},
	},
}

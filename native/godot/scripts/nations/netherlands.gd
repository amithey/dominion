extends RefCounted
## The Netherlands. Registered in nation_registry.gd; its position there is its saved index.
## Took the rows the Union held for it: native/EU-SPLIT-LEDGER.md.
const DATA := {
	"id": "netherlands",
	"group": "expansion",
	"arsenal": "netherlands",
	"name": "Netherlands",
	"leader": "Prime Minister Rob Jetten",
	"colour": "#d98c5f",
	"portrait": "jetten",
	"signature": "Chip Equipment Embargo",
	"doctrine": "The trading hub: Europe's largest port, the machines that make the world's advanced chips, and a small, well-equipped army folded into its neighbours'. Little land and little oil or gas of its own, and a minority government.",
	# Income: GDP a head near $65,000 is nearly five times the world's level: +10% on the table's scale (15 points
	# a tenfold, rounded to 5). Research +15%: among the highest outputs of scientific articles a million people
	# (not re-checked this round, see the ledger). Trade 1.2: Rotterdam and Schiphol. Ports 15% cheaper. Oil and gas:
	# the big Groningen field is closed (-70% and -60%). Growth 0.75. Civilian capacity -15%: little land.
	"profile": {"bonus": {"incomePct": 0.10, "researchPct": 0.15, "civCapPct": -0.15, "dmgAll": -0.03}, "growth": 0.75, "resources": {"oil": 0.3, "gas": 0.4}, "trade": 1.2, "build_costs": {"port": 0.85},
		"strengths": ["Income +10%, research +15%, trade income +20%", "Ports cost 15% less: Rotterdam and Schiphol", "Chip Equipment Embargo: withholds the tools that make advanced chips"],
		"weaknesses": ["Little land: civilian capacity -15%", "Oil and gas output -70% and -60% since the big field closed", "A small army: -3% combat damage"]},
	"power": {"name": "Chip Equipment Embargo", "target": true, "hostile": true, "cooldown": 360.0, "duration": 120.0, "costs": {"money": 400}, "needs": [],
		"desc": "$400: the Netherlands withholds the lithography and chip tools its firms make. The target's military factories stand still for 60 seconds and its income falls 10% for 2 minutes. Relations with it fall 12. Not on an ally."},
	"ai": {"compute": 2, "models": 2, "autonomy": 1, "cyber": 3, "lean": "in", "signs": ["laws"], "ceiling": 3,
		"why": "Makes the machines that make the world's advanced chips, but has little frontier compute of its own."},
	"ai_evidence": ["Chip tools and a hosting hub", "A Dutch firm builds the machines that make advanced chips and Amsterdam is a data-centre hub; defence AI is mostly adopted from allies.", ["industry", "sensors", "cyber", "administration"]],
	"ai_use": {
		"surveillance": ["barred", "The EU AI Act forbids real-time facial recognition in public spaces, with narrow judicial exceptions."],
		"revenue": ["fielded", "The tax authority scored families with a risk algorithm that wrongly flagged thousands, and the scandal brought down a government."]},
	"dossier": {
		"profile": {"land": "Leopard 2, CV90, Boxer and PzH 2000 form a small mechanised army folded into Germany's; Fennek vehicles still scout for it. The numbers in service are not modelled.", "air": "The F-35A is the front-line combat aircraft, with Apache attack helicopters and Reaper drones beside it; the F-16 has gone.", "sea": "De Zeven Provincien frigates, which can also watch for ballistic missiles, Rotterdam-class assault ships and Walrus submarines make a small, modern fleet built to work with allies.", "fires": "PzH 2000 howitzers, Patriot batteries and new PULS rocket launchers and Skyranger air defence are the fires; some are orders, not deliveries.", "support": "The port of Rotterdam and Schiphol are the gateways for reinforcements into Europe, but ammunition and spares stocks are the central uncertainty.", "limits": "Public sources show the types in service or ordered, not stocks or readiness, and an order is not a delivered unit; the Netherlands has no nuclear weapons of its own.", "watch": ["The replacement of the Fennek and the Walrus submarines, and the PULS and Skyranger deliveries: timing remains uncertain"], "sources": ["sipri"]},
		"sources": {},
		"roster": {},
	},
	"force_names": {
		"reconVehicle": "Fennek",
		"asFrigate": "De Zeven Provincien-class",
		"landingShip": "Rotterdam-class",
		"navalHelicopter": "NH90 NFH",
		"heavyLift": "CH-47F Chinook",
		"ifv": "CV9035NL",
	},
	"capabilities": {
		"units": ["stealthFighter", "destroyer", "abmLauncher"],
		"research": ["missileDefence"],
		"names": {
			"tank": "Leopard 2A6", "apc": "Boxer", "artillery": "PzH 2000", "mlrs": "PULS", "aaVehicle": "Skyranger 30", "samLauncher": "Patriot PAC-3",
			"helicopter": "NH90", "gunship": "AH-64E Apache", "jet": "F-35A", "drone": "MQ-9A Reaper", "corvette": "Holland-class",
			"destroyer": "De Zeven Provincien-class", "submarine": "Walrus-class", "stealthFighter": "F-35A", "atgmTeam": "Javelin team",
			"manpads": "Stinger team", "abmLauncher": "Patriot PAC-3",
		},
	},
}

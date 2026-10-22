extends RefCounted
## Germany. Registered in nation_registry.gd at the index the European Union held, so saves keep their nation.
## The Union's other members take the rows that were theirs: native/EU-SPLIT-LEDGER.md.
const DATA := {
	"id": "germany",
	"group": "core",
	"arsenal": "green",
	"name": "Germany",
	"leader": "Chancellor Friedrich Merz",
	"colour": "#33b86e",
	"portrait": "merz",
	"signature": "IRIS-T SLM",
	"doctrine": "Layered defence: exclusive IRIS-T SLM air defence. It protects an army from aircraft but cannot fight ground targets. An industrial exporter with no nuclear weapons of its own, short of oil and gas, and slow to rearm.",
	# Income: GDP a head above $55,000 puts it in the United Kingdom's tier (+10%). Research +10%: a large
	# research budget. Oil and gas: almost none is produced at home (-70%). Growth 0.65: births far below
	# replacement. Combat damage -4%: years of low spending, now rising (figures to check, see the ledger).
	"profile": {"bonus": {"incomePct": 0.10, "researchPct": 0.10, "happiness": 3.0, "health": 5.0, "dmgAll": -0.04}, "growth": 0.65, "resources": {"oil": 0.3, "gas": 0.3}, "trade": 1.15, "costs": {"airDefence": 0.9},
		"strengths": ["Income +10%, research +10%, trade income +15%", "Welfare and health: +3 happiness, +5 health", "Air defence 10% cheaper (IRIS-T, Patriot)"],
		"weaknesses": ["Imported energy: oil and gas output -70%", "Low readiness after years of low spending: -4% combat damage", "An ageing population: the population grows a third slower"]},
	"ai": {"compute": 2, "models": 3, "autonomy": 2, "cyber": 3, "lean": "in", "signs": ["laws"], "ceiling": 4,
		"why": "Strong research and a new national supercomputer, but few frontier laboratories."},
	"ai_evidence": ["Deployment and infrastructure", "Public AI infrastructure and defence start-ups supply the armed forces; orders for AI-enabled systems do not prove fielding at scale.", ["assurance", "administration", "industry", "diplomacy"]],
	"ai_use": {
		"targeting": ["developing", "NATO bought a commercial targeting decision-support system for allied headquarters."],
		"counterDrone": ["developing", "National counter-drone programmes after drones overflew bases and ports."],
		"undersea": ["developing", "Seabed infrastructure protection with uncrewed vessels and sensors."],
		"surveillance": ["barred", "The EU AI Act forbids real-time facial recognition in public spaces, with narrow judicial exceptions."],
		"infoShield": ["fielded", "Federal agencies track foreign manipulation, and the Digital Services Act obliges platforms to act."],
		"revenue": ["fielded", "Tax administrations use analytics against VAT fraud."],
		"export": ["developing", "AI factories open to partners; no package export programme."],
		"biosecurity": ["developing", "Research and guidance on screening synthetic DNA."]},
	"dossier": {
		"profile": {"land": "Leopard 2, Puma and Boxer give heavy armour and mechanised infantry, with Fennek for reconnaissance; the numbers in service are not modelled.", "air": "Eurofighter and the F-35A cover multirole and strike roles, with Tornado kept for ground attack and electronic combat until it is replaced.", "sea": "Frigates of the F125 and F124 classes and Type 212 submarines suit the Baltic and North Sea; the game does not credit blue-water reach.", "fires": "PzH 2000 howitzers and MARS II rockets are the artillery; IRIS-T SLM, Patriot and Skyranger are separate air-defence layers.", "support": "Spares, ammunition stocks and maintenance contracts are the central uncertainty; the game abstracts them into resources and research.", "limits": "Public sources show types ordered or in service, not stocks or readiness, and an order is not a delivered unit; Germany has no nuclear weapons of its own.", "watch": ["Eurofighter and F-35A deliveries and the frigate replacement programme: timing remains uncertain"], "sources": ["sipri"]},
		"sources": {},
		"roster": {},
	},
}

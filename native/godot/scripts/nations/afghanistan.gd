extends RefCounted
## Afghanistan. Registered in nation_registry.gd; its position there is its saved index.
const DATA := {
	"id": "afghanistan",
	"group": "additional",
	"arsenal": "afghanistan",
	"name": "Afghanistan",
	"leader": "Supreme Leader Hibatullah Akhundzada",
	"colour": "#d9d4c5",
	"portrait": "akhundzada",
	"signature": "Suicide Attack Squad",
	"doctrine": "Insurgency: cheap, fast-raised, hardy infantry, suicide attack squads and attacks deep inside an enemy country. No air force, no navy, no nuclear reactor; sanctions and isolation starve its economy and research.",
	# Afghanistan: $417 a head: -25%; 4 articles a million: -30%, times the 72% of students left after the
	# ban on women: -50%. Trade -40%: trade with Pakistan fell 40% in 2025, the border shut since October
	# 2025. Happiness -8: the world's least happy nation (World Happiness Report, last six years running)
	# takes the game's largest single effect.
	"profile": {"bonus": {"incomePct": -0.25, "researchPct": -0.5, "hpInfantry": 0.15, "happiness": -8}, "resources": {"iron": 1.2}, "trade": 0.6, "train": {"infantry": 1.3}, "costs": {"infantry": 0.8, "armor": 1.25}, "strengths": ["Infantry +15% health, -20% cost, recruited 30% faster", "Suicide attack squads; insurgent attacks deep in an enemy country", "Iron output +20% (mines)"], "weaknesses": ["Income -25%, research -50% (women barred from study), trade -40% (borders shut, sanctions)", "No air force, navy, strategic air defence, missiles or nuclear reactor", "Armour costs +25%; happiness -8"]},
}

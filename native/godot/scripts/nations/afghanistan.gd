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
	"ai": {"compute": 0, "models": 0, "autonomy": 0, "cyber": 0, "lean": "in", "signs": ["laws"], "ceiling": 0,
		"why": "No data centres, an internet the authorities switch off, and women barred from study."},
	"ai_evidence": ["Severe infrastructure constraints", "Connectivity and access to education constrain adoption; no national AI deployment is assumed.", ["agriculture", "health", "administration", "diplomacy"]],
	## No public evidence of any use of AI in the strategic domains (ai_use_data.gd).
	"ai_use": {},
	"dossier": {
		"profile": {"land": "Captured small arms and vehicles support a limited ground force; captured equipment is not local manufacturing capacity.", "air": "A few maintained helicopters do not establish a combat-ready modern fighter force.", "sea": "Landlocked: no port, shipyard or navy should be inferred from generic game templates.", "fires": "Basic portable support and legacy artillery differ from guided missiles and modern integrated air defence.", "support": "Parts, trained maintainers and airworthiness are the central uncertainty for captured equipment.", "limits": "SIGAR's discussion of abandoned equipment is not proof that all assets remain operational or even inside Afghanistan.", "watch": ["Captured Western platforms: present condition and support remain unverified"], "sources": ["afghanistan", "sipri"]},
		"sources": {
			"afghanistan": ["SIGAR: captured equipment and sustainment (April 2025)", "https://www.sigar.mil/Portals/147/Files/Reports/Quarterly-Reports/2025-04-30qr.pdf"],
		},
		"roster": {},
	},
}

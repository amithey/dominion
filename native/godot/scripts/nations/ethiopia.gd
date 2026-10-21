extends RefCounted
## Ethiopia. Registered in nation_registry.gd; its position there is its saved index.
const DATA := {
	"id": "ethiopia",
	"group": "regional",
	"arsenal": "ethiopia",
	"name": "Ethiopia",
	"leader": "Prime Minister Abiy Ahmed",
	"colour": "#66a465",
	"portrait": "ethiopia",
	"signature": "Hydropower Grid",
	"doctrine": "Hydropower and corridors: agricultural output supports a growing population. A supplied power plant can sell a timed grid contract to a friendly partner. Landlocked: no ports or navy.",
	"dossier": {
		"profile": {"land": "A mixed imported armoured fleet gains a documented wheeled artillery option: SH-15.", "air": "Crewed combat aircraft and imported UAVs have separate support and vulnerability profiles.", "sea": "Landlocked: naval aspirations do not justify a playable port or surface fleet.", "fires": "Observed SH-15 provides mobile conventional fires; it does not grant Chinese strategic missile technology.", "support": "Foreign spares, ammunition, fuel and reconnaissance constrain the gun's usefulness.", "limits": "Janes observed delivery imagery; current readiness and precise fleet size are not established by this dossier.", "watch": ["Additional fighter or UAV reports need configuration and delivery confirmation"], "sources": ["ethiopia", "sipri"]},
		"sources": {
			"ethiopia": ["Janes: Ethiopia displays SH-15 (reported)", "https://www.janes.com/defence-intelligence-insights/defence-news/defence/ethiopia-displays-new-sh15-howitzers"],
		},
		"roster": {
			"wheeledHowitzer": ["SH-15", "ethiopia", "Observed delivery; readiness unknown"],
		},
	},
}

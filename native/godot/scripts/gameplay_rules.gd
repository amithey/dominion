extends RefCounted
## Native balancing and offshore rules, applied to every campaign export.
static func apply(w: Node) -> void:
	# Artillery reaches three hexes (a hex is radius * sqrt 3 across).
	var three_hexes: float = float(w.map.logistics.hexRadius) * sqrt(3.0) * 3.0
	for entry in [["artillery", three_hexes], ["mlrs", three_hexes], ["aaVehicle", 65.0], ["samLauncher", 115.0]]:
		w.unit_defs[entry[0]].range = entry[1]
		w.unit_defs[entry[0]].aggro = entry[1] * 1.15
	w.damage_profile.samSite = {"air": 2.0}
	w.building_defs.bunker.desc = "Hardened strongpoint: machine guns engage enemy ground forces within 2 hexes; ground fire does it a third of the damage, and friendly troops beside it take half."
	w.building_defs.samSite.desc = "Automated anti-air battery: shoots down enemy aircraft in flight (not ground forces, not aircraft parked on a base)."
	w.building_defs.offshoreRig["water"] = true
	w.building_defs.offshoreRig.depositTypes = ["seaOil", "seaGas"]
	w.building_defs.offshoreRig.desc = "Offshore oil or natural gas. Marine contractors build the platform; no land worker required."
	w.map.depositTypes["seaGas"] = w.map.depositTypes.seaOil.duplicate(true)
	w.map.depositTypes.seaGas.merge({"name": "Offshore Natural Gas", "res": "gas", "rate": 2.0}, true)
	var index := 0
	for dep in w.map.deposits:
		if dep.type == "seaOil":
			index += 1
			if index % 2 == 0: dep.type = "seaGas"
	# Building cards say what each building does in this game (the export's
	# texts promised approval, public order, culture and education, which the
	# native game does not have; the military and industrial ones now work).
	for entry in [
		["powerPlant", "+15% production and construction speed (stacks up to +30%)."],
		["ammoDepot", "+5% damage (up to +25%) and 6% faster reloading (up to 18%) for all your units; stores 4 more missiles."],
		["commandCenter", "+10% health for every unit trained while it stands. Coordinates the war effort; holds the land around it."],
		["tvStation", "The national broadcaster: needed for the Mass Media research (+4 happiness)."],
		["policeStation", "Needed for the Internal Security Service research (catches enemy agents)."],
		["school", "+0.2 research a second. Needed for the Public Education research (+10% research)."],
		["library", "+0.5 research a second."],
		["university", "+1 research a second. Gateway to great discoveries."],
		["museum", "+4 happiness. A nation with a story fights for it."],
		["park", "+6 happiness. Everyone loves a picnic."],
		["stadium", "+8 happiness, +3% income. Bread and games."],
		["courthouse", "+5% income. Needed for the Constitutional Framework research."]]:
		if w.building_defs.has(entry[0]):
			w.building_defs[entry[0]].desc = entry[1]
	w.map.economy.startResources["gas"] = 100.0
	w.map.economy.baseCap["gas"] = 400.0
	w.map.trade.price["gas"] = 3.0

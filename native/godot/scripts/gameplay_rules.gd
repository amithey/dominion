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
	w.map.economy.startResources["gas"] = 100.0
	w.map.economy.baseCap["gas"] = 400.0
	w.map.trade.price["gas"] = 3.0

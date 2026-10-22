extends RefCounted
## Readable role silhouettes at RTS scale, not engineering replicas.
## Geometry shares the existing vertex-painted vehicles and live turret/rotor
## pivots; the same builders serve battlefield units and picture cards.

static func ground(g: RefCounted, key: String, owner: int) -> Dictionary:
	var parts := {"root": Node3D.new(), "turret": null, "radar": null, "axles": [], "muzzle": 3.3}
	parts.root.name = "Force_" + key
	g._mat = g.material_for(owner)
	var body: SurfaceTool = g._begin()
	var top: SurfaceTool = g._begin()
	var id: String = str(g.world.map.nations[owner].get("id", ""))
	if key == "decoy":
		# A decoy is built to look exactly like the real tank: that is the point.
		parts.root.free()
		var copy: Dictionary = g.build("tank", owner)
		copy.root.name = "Force_decoy"
		return copy
	if key in ["mineLayer", "counterBatteryRadar", "coastalASM"]:
		var bed: float = g.truck(body, parts, 4.2)
		parts.turret = Node3D.new()
		parts.turret.position = Vector3(0, bed + 0.1, -1.2)
		parts.root.add_child(parts.turret)
		if key == "mineLayer":
			# Banks of mine-dispenser tubes over the bed.
			for side: float in [-1.0, 1.0]:
				for row in range(3):
					for col in range(2):
						var tube := Transform3D(Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.FORWARD, side * 0.4), Vector3(side * (0.5 + col * 0.35), 0.4 + row * 0.32, 0.0))
						g.cyl(top, 0.14, 1.3, Vector3.ZERO, "z", g.DARK, 8, -1.0, tube)
			parts.muzzle = 1.2
		elif key == "counterBatteryRadar":
			# A large flat phased-array face on a raised mount.
			g.block(top, Vector3(0.5, 0.9, 0.5), Vector3(0, 0.45, 0), g.METAL)
			g.block(top, Vector3(2.6, 1.8, 0.22), Vector3(0, 1.6, 0.2), g.LIGHT, 0, 0, 0, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3.ZERO))
			g.block(top, Vector3(2.3, 1.55, 0.05), Vector3(0, 1.62, 0.33), g.DARK, 0, 0, 0, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3.ZERO))
			parts.radar = parts.turret
			parts.muzzle = 0.5
		else:
			# Two large anti-ship missile canisters, raised to fire.
			var raised := Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0, 0.35, 0))
			for side: float in [-0.55, 0.55]:
				g.cyl(top, 0.42, 5.6, Vector3(side, 0.45, 0.4), "z", g.LIGHT, 12, -1.0, raised)
				g.cyl(top, 0.36, 0.06, Vector3(side, 0.45, 3.2), "z", g.DARK, 12, -1.0, raised)
			parts.muzzle = 3.0
		g._attach(parts.root, body)
		g._attach(parts.turret, top)
		parts.turret.set_meta("axis", Vector3.UP)
		return parts
	if key in ["combatUGV", "logisticsUGV", "robotDog"]:
		robot(g, body, top, parts, key)
		g._attach(parts.root, body)
		if parts.turret != null:
			g._attach(parts.turret, top)
			parts.turret.set_meta("axis", Vector3.UP)
		return parts
	if key in ["mineClearer", "recoveryVehicle"]:
		g.tracks(body, 6.8, 1.5, 0.55, 6, 0.32)
		g.block(body, Vector3(3.0, 1.2, 6.8), Vector3(0, 0.6, 0), g.PAINT, 0.15, 0.6, 0.15)
		g.block(body, Vector3(2.6, 0.8, 3.4), Vector3(0, 1.6, -0.9), g.LIGHT, 0.08, 0.3, 0.05)
		for side: float in [-1.0, 1.0]:
			g.block(body, Vector3(0.06, 0.4, 0.9), Vector3(side * 1.5, 1.3, -1.2), g.TEAM)
		g.antenna(body, Vector3(-1.0, 2.3, -2.6), 2.0)
		parts.turret = Node3D.new()
		parts.turret.position = Vector3(0, 2.0, -0.4)
		parts.root.add_child(parts.turret)
		if key == "mineClearer":
			# A plough ahead of the hull and a line-charge launcher on the deck.
			g.block(body, Vector3(3.4, 0.7, 0.3), Vector3(0, 0.45, 3.9), g.METAL, 0, 0.4)
			for x: float in [-1.2, -0.4, 0.4, 1.2]:
				g.block(body, Vector3(0.18, 0.5, 0.8), Vector3(x, 0.25, 4.3), g.DARK)
			g.block(top, Vector3(1.6, 0.9, 2.4), Vector3(0, 0.45, 0), g.DARK, 0, 0, 0, Transform3D(Basis(Vector3.RIGHT, -0.45), Vector3.ZERO))
			parts.muzzle = 2.0
		else:
			# A dozer blade at the front and a jib crane over the deck.
			g.block(body, Vector3(3.3, 0.9, 0.25), Vector3(0, 0.6, 3.6), g.METAL, 0, 0.3)
			var jib := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0.7, 0.2, 0.2))
			g.block(top, Vector3(0.3, 0.3, 4.2), Vector3(0, 0, 2.0), g.LIGHT, 0, 0, 0, jib)
			g.cyl(top, 0.04, 1.4, Vector3(0.7, 1.6, 3.2), "y", g.METAL, 6)
			g.block(top, Vector3(0.6, 0.6, 0.6), Vector3(-0.6, 0.3, -0.4), g.DARK)
			parts.muzzle = 1.0
		g._attach(parts.root, body)
		g._attach(parts.turret, top)
		parts.turret.set_meta("axis", Vector3.UP)
		return parts
	if key == "towedHowitzer":
		g.axle(parts, 0.0, 1.35, 0.62, 0.38)
		g.block(body, Vector3(2.0, 0.35, 1.4), Vector3(0, 0.7, 0), g.METAL)
		for side: float in [-1.0, 1.0]:
			g.block(body, Vector3(0.2, 0.22, 3.6), Vector3.ZERO, g.PAINT, 0, 0, 0, Transform3D(Basis(Vector3.UP, side * 0.3), Vector3(side * 0.6, 0.32, -1.8)))
			g.block(body, Vector3(0.65, 0.12, 0.55), Vector3(side * 1.1, 0.12, -3.3), g.METAL)
		parts.turret = Node3D.new()
		parts.turret.position = Vector3(0, 0.95, 0)
		parts.root.add_child(parts.turret)
		var raised := Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3.ZERO)
		g.block(top, Vector3(0.7, 0.6, 1.4), Vector3(0, 0, 0), g.DARK)
		g.cyl(top, 0.13, 5.0, Vector3(0, 0.35, 2.2), "z", g.PAINT, 12, 0.1, raised)
		g.block(top, Vector3(0.45, 0.26, 0.4), Vector3(0, 0.35, 4.9), g.METAL, 0, 0, 0, raised)
		parts.muzzle = 4.9
	else:
		var tracked: bool = key == "heavyAPC" or (key == "ifv" and id != "indonesia") or (key == "directFire" and id == "indonesia") or (key == "reconVehicle" and id == "usa") or (key == "shortRangeSAM" and id in ["uk", "turkiye"])
		# The armoured roles have their own, detailed silhouettes.
		if key == "wheeledHowitzer" or (key == "shortRangeSAM" and not tracked):
			if key == "wheeledHowitzer":
				_truck_howitzer(g, body, top, parts)
			else:
				_air_defence_vehicle(g, body, top, parts)
			g._attach(parts.root, body)
			g._attach(parts.turret, top)
			parts.turret.set_meta("axis", Vector3.UP)
			return parts
		if key in ["ifv", "heavyAPC", "reconVehicle", "directFire"]:
			armour(g, body, top, parts, key, tracked, id)
			g._attach(parts.root, body)
			g._attach(parts.turret, top)
			parts.turret.set_meta("axis", Vector3.UP)
			return parts
		var scout: bool = key == "reconVehicle" and not tracked
		var heavy: bool = key == "heavyAPC"
		var length := 4.5 if scout else (7.3 if heavy else 6.5)
		var half_width := 1.1 if scout else 1.4
		var height := 1.65 if scout else 2.0
		if tracked:
			g.tracks(body, length, half_width, 0.55, 6, 0.32)
		else:
			var axles: Array = [-1.45, 1.45] if scout else [-2.15, -0.75, 0.75, 2.15]
			for z: float in axles: g.axle(parts, z, half_width, 0.56, 0.38)
		g.block(body, Vector3(half_width * 2.0, 1.1, length), Vector3(0, 0.6, 0), g.PAINT, 0.15, 0.7, 0.15)
		g.block(body, Vector3(half_width * 1.8, 0.7, length * 0.65), Vector3(0, 1.55, -0.3), g.LIGHT, 0.08, 0.3, 0.05)
		for side: float in [-1.0, 1.0]:
			g.block(body, Vector3(0.08, 0.32, 0.8), Vector3(side * half_width, 1.85, 0.9), g.GLASS)
			g.block(body, Vector3(0.06, 0.36, 0.85), Vector3(side * half_width, 1.3, -1.0), g.TEAM)
			if heavy:
				for z: float in [-2.5, -1.3, -0.1, 1.1, 2.3]:
					g.block(body, Vector3(0.25, 0.8, 1.0), Vector3(side * 1.5, 0.85, z), g.DARK)
		g.antenna(body, Vector3(-0.9, height, -length * 0.4), 2.0)
		g.block(body, Vector3(1.4, 1.1, 0.06), Vector3(0, 1.0, -length * 0.5 - 0.02), g.METAL)
		parts.turret = Node3D.new()
		parts.turret.position = Vector3(0, height, 0.3)
		parts.root.add_child(parts.turret)
		var gun: bool = key in ["directFire", "wheeledHowitzer"]
		g.block(top, Vector3(1.7 if gun else 1.1, 0.55, 1.9 if gun else 1.2), Vector3.ZERO, g.PAINT, 0.1, 0.2, 0.1)
		if not key in ["wheeledHowitzer", "shortRangeSAM"]:
			g.cyl(top, 0.12 if gun else (0.065 if key == "ifv" else 0.035), 4.3 if gun else 1.9, Vector3(0, 0.22, 2.7 if gun else 1.35), "z", g.METAL, 10)
		parts.muzzle = 4.8 if gun else 2.3
		if key == "wheeledHowitzer":
			# Truck cab ahead of an exposed rear gun; distinct from tracked guns.
			g.block(body, Vector3(2.5, 1.4, 1.6), Vector3(0, 2.0, 2.3), g.PAINT)
			g.block(body, Vector3(2.1, 0.65, 0.06), Vector3(0, 2.3, 3.13), g.GLASS)
			parts.turret.position.z = -1.6
			var elevated := Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.6, 0))
			g.cyl(top, 0.15, 7.0, Vector3(0, 0, 3.2), "z", g.LIGHT, 12, 0.1, elevated)
			parts.muzzle = 6.2
		if key == "shortRangeSAM":
			for side: float in [-1.0, 1.0]:
				for level: float in [0.45, 0.95]:
					g.block(top, Vector3(0.6, 0.4, 2.3), Vector3(side * 1.15, level, 0.25), g.LIGHT)
					g.block(top, Vector3(0.53, 0.33, 0.08), Vector3(side * 1.15, level, 1.44), g.DARK)
			g.block(top, Vector3(1.0, 0.65, 0.16), Vector3(0, 1.5, -0.5), g.GLASS)
			parts.muzzle = 1.5
		if scout:
			g.block(top, Vector3(0.3, 0.4, 0.4), Vector3(0.45, 0.8, -0.2), g.DARK)
			g.block(top, Vector3(0.26, 0.16, 0.04), Vector3(0.45, 0.85, 0.02), g.GLASS)
		if key == "ifv":
			g.block(top, Vector3(0.4, 0.3, 0.45), Vector3(-0.45, 0.6, 0.1), g.GLASS)
	g._attach(parts.root, body)
	if parts.turret != null:
		g._attach(parts.turret, top)
		parts.turret.set_meta("axis", Vector3.UP)
	return parts

static func craft_model(c: RefCounted, key: String, owner: int) -> Dictionary:
	var g: RefCounted = c.g
	g._mat = c.material_for(owner, "ship" if key in ["missileBoat", "carrier", "asFrigate", "landingShip"] else ("heli" if key in ["scoutHelicopter", "heavyLift"] else "jet"))
	var st: SurfaceTool = g._begin()
	var parts := {"root": Node3D.new(), "rotor": null, "radar": null, "turret": null}
	parts.root.name = "Force_" + key
	if key == "asFrigate":
		c.destroyer(st, parts, 13.0, 2.5)
		# A towed-array winch and torpedo tubes at the stern.
		g.cyl(st, 0.35, 0.9, Vector3(0, 1.4, -5.6), "x", c.DARK, 10)
		for side: float in [-1.0, 1.0]:
			g.cyl(st, 0.12, 1.1, Vector3(side * 0.95, 1.5, -2.6), "z", c.METAL, 8)
	elif key == "carrier":
		carrier(c, st, parts, str(c.world.map.nations[owner].get("id", "")))
	elif key == "landingShip":
		landing_ship(c, st, parts)
	elif key in ["aewc", "maritimePatrol"]:
		# A transport or airliner airframe: long fuselage, straight wings, two engines.
		var l := 12.0
		c.fuselage(st, l, [[0.0, 0.7, 0.75], [0.12, 0.85, 0.9], [0.6, 0.85, 0.9], [0.85, 0.55, 0.6], [1.0, 0.15, 0.2]], c.PAINT)
		g.prim(st, c._sphere(0.4), Transform3D(Basis().scaled(Vector3(1.4, 0.8, 1.4)), Vector3(0, 0.5, l * 0.42)), c.GLASS)
		for side: float in [-1.0, 1.0]:
			c.surface(st, Vector3(side * 0.8, 0.2, 1.2), Vector3(side * 0.8, 0.2, -0.8), Vector3(side * 7.2, 0.4, 0.4), Vector3(side * 7.2, 0.4, -0.5), 0.2, 0.08, Vector3.UP, c.PAINT)
			c.surface(st, Vector3(side * 0.4, 0.3, -4.6), Vector3(side * 0.4, 0.3, -5.6), Vector3(side * 2.8, 0.3, -5.2), Vector3(side * 2.8, 0.3, -5.8), 0.1, 0.05, Vector3.UP, c.PAINT)
			g.cyl(st, 0.42, 1.6, Vector3(side * 2.8, -0.15, 0.9), "z", c.METAL, 12)
			c.roundel(st, Vector3(side * 4.4, 0.52, -0.1), 0.32)
		c.surface(st, Vector3(0, 0.6, -4.3), Vector3(0, 0.6, -5.8), Vector3(0, 2.6, -5.4), Vector3(0, 2.6, -6.0), 0.1, 0.05, Vector3.RIGHT, c.PAINT)
		if key == "aewc":
			# The rotating radar dome on two struts.
			for z: float in [-0.9, -2.1]:
				g.block(st, Vector3(0.15, 1.1, 0.25), Vector3(0, 1.3, z), c.METAL)
			var dome: Array = c._node(parts, "radar", Vector3(0, 2.0, -1.5))
			var disc: SurfaceTool = dome[1]
			g.cyl(disc, 2.4, 0.45, Vector3.ZERO, "y", c.LIGHT, 20)
			g.block(disc, Vector3(4.4, 0.05, 0.6), Vector3(0, 0.25, 0), c.DARK)
			g._attach(dome[0], disc)
		else:
			# A tail boom for the magnetic anomaly detector, and a weapons bay.
			g.cyl(st, 0.12, 2.2, Vector3(0, 0.2, -7.2), "z", c.METAL, 8)
			g.block(st, Vector3(0.9, 0.2, 2.2), Vector3(0, -0.85, 0.5), c.DARK)
	elif key == "ewJet":
		c.fighter(st)
		# Jamming pods under the wings and a radome-tipped fin.
		for side: float in [-1.0, 1.0]:
			g.cyl(st, 0.3, 2.2, Vector3(side * 1.6, -0.55, -1.0), "z", c.LIGHT, 12, 0.18)
			g.cyl(st, 0.22, 0.4, Vector3(side * 3.5, 0.0, -2.3), "z", c.WHITE, 10, 0.05)
		g.cyl(st, 0.3, 1.8, Vector3(0, -0.6, 0.6), "z", c.LIGHT, 12, 0.18)
	elif key == "navalHelicopter":
		c.utility_helicopter(st, parts, 1.0, true)
	elif key == "heavyBomberDrone":
		hexacopter(c, st, parts)
	elif key == "heavyLift":
		heavy_lift(c, st, parts, str(c.world.map.nations[owner].get("id", "")))
	elif key == "missileBoat":
		c.gunboat(st, parts, 8.0, 2.0)
		for side: float in [-1.0, 1.0]:
			for z: float in [-1.0, -2.0]:
				var xform := Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(side * 0.58, 1.4, z))
				g.block(st, Vector3(0.5, 0.45, 1.25), Vector3.ZERO, c.DARK, 0.04, 0, 0, xform)
	elif key == "scoutHelicopter":
		# Purpose-built unarmed sensor aircraft, rather than a gunship mesh.
		c.fuselage(st, 4.4, [[0.0, 0.4, 0.5], [0.3, 0.65, 0.65], [0.65, 0.6, 0.65], [0.9, 0.3, 0.4], [1.0, 0.1, 0.15]], c.PAINT)
		g.prim(st, c._sphere(0.52), Transform3D(Basis().scaled(Vector3(1.1, 0.9, 1.5)), Vector3(0, 0.3, 1.0)), c.GLASS)
		g.cyl(st, 0.16, 3.9, Vector3(0, 0.35, -3.5), "z", c.PAINT, 10, 0.25)
		g.block(st, Vector3(0.12, 1.1, 0.8), Vector3(0, 0.8, -5.3), c.PAINT)
		g.prim(st, c._sphere(0.25), Transform3D(Basis(), Vector3(0, 0.85, 0.6)), c.GLASS)
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(0.1, 0.1, 3.3), Vector3(side * 0.85, -0.8, 0), c.METAL)
			g.block(st, Vector3(0.06, 0.75, 0.08), Vector3(side * 0.65, -0.45, 0.6), c.METAL)
		var rotor: Array = c._node(parts, "rotor", Vector3(0, 1.1, 0))
		var blades: SurfaceTool = rotor[1]
		for i in range(4):
			g.block(blades, Vector3(0.25, 0.04, 3.2), Vector3(0, 0, 1.5), c.DARK, 0, 0, 0, Transform3D(Basis(Vector3.UP, i * PI * 0.5), Vector3.ZERO))
		g._attach(rotor[0], blades)
	elif key == "attackJet":
		attack_aircraft(c, st)
	else:
		var attack: bool = key == "attackJet"
		var length := 8.5 if attack else 7.3
		c.fuselage(st, length, [[0.0, 0.45, 0.28], [0.2, 0.62, 0.4], [0.5, 0.52, 0.4], [0.75, 0.33, 0.3], [0.92, 0.12, 0.15], [1.0, 0.01, 0.01]], c.PAINT)
		g.prim(st, c._sphere(0.34), Transform3D(Basis().scaled(Vector3(0.85, 0.85, 2.2)), Vector3(0, 0.35, 1.35)), c.GLASS)
		for side: float in [-1.0, 1.0]:
			c.surface(st, Vector3(side * 0.45, 0, 1.3), Vector3(side * 0.45, 0, -1.4), Vector3(side * (4.5 if attack else 3.3), 0, 0.2 if attack else -0.9), Vector3(side * (4.5 if attack else 3.3), 0, -1.1 if attack else -1.7), 0.12, 0.04, Vector3.UP, c.PAINT)
			c.surface(st, Vector3(0, 0.1, -2.4), Vector3(0, 0.1, -3.6), Vector3(side * 1.65, 0.1, -3.1), Vector3(side * 1.65, 0.1, -3.8), 0.06, 0.03, Vector3.UP, c.PAINT)
			c.missile(st, Vector3(side * 2.1, -0.25, -0.1), 1.15)
			c.roundel(st, Vector3(side * 2.6, 0.06, -0.8), 0.23)
			if attack:
				g.cyl(st, 0.32, 1.8, Vector3(side * 0.9, 0.2, -2.4), "z", c.DARK, 12, 0.29)
				c.missile(st, Vector3(side * 3.2, -0.22, -0.3), 1.0)
		c.surface(st, Vector3(0, 0.2, -2.6), Vector3(0, 0.2, -3.7), Vector3(0, 1.4, -3.1), Vector3(0, 1.4, -3.8), 0.09, 0.04, Vector3.RIGHT, c.PAINT)
		if not attack: g.cyl(st, 0.28, 0.3, Vector3(0, 0, -3.7), "z", c.METAL, 12)
	g._attach(parts.root, st)
	return parts

static func infantry_prop(w: Node, holder: Node3D, key: String, owner: int) -> void:
	if not key in ["mortarTeam", "machineGunTeam", "scoutTeam", "recoillessTeam"]: return
	var g: RefCounted = w.armor
	g._mat = g.material_for(owner)
	var st: SurfaceTool = g._begin()
	var prop := Node3D.new()
	prop.name = "Equipment_" + key
	holder.add_child(prop)
	if key == "mortarTeam":
		g.cyl(st, 0.42, 0.08, Vector3(0.8, 0.12, 0.6), "y", g.DARK, 12)
		var raised := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.8, 0.16, 0.6))
		g.cyl(st, 0.085, 1.5, Vector3(0, 0.7, 0), "y", g.METAL, 10, 0.085, raised)
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(0.06, 0.85, 0.06), Vector3(0.8 + side * 0.24, 0.48, 1.0), g.PAINT)
	elif key == "recoillessTeam":
		g.cyl(st, 0.12, 1.55, Vector3(0.65, 1.2, 0.5), "z", g.METAL, 12)
		g.cyl(st, 0.19, 0.28, Vector3(0.65, 1.2, -0.35), "z", g.DARK, 12)
		g.block(st, Vector3(0.3, 0.18, 0.25), Vector3(0.65, 1.42, 0.55), g.GLASS)
		g.block(st, Vector3(0.45, 0.45, 0.6), Vector3(-0.6, 0.25, 0), g.PAINT)
	elif key == "machineGunTeam":
		g.block(st, Vector3(0.22, 0.18, 0.75), Vector3(0.65, 0.85, 0.6), g.DARK)
		g.cyl(st, 0.045, 1.1, Vector3(0.65, 0.9, 1.35), "z", g.METAL, 8)
		g.block(st, Vector3(0.3, 0.22, 0.3), Vector3(0.4, 0.77, 0.55), g.PAINT)
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(0.06, 0.78, 0.06), Vector3(0.65 + side * 0.24, 0.4, 0.85), g.METAL)
	else:
		g.block(st, Vector3(0.48, 0.7, 0.26), Vector3(0, 1.35, -0.35), g.DARK)
		g.antenna(st, Vector3(0.14, 1.7, -0.35), 0.7)
	g._attach(prop, st)


## Aircraft carriers by class (native/WAR-TOOLS-RESEARCH-2026-10-12.md, "Carriers"):
##   super  catapult carrier (Ford, Fujian, Charles de Gaulle): an angled landing
##          deck to port, the island to starboard, deck-edge lifts, two bow catapults
##   twin   Queen Elizabeth: a ski-jump bow and two islands
##   ski    a ski-jump bow and one island (Vikrant; Anadolu, an assault ship
##          with a stern dock)
##   flat   Kaga: a straight flat deck, as a converted helicopter destroyer
##   box    Shahid Bagheri: a converted container ship, its bridge block aft and
##          a flight deck with a ramp forward
## Aircraft parked on deck are separate nodes, DeckPlane0..: war_tools.gd hides
## them while they are flying.
const CARRIER_STYLE := {"usa": ["super", 30.0], "china": ["super", 29.0], "france": ["super", 25.0], "uk": ["twin", 27.5], "italy": ["ski", 23.0], "india": ["ski", 25.0], "turkiye": ["ski", 22.0], "japan": ["flat", 23.0], "iran": ["box", 23.0]}
const DRONE_CARRIERS := ["turkiye", "iran"]
const DECK_DARK := Color(0.15, 0.3, 0.0)   # non-skid deck coating: charcoal, against the grey hull
const MARK := 0.22                         # deck line width

static func carrier(c: RefCounted, st: SurfaceTool, parts: Dictionary, id: String) -> void:
	var g: RefCounted = c.g
	var style: String = CARRIER_STYLE.get(id, ["super", 28.0])[0]
	var length: float = CARRIER_STYLE.get(id, ["super", 28.0])[1]
	var beam := length * 0.15
	var deck_w := length * (0.26 if style == "super" else 0.22)
	var hull_top: float = float(c.hull(st, length, beam, 1.5, 1.3, 0.25).call(0.5))
	var y := hull_top + 0.9   # (blocks stand on their base) the flight deck stands on the hangar, over the hull
	var top := y + 0.22       # the deck surface: markings and aircraft stand on it
	var aft := -length * 0.5
	if style == "box":
		# A container ship: slab sides, the bridge and funnel block at the stern.
		g.block(st, Vector3(beam * 1.05, 0.95, length * 0.86), Vector3(0, hull_top - 0.05, length * 0.03), c.PAINT)
		g.block(st, Vector3(beam * 1.0, 2.6, length * 0.12), Vector3(0, hull_top + 0.9, aft + length * 0.08), c.WHITE)
		g.block(st, Vector3(beam * 1.1, 0.45, length * 0.13), Vector3(0, hull_top + 3.0, aft + length * 0.08), c.GLASS)
		g.block(st, Vector3(0.7, 1.4, 0.9), Vector3(0, hull_top + 3.45, aft + length * 0.03), c.TEAM)
		y = hull_top + 0.9
		top = y + 0.18
		g.block(st, Vector3(deck_w, 0.18, length * 0.7), Vector3(0, y, length * 0.12), DECK_DARK)
		_ramp(c, st, Vector3(-deck_w * 0.2, top - 0.25, length * 0.45), deck_w * 0.5, length * 0.08)
		g.block(st, Vector3(MARK, 0.03, length * 0.6), Vector3(-deck_w * 0.2, top, length * 0.1), c.WHITE)
		_deck_planes(c, parts, top, [Vector3(1.0, 0, -1.0), Vector3(1.0, 0, 1.5), Vector3(1.0, 0, 4.0)], true)
		return
	# The hangar deck and the overhanging flight deck, with sponsons beneath it.
	g.block(st, Vector3(beam * 1.02, 0.95, length * 0.9), Vector3(0, hull_top - 0.05, 0), c.PAINT)
	g.block(st, Vector3(deck_w, 0.22, length * 0.98), Vector3(0, y, 0.0), DECK_DARK)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3((deck_w - beam) * 0.5, 0.6, length * 0.6), Vector3(side * (beam + deck_w) * 0.25, y - 0.4, 0.0), c.DARK)
	if style == "super":
		# The angled landing area to port, sponsoned out past the hull.
		var angle := Transform3D(Basis(Vector3.UP, -0.16), Vector3(-deck_w * 0.32, y, -length * 0.12))
		g.block(st, Vector3(deck_w * 0.55, 0.22, length * 0.62), Vector3.ZERO, DECK_DARK, 0, 0, 0, angle)
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(MARK, 0.02, length * 0.58), Vector3(side * deck_w * 0.25, 0.22, 0), c.WHITE, 0, 0, 0, angle)
		for z in range(7):
			g.block(st, Vector3(MARK, 0.02, length * 0.04), Vector3(0, 0.22, -length * 0.26 + z * length * 0.085), c.WHITE, 0, 0, 0, angle)
		for z in range(5):
			g.block(st, Vector3(deck_w * 0.4, 0.02, 0.05), Vector3(0, 0.22, -length * 0.22 + z * 0.5), c.METAL, 0, 0, 0, angle)
		# Two bow catapults, and the edge lifts.
		for x: float in [-0.7, 0.7]:
			g.block(st, Vector3(MARK * 0.8, 0.02, length * 0.32), Vector3(x, top, length * 0.3), c.WHITE)
		for z: float in [0.1, -0.12, -0.3]:
			g.block(st, Vector3(1.4, 0.24, 1.6), Vector3(deck_w * 0.5 + 0.5, y, length * z), DECK_DARK)
		g.block(st, Vector3(1.4, 0.24, 1.6), Vector3(-deck_w * 0.5 - 0.4, y, -length * 0.3), DECK_DARK)
		_island(c, st, parts, Vector3(deck_w * 0.36, top, -length * (0.12 if id == "usa" else 0.02)), length)
		_deck_planes(c, parts, top, [Vector3(1.6, 0, 6.5), Vector3(1.6, 0, 8.2), Vector3(-0.6, 0, 9.6), Vector3(1.9, 0, -8.5), Vector3(0.4, 0, -10.0)], false)
	else:
		# A straight deck: a centre line and its markings.
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(MARK, 0.02, length * 0.86), Vector3(-deck_w * 0.1 + side * deck_w * 0.3, top, 0), c.WHITE)
		for z in range(6):
			g.block(st, Vector3(MARK, 0.02, length * 0.05), Vector3(-deck_w * 0.1, top, -length * 0.38 + z * length * 0.13), c.WHITE)
		if style in ["twin", "ski"]:
			_ramp(c, st, Vector3(-deck_w * 0.08, top - 0.25, length * 0.43), deck_w * 0.75, length * 0.1)
		if style == "twin":
			_island(c, st, parts, Vector3(deck_w * 0.38, top, length * 0.1), length * 0.8)
			_island(c, st, parts, Vector3(deck_w * 0.38, top, -length * 0.18), length * 0.8, false)
		else:
			_island(c, st, parts, Vector3(deck_w * 0.38, top, length * 0.02), length * 0.85)
		if id == "turkiye":
			# An assault ship: a stern gate over the well dock.
			g.block(st, Vector3(beam * 0.7, 0.9, 0.12), Vector3(0, hull_top - 0.1, aft - 0.02), c.DARK)
		var drones: bool = id in DRONE_CARRIERS
		_deck_planes(c, parts, top, [Vector3(1.7, 0, -2.0), Vector3(1.7, 0, -4.0), Vector3(1.7, 0, -6.0), Vector3(-0.8, 0, -8.0)], drones)

## An amphibious landing ship: the bridge and funnels forward of amidships, a long open
## vehicle deck and helicopter spots aft over the well dock, a stern gate, and the
## cargo on deck (vehicles under tarpaulins, containers).
static func landing_ship(c: RefCounted, st: SurfaceTool, parts: Dictionary) -> void:
	var g: RefCounted = c.g
	var length := 16.0
	var beam := 3.1
	var deck: Callable = c.hull(st, length, beam, 1.15, 1.0, 0.35)
	var h := func(z: float) -> float: return deck.call(z / length + 0.5)
	var bz := length * 0.14
	g.block(st, Vector3(beam * 0.86, 1.9, length * 0.2), Vector3(0, h.call(bz), bz), c.LIGHT, 0.1, 0.3, 0.1)
	g.block(st, Vector3(beam * 0.7, 0.8, length * 0.14), Vector3(0, h.call(bz) + 1.9, bz + 0.2), c.LIGHT, 0.08, 0.3)
	g.block(st, Vector3(beam * 0.66, 0.2, 0.05), Vector3(0, h.call(bz) + 2.3, bz + length * 0.07 + 0.02), c.GLASS)
	c.mast(st, parts, Vector3(0, h.call(bz) + 2.7, bz - 0.3), 3.4)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(beam * 0.2, 1.3, length * 0.06), Vector3(side * beam * 0.3, h.call(-length * 0.04) + 0.0, -length * 0.04), c.PAINT, 0.1, 0.2)
		g.block(st, Vector3(beam * 0.16, 0.22, length * 0.05), Vector3(side * beam * 0.3, h.call(-length * 0.04) + 1.2, -length * 0.04 - 0.03), c.TEAM)
	# The long flat deck aft, with two helicopter spots and the vehicles on it.
	var aft := -length * 0.27
	g.block(st, Vector3(beam * 0.98, 0.18, length * 0.46), Vector3(0, h.call(aft) + 0.06, aft), DECK_DARK)
	for z: float in [aft + 1.6, aft - 2.2]:
		g.block(st, Vector3(1.6, 0.02, 0.1), Vector3(0, h.call(z) + 0.25, z), c.WHITE)
		g.block(st, Vector3(0.1, 0.02, 1.6), Vector3(0, h.call(z) + 0.25, z), c.WHITE)
	for i in range(3):
		var z: float = aft + 2.4 - i * 1.6
		var side: float = -0.62 if i % 2 == 0 else 0.62
		g.block(st, Vector3(0.9, 0.5, 1.3), Vector3(side, h.call(z) + 0.25, z), c.PAINT, 0.05)
		g.block(st, Vector3(0.9, 0.08, 1.3), Vector3(side, h.call(z) + 0.75, z), c.DARK)
	g.block(st, Vector3(beam * 0.84, 0.9, 0.14), Vector3(0, h.call(-length * 0.5 + 0.2), -length * 0.5 + 0.2), c.DARK)   # the stern gate
	# Davits for the landing craft, and the bow gun.
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.1, 0.9, 0.5), Vector3(side * beam * 0.5, h.call(length * 0.02) + 0.1, length * 0.02), c.METAL)
	c.naval_gun(parts, Vector3(0, h.call(length * 0.36), length * 0.36), 0.7)

## A superstructure on the starboard edge: bridge windows, a mast, a radar.
static func _island(c: RefCounted, st: SurfaceTool, parts: Dictionary, at: Vector3, length: float, mast := true) -> void:
	# (Blocks stand on their base: every height below is above the deck.)
	var g: RefCounted = c.g
	var w := length * 0.06
	var l := length * 0.16
	g.block(st, Vector3(w, 2.9, l), at, c.LIGHT, 0.04, 0.12, 0.08)
	g.block(st, Vector3(w * 0.92, 1.1, l * 0.78), at + Vector3(0, 2.9, 0.15), c.LIGHT, 0.05, 0.2)
	g.block(st, Vector3(w * 0.97, 0.34, l * 0.8), at + Vector3(0, 3.35, 0.25), c.GLASS)   # the bridge's window band
	g.block(st, Vector3(w * 0.97, 0.24, l * 0.7), at + Vector3(0, 1.9, 0.0), c.GLASS)     # flight control
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.06, 1.0, 1.0), at + Vector3(side * w * 0.5, 2.3, l * 0.25), c.DARK)   # phased-array faces
	g.block(st, Vector3(w * 0.6, 0.6, w * 0.6), at + Vector3(0, 4.0, -l * 0.15), c.METAL)
	g.prim(st, c._sphere(0.35), Transform3D(Basis(), at + Vector3(0, 4.9, -l * 0.15)), c.WHITE)
	g.block(st, Vector3(w * 0.55, 0.5, 0.8), at + Vector3(0, 0.5, -l * 0.5 - 0.4), c.TEAM)
	if mast:
		c.mast(st, parts, at + Vector3(0, 4.0, 0.3), 3.2)

## A ski-jump ramp at the bow.
static func _ramp(c: RefCounted, st: SurfaceTool, at: Vector3, width: float, run: float) -> void:
	var tilt := Transform3D(Basis(Vector3.RIGHT, -0.22), at + Vector3(0, 0.3, 0))
	c.g.block(st, Vector3(width, 0.3, run), Vector3.ZERO, DECK_DARK, 0, 0, 0, tilt)
	c.g.block(st, Vector3(MARK, 0.03, run), Vector3(0, 0.3, 0), c.WHITE, 0, 0, 0, tilt)

## Aircraft parked on deck, each its own node so it can leave and return.
static func _deck_planes(c: RefCounted, parts: Dictionary, y: float, spots: Array, drones: bool) -> void:
	var g: RefCounted = c.g
	for i in range(spots.size()):
		var node := Node3D.new()
		node.name = "DeckPlane%d" % i
		node.position = Vector3(spots[i].x, y, spots[i].z)
		node.rotation.y = -2.3 if i % 2 == 0 else 2.6
		parts.root.add_child(node)
		node.scale = Vector3.ONE * 1.7
		var pst: SurfaceTool = g._begin()
		if drones:
			g.block(pst, Vector3(0.22, 0.2, 1.5), Vector3(0, 0.12, 0), c.WHITE)
			g.block(pst, Vector3(2.6, 0.04, 0.32), Vector3(0, 0.2, 0.15), c.WHITE)
			g.block(pst, Vector3(0.9, 0.04, 0.2), Vector3(0, 0.2, -0.7), c.WHITE)
		else:
			g.block(pst, Vector3(0.3, 0.26, 1.9), Vector3(0, 0.16, 0), c.LIGHT, 0.2)
			g.block(pst, Vector3(1.1, 0.05, 0.8), Vector3(0, 0.15, -0.1), c.LIGHT, 0.5)   # wings, folded up short
			g.block(pst, Vector3(0.75, 0.04, 0.3), Vector3(0, 0.18, -0.85), c.LIGHT)
			for side: float in [-0.12, 0.12]:
				g.block(pst, Vector3(0.05, 0.42, 0.35), Vector3(side, 0.42, -0.8), c.LIGHT)   # twin fins
			g.block(pst, Vector3(0.16, 0.1, 0.42), Vector3(0, 0.32, 0.45), c.GLASS)
		g._attach(node, pst)


## Heavy-lift helicopters (native/HELICOPTERS-RESEARCH-2026-10-12.md): the
## Chinook's tandem rotors on a long box fuselage with a rear ramp; the Mi-26's
## single eight-blade rotor over the largest cabin flying; China's Z-8, a
## boat-hulled single-rotor type.
static func heavy_lift(c: RefCounted, st: SurfaceTool, parts: Dictionary, id: String) -> void:
	var g: RefCounted = c.g
	if id == "russia" or id == "china":
		var big := 1.5 if id == "russia" else 1.2
		c.utility_helicopter(st, parts, big)
		# A clamshell rear door and a rotor with more blades.
		g.block(st, Vector3(1.6 * big, 1.2 * big, 0.2), Vector3(0, -0.6 * big, -2.15 * big), c.DARK)
		var hub: Node3D = parts.rotor
		var extra: SurfaceTool = g._begin()
		for b in range(4 if id == "russia" else 2):
			var xf := Transform3D(Basis(Vector3.UP, TAU * (b + 0.5) / (4.0 if id == "russia" else 2.0)) * Basis(Vector3.BACK, 0.03), Vector3.ZERO)
			g.block(extra, Vector3(0.3 * big, 0.035, 3.3 * big), Vector3(0, 0, 1.75 * big), c.DARK, 0.0, 0.0, 0.0, xf)
		g._attach(hub, extra)
		return
	# The Chinook: a long box fuselage, a rotor pylon at each end, a rear ramp.
	var l := 7.6
	c.fuselage(st, l, [[0.0, 0.75, 0.75, 0.15], [0.08, 0.95, 1.0], [0.85, 0.95, 1.05], [0.97, 0.9, 1.0], [1.0, 0.7, 0.8]], c.PAINT)
	g.prim(st, c._sphere(0.6), Transform3D(Basis().scaled(Vector3(1.4, 0.8, 1.0)), Vector3(0, 0.25, l * 0.48)), c.GLASS)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.35, 0.55, l * 0.75), Vector3(side * 1.0, -0.75, -0.2), c.PAINT)   # fuel sponsons
		for z in range(5):
			g.block(st, Vector3(0.05, 0.28, 0.3), Vector3(side * 0.97, 0.05, l * 0.3 - z * 1.0), c.GLASS)
		g.cyl(st, 0.24, 1.3, Vector3(side * 0.62, 1.15, -l * 0.42), "z", c.LIGHT, 10, 0.2)   # engines on the aft pylon
		g.cyl(st, 0.2, 0.14, Vector3(side * 1.0, -1.0, l * 0.3), "x", c.RUBBER, 10)
		g.cyl(st, 0.2, 0.14, Vector3(side * 1.0, -1.0, -l * 0.3), "x", c.RUBBER, 10)
	g.block(st, Vector3(1.2, 1.3, 1.3), Vector3(0, 0.55, -l * 0.43), c.PAINT, 0.15, 0.3)   # aft pylon
	g.block(st, Vector3(0.9, 0.5, 0.9), Vector3(0, 0.95, l * 0.4), c.PAINT, 0.1, 0.1)      # forward pylon
	g.block(st, Vector3(1.5, 0.12, 1.3), Vector3(0, -0.85, -l * 0.53), c.DARK, 0, 0, 0, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3.ZERO))   # the ramp
	g.block(st, Vector3(0.1, 0.35, 0.4), Vector3(0, 1.6, -l * 0.43), c.TEAM)
	for which in [["rotor", l * 0.42, 1.55], ["rotor2", -l * 0.43, 2.0]]:
		var hub := Node3D.new()
		hub.position = Vector3(0, float(which[2]), float(which[1]))
		parts.root.add_child(hub)
		parts[which[0]] = hub
		var r: SurfaceTool = g._begin()
		g.cyl(r, 0.22, 0.24, Vector3.ZERO, "y", c.METAL, 10)
		for b in range(3):
			var xf := Transform3D(Basis(Vector3.UP, TAU * b / 3.0) * Basis(Vector3.BACK, 0.03), Vector3.ZERO)
			g.block(r, Vector3(0.36, 0.04, 4.0), Vector3(0, 0, 2.1), c.DARK, 0.0, 0.0, 0.0, xf)
		g._attach(hub, r)


## Ground robots (native/DRONES-ROBOTS-RESEARCH-2026-10-12.md): a low tracked
## chassis with a remote weapon station (THeMIS, Uran-9, Droid); a flat cargo
## robot with a stretcher frame; a four-legged robot with a rifle on its back.
static func robot(g: RefCounted, body: SurfaceTool, top: SurfaceTool, parts: Dictionary, key: String) -> void:
	if key == "robotDog":
		g.block(body, Vector3(0.7, 0.45, 1.6), Vector3(0, 0.75, 0), g.PAINT, 0.1, 0.15, 0.15)
		g.block(body, Vector3(0.45, 0.3, 0.45), Vector3(0, 0.95, 0.85), g.DARK, 0.05, 0.1)   # the sensor head
		g.block(body, Vector3(0.3, 0.12, 0.05), Vector3(0, 1.05, 1.08), g.GLASS)
		for side: float in [-1.0, 1.0]:
			for z: float in [-0.55, 0.55]:
				g.block(body, Vector3(0.14, 0.45, 0.14), Vector3(side * 0.33, 0.35, z), g.METAL, 0, 0, 0, Transform3D(Basis(Vector3.RIGHT, 0.35 if z > 0 else -0.35), Vector3.ZERO))
				g.block(body, Vector3(0.12, 0.42, 0.12), Vector3(side * 0.33, 0.0, z + (0.12 if z > 0 else -0.12)), g.DARK)
		parts.turret = Node3D.new()
		parts.turret.position = Vector3(0, 1.2, 0.0)
		parts.root.add_child(parts.turret)
		g.block(top, Vector3(0.18, 0.18, 0.5), Vector3(0, 0, -0.1), g.DARK)
		g.cyl(top, 0.03, 0.9, Vector3(0, 0.1, 0.55), "z", g.METAL, 6)
		parts.muzzle = 1.0
		return
	# A small tracked chassis: the THeMIS layout, tracks either side of a central module.
	g.tracks(body, 2.6, 0.95, 0.4, 4, 0.22)
	g.block(body, Vector3(1.1, 0.5, 2.3), Vector3(0, 0.35, 0), g.PAINT, 0.05, 0.1, 0.1)
	g.antenna(body, Vector3(-0.4, 0.85, -0.9), 1.3)
	g.block(body, Vector3(0.3, 0.2, 0.08), Vector3(0, 0.6, 1.15), g.GLASS)   # the driving camera
	if key == "logisticsUGV":
		# A cargo deck with crates and a stretcher frame.
		g.block(body, Vector3(1.7, 0.08, 2.0), Vector3(0, 0.85, 0), g.DARK)
		g.block(body, Vector3(0.6, 0.45, 0.6), Vector3(-0.4, 0.93, 0.4), g.PAINT)
		g.block(body, Vector3(0.7, 0.12, 1.5), Vector3(0.45, 0.93, -0.2), g.LIGHT)
		for x: float in [-0.8, 0.8]:
			g.block(body, Vector3(0.05, 0.35, 0.05), Vector3(x, 0.93, 0.9), g.METAL)
		return
	# The remote weapon station: a sensor box and a heavy machine gun.
	parts.turret = Node3D.new()
	parts.turret.position = Vector3(0, 0.85, -0.1)
	parts.root.add_child(parts.turret)
	g.block(top, Vector3(0.6, 0.4, 0.7), Vector3.ZERO, g.DARK)
	g.block(top, Vector3(0.25, 0.2, 0.06), Vector3(0.18, 0.25, 0.36), g.GLASS)
	g.cyl(top, 0.05, 1.3, Vector3(-0.1, 0.22, 0.95), "z", g.METAL, 8)
	g.block(top, Vector3(0.25, 0.25, 0.35), Vector3(0.3, 0.05, -0.2), g.PAINT)   # the ammunition box
	parts.muzzle = 1.6

## A heavy bomber hexacopter (Vampire): six rotor arms round a central body,
## a bomb rack beneath and a sensor ball.
static func hexacopter(c: RefCounted, st: SurfaceTool, parts: Dictionary) -> void:
	var g: RefCounted = c.g
	g.block(st, Vector3(0.9, 0.35, 0.9), Vector3(0, -0.15, 0), c.DARK, 0.1)
	g.prim(st, c._sphere(0.18), Transform3D(Basis(), Vector3(0, -0.3, 0.45)), c.GLASS)
	for i in range(6):
		var a := TAU * i / 6.0
		var dir := Vector3(sin(a), 0, cos(a))
		g.block(st, Vector3(0.1, 0.08, 1.5), Vector3.ZERO, c.PAINT, 0, 0, 0, Transform3D(Basis(Vector3.UP, a), dir * 0.75))
		g.cyl(st, 0.08, 0.2, dir * 1.45 + Vector3(0, 0.05, 0), "y", c.METAL, 8)
		g.cyl(st, 0.55, 0.02, dir * 1.45 + Vector3(0, 0.18, 0), "y", c.DARK, 14)   # the rotor disc
	for x: float in [-0.25, 0.25]:
		g.cyl(st, 0.09, 0.5, Vector3(x, -0.5, 0), "z", c.METAL, 8)   # bombs on the rack
	g.block(st, Vector3(0.06, 0.35, 0.06), Vector3(0.35, -0.55, 0.35), c.METAL)
	g.block(st, Vector3(0.06, 0.35, 0.06), Vector3(-0.35, -0.55, -0.35), c.METAL)


## The armoured roles, each its own silhouette (native/UNIT-LOOKS-2026-10-12.md):
##   ifv          a sloped hull with a trim vane and a rear ramp; a two-man
##                turret with an autocannon and a twin anti-tank missile box
##   heavyAPC     a tank-heavy hull (Namer): thick skirts, a stepped front, a
##                remote weapon station and a rear door
##   reconVehicle a light 4x4 patrol vehicle with an open crew compartment, a
##                roll cage and a machine gun on a ring (the tracked US Bradley
##                Scout uses the IFV body with a sensor mast)
##   directFire   a wheeled (or tracked, Harimau) hull under a big turret with a
##                long 105 mm gun, its fume extractor and muzzle brake
static func armour(g: RefCounted, st: SurfaceTool, top: SurfaceTool, parts: Dictionary, key: String, tracked: bool, id: String) -> void:
	if key == "reconVehicle" and not tracked:
		_patrol_vehicle(g, st, top, parts)
		return
	var heavy := key == "heavyAPC"
	var gun := key == "directFire"
	var length := 7.4 if heavy else (7.0 if gun else 6.4)
	var hw := 1.55 if heavy else 1.42
	var deck := 1.75 if heavy else 1.5   # the hull roof
	if tracked:
		g.tracks(st, length, hw, 0.62, 7 if heavy else 6, 0.32)
		# Side skirts in panels over the upper run.
		for side: float in [-1.0, 1.0]:
			var panels := 6
			for i in range(panels):
				var z := -length * 0.5 + 0.55 + i * (length - 1.1) / (panels - 1)
				g.block(st, Vector3(0.14 if heavy else 0.08, 0.7 if heavy else 0.55, (length - 0.8) / panels), Vector3(side * (hw + 0.05), 0.42, z), g.PAINT if i % 2 == 0 else g.LIGHT)
	else:
		var axles: Array = [-2.4, -0.8, 0.8, 2.4] if length > 6.6 else [-2.0, 0.0, 2.0]
		for z: float in axles: g.axle(parts, z, hw, 0.56, 0.42)
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(0.1, 0.12, length - 0.6), Vector3(side * (hw + 0.02), 1.05, 0), g.DARK)   # the wheel-arch line
	# Lower and upper hull, a sloped glacis, the rear plate.
	g.block(st, Vector3(hw * 1.5, 0.7, length - 0.4), Vector3(0, 0.35, 0), g.DARK)
	g.block(st, Vector3(hw * 2.2, deck - 0.95, length - 0.6), Vector3(0, 0.95, -0.2), g.PAINT, 0.05, 0.0, 0.2)
	var front := length * 0.5
	g.hexa(st, [Vector3(-hw * 1.05, 0.45, front + 0.05), Vector3(hw * 1.05, 0.45, front + 0.05), Vector3(hw * 1.05, 0.95, front - 0.4), Vector3(-hw * 1.05, 0.95, front - 0.4),
		Vector3(-hw * 1.05, 0.95, front + 0.0), Vector3(hw * 1.05, 0.95, front + 0.0), Vector3(hw * 1.02, deck, front - (1.2 if heavy else 1.5)), Vector3(-hw * 1.02, deck, front - (1.2 if heavy else 1.5))], g.LIGHT)
	if heavy:
		# A stepped, thick front and slab armour along the sides.
		g.block(st, Vector3(hw * 2.1, 0.35, 0.8), Vector3(0, deck, front - 1.6), g.DARK, 0.1)
		for side: float in [-1.0, 1.0]:
			g.block(st, Vector3(0.3, 0.55, length - 1.6), Vector3(side * (hw - 0.05), deck - 0.55, -0.4), g.LIGHT)
	elif not gun:
		g.block(st, Vector3(hw * 1.7, 0.12, 0.35), Vector3(0, 0.9, front - 0.1), g.PAINT, 0, 0.3)   # trim vane
	g.block(st, Vector3(hw * 1.4, deck - 0.4, 0.12), Vector3(0, 0.4, -front + 0.25), g.METAL)        # rear ramp / door
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.2, 0.12, 0.1), Vector3(side * hw * 0.8, 0.95, front - 0.25), g.GLASS)  # headlights
		g.block(st, Vector3(0.06, 0.36, 0.8), Vector3(side * hw * 1.1, deck - 0.5, -1.2), g.TEAM)
		g.block(st, Vector3(0.45, 0.3, 1.2), Vector3(side * hw * 0.75, deck, -front + 1.2), g.DARK)   # stowage
	for i in range(4):
		g.block(st, Vector3(hw * 1.2, 0.04, 0.12), Vector3(0, deck, front - 2.2 - i * 0.25), g.METAL)   # engine grille
	g.hatch(st, Vector3(-hw * 0.45, deck, front - 1.0), 0.28)
	g.antenna(st, Vector3(-hw * 0.8, deck, -front + 0.6), 2.2)
	# The turret.
	parts.turret = Node3D.new()
	parts.turret.position = Vector3(0, deck, -0.1 if gun else 0.1)
	parts.root.add_child(parts.turret)
	if heavy:
		# A remote weapon station on a hatch ring.
		g.cyl(top, 0.42, 0.18, Vector3(0, 0.09, 0), "y", g.DARK, 14)
		g.block(top, Vector3(0.6, 0.45, 0.7), Vector3(0, 0.18, 0), g.PAINT)
		g.block(top, Vector3(0.3, 0.2, 0.05), Vector3(0.15, 0.45, 0.36), g.GLASS)
		g.cyl(top, 0.05, 1.3, Vector3(-0.15, 0.4, 0.95), "z", g.METAL, 8)
		parts.muzzle = 1.6
		return
	var tw := 1.0 if gun else 0.8
	var tl := 1.6 if gun else 1.2
	# A faceted turret with a bustle.
	g.hexa(top, [Vector3(-tw * 0.7, 0, tl), Vector3(tw * 0.7, 0, tl), Vector3(tw, 0, -tl * 0.9), Vector3(-tw, 0, -tl * 0.9),
		Vector3(-tw * 0.5, 0.62, tl * 0.75), Vector3(tw * 0.5, 0.62, tl * 0.75), Vector3(tw * 0.9, 0.66, -tl * 0.85), Vector3(-tw * 0.9, 0.66, -tl * 0.85)], g.PAINT)
	g.block(top, Vector3(tw * 1.8, 0.5, 0.7), Vector3(0, 0.05, -tl * 1.2), g.LIGHT, 0.05)   # bustle
	g.cyl(top, 0.3, 0.22, Vector3(-tw * 0.45, 0.66, -tl * 0.3), "y", g.DARK, 12)              # commander's cupola
	g.block(top, Vector3(0.28, 0.3, 0.28), Vector3(-tw * 0.45, 0.88, -tl * 0.05), g.DARK)
	g.block(top, Vector3(0.22, 0.14, 0.04), Vector3(-tw * 0.45, 0.98, 0.1 - tl * 0.05), g.GLASS)
	for side: float in [-1.0, 1.0]:
		g.smoke_launchers(top, Vector3(side * tw * 0.75, 0.42, tl * 0.5), side, 3)
	g.antenna(top, Vector3(tw * 0.7, 0.66, -tl * 1.1), 1.8)
	if gun:
		# A long 105 mm gun: mantlet, fume extractor, muzzle brake.
		g.block(top, Vector3(0.75, 0.55, 0.45), Vector3(0, 0.08, tl - 0.1), g.DARK, 0.05)
		g.cyl(top, 0.11, 4.6, Vector3(0, 0.36, tl + 2.3), "z", g.PAINT, 12, 0.095)
		g.cyl(top, 0.17, 0.7, Vector3(0, 0.36, tl + 1.6), "z", g.LIGHT, 12)
		g.cyl(top, 0.15, 0.32, Vector3(0, 0.36, tl + 4.55), "z", g.DARK, 12)
		parts.muzzle = tl + 4.7
		return
	# An autocannon, a coaxial gun and the twin anti-tank missile box.
	g.block(top, Vector3(0.45, 0.4, 0.4), Vector3(0, 0.12, tl - 0.1), g.DARK)
	g.cyl(top, 0.065, 2.2, Vector3(0, 0.3, tl + 1.0), "z", g.METAL, 10)
	g.cyl(top, 0.085, 0.3, Vector3(0, 0.3, tl + 2.05), "z", g.DARK, 10)
	g.cyl(top, 0.03, 0.8, Vector3(0.25, 0.25, tl + 0.3), "z", g.METAL, 6)
	if key == "reconVehicle":
		# The tracked scout: a raised sensor mast in place of the missile box.
		g.cyl(top, 0.05, 1.4, Vector3(tw * 0.6, 1.3, -tl * 0.4), "y", g.METAL, 6)
		g.block(top, Vector3(0.5, 0.35, 0.4), Vector3(tw * 0.6, 2.0, -tl * 0.4), g.DARK)
		g.block(top, Vector3(0.4, 0.18, 0.04), Vector3(tw * 0.6, 2.1, -tl * 0.4 + 0.2), g.GLASS)
	else:
		g.block(top, Vector3(0.42, 0.45, 1.1), Vector3(tw * 0.95, 0.3, -0.1), g.DARK)
		g.block(top, Vector3(0.36, 0.16, 0.04), Vector3(tw * 0.95, 0.55, 0.46), g.METAL)
		g.block(top, Vector3(0.36, 0.16, 0.04), Vector3(tw * 0.95, 0.35, 0.46), g.METAL)
	parts.muzzle = tl + 2.2

## A light 4x4 patrol vehicle (Jackal, Fennek, Hawkei): open crew compartment,
## roll cage, a ring-mounted machine gun, a spare wheel and jerricans.
static func _patrol_vehicle(g: RefCounted, st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var length := 4.8
	for z: float in [-1.5, 1.5]: g.axle(parts, z, 1.15, 0.52, 0.38)
	g.block(st, Vector3(2.0, 0.55, length), Vector3(0, 0.55, 0), g.PAINT, 0.05, 0.25, 0.1)
	g.block(st, Vector3(2.1, 0.08, length - 0.3), Vector3(0, 1.1, 0), g.DARK)      # the floor and sills
	g.block(st, Vector3(1.9, 0.5, 1.3), Vector3(0, 1.1, 1.6), g.PAINT, 0.05, 0.4)  # bonnet
	for side: float in [-1.0, 1.0]:
		# The roll cage, door frames and a windscreen frame.
		g.block(st, Vector3(0.08, 0.95, 0.08), Vector3(side * 0.92, 1.18, 0.75), g.METAL)
		g.block(st, Vector3(0.08, 0.85, 0.08), Vector3(side * 0.92, 1.18, -1.2), g.METAL)
		g.block(st, Vector3(0.08, 0.08, 2.0), Vector3(side * 0.92, 2.05, -0.22), g.METAL)
		g.block(st, Vector3(0.06, 0.3, 1.6), Vector3(side * 1.02, 1.18, -0.3), g.TEAM if side > 0 else g.PAINT)
		g.block(st, Vector3(0.18, 0.12, 0.1), Vector3(side * 0.7, 1.15, 2.25), g.GLASS)
		g.block(st, Vector3(0.22, 0.45, 0.3), Vector3(side * 0.75, 1.18, -2.1), g.DARK)   # jerricans
	g.block(st, Vector3(1.84, 0.08, 0.08), Vector3(0, 2.05, 0.75), g.METAL)
	g.block(st, Vector3(1.7, 0.55, 0.06), Vector3(0, 1.2, 0.95), g.GLASS)
	g.cyl(st, 0.42, 0.25, Vector3(0, 1.5, -2.45), "z", g.RUBBER, 12)                   # the spare wheel
	g.antenna(st, Vector3(-0.8, 1.2, -1.8), 2.2)
	parts.turret = Node3D.new()
	parts.turret.position = Vector3(0, 2.1, -0.3)
	parts.root.add_child(parts.turret)
	g.cyl(top, 0.55, 0.08, Vector3.ZERO, "y", g.METAL, 16)   # the weapon ring
	g.block(top, Vector3(0.2, 0.2, 0.7), Vector3(0, 0.1, 0.2), g.DARK)
	g.cyl(top, 0.04, 1.2, Vector3(0, 0.22, 0.95), "z", g.METAL, 6)
	g.block(top, Vector3(0.5, 0.35, 0.06), Vector3(0, 0.1, 0.55), g.PAINT)                # gun shield
	parts.muzzle = 1.5


## A wheeled self-propelled howitzer (CAESAR, PCL-181, Archer, Malva): a 6x6
## truck with an armoured cab, the gun on the rear bed, a recoil spade lowered
## behind it.
static func _truck_howitzer(g: RefCounted, st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var bed: float = g.truck(st, parts, 4.4)
	g.block(st, Vector3(2.6, 0.5, 1.9), Vector3(0, 2.6, 2.35), g.PAINT, 0.1, 0.2)   # the armoured cab roof
	g.block(st, Vector3(2.0, 0.9, 0.25), Vector3(0, 0.3, -3.25), g.METAL, 0, 0.3)   # the recoil spade
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.25, 0.12, 1.4), Vector3(side * 1.0, 1.1, -1.6), g.DARK)   # ammunition lockers
	parts.turret = Node3D.new()
	parts.turret.position = Vector3(0, bed + 0.2, -1.4)
	parts.root.add_child(parts.turret)
	g.block(top, Vector3(1.2, 0.5, 1.4), Vector3(0, 0, 0), g.DARK)                 # the cradle
	var elevated := Transform3D(Basis(Vector3.RIGHT, -0.38), Vector3(0, 0.55, 0.2))
	g.cyl(top, 0.16, 7.2, Vector3(0, 0, 3.3), "z", g.LIGHT, 12, 0.13, elevated)
	g.cyl(top, 0.22, 0.4, Vector3(0, 0, 6.8), "z", g.DARK, 12, -1.0, elevated)      # muzzle brake
	for side: float in [-1.0, 1.0]:
		g.cyl(top, 0.09, 1.6, Vector3(side * 0.35, 0.2, 0.6), "z", g.METAL, 8, -1.0, elevated)   # recuperators
	parts.muzzle = 6.6

## A wheeled short-range air defence (Avenger, Pantsir, Tor on wheels): a light
## vehicle with a cab, a turret carrying two missile pods either side of the
## operator's cabin, and a search radar.
static func _air_defence_vehicle(g: RefCounted, st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var length := 5.2
	for z: float in [-1.6, 1.6]: g.axle(parts, z, 1.15, 0.52, 0.4)
	g.block(st, Vector3(2.2, 0.65, length), Vector3(0, 0.5, 0), g.PAINT, 0.05, 0.3, 0.1)
	g.block(st, Vector3(2.0, 0.85, 1.6), Vector3(0, 1.15, 1.3), g.PAINT, 0.1, 0.45)   # the cab
	g.block(st, Vector3(1.8, 0.35, 0.05), Vector3(0, 1.55, 2.05), g.GLASS, 0, 0.1)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.05, 0.3, 0.7), Vector3(side * 1.0, 1.5, 1.3), g.GLASS)
		g.block(st, Vector3(0.18, 0.12, 0.1), Vector3(side * 0.75, 0.9, length * 0.5 - 0.05), g.GLASS)
		g.block(st, Vector3(0.06, 0.35, 1.2), Vector3(side * 1.12, 0.9, -1.0), g.TEAM)
	g.antenna(st, Vector3(-0.9, 1.15, -2.2), 2.0)
	parts.turret = Node3D.new()
	parts.turret.position = Vector3(0, 1.15, -0.9)
	parts.root.add_child(parts.turret)
	g.cyl(top, 0.75, 0.25, Vector3.ZERO, "y", g.DARK, 16)
	g.block(top, Vector3(0.9, 0.8, 1.0), Vector3(0, 0.25, 0), g.PAINT, 0.08, 0.15)        # the operator's cabin
	g.block(top, Vector3(0.7, 0.25, 0.05), Vector3(0, 0.75, 0.5), g.GLASS)
	for side: float in [-1.0, 1.0]:
		g.block(top, Vector3(0.55, 0.7, 1.3), Vector3(side * 0.85, 0.35, 0.0), g.LIGHT)    # a missile pod
		for row in range(2):
			for col in range(2):
				g.cyl(top, 0.1, 0.06, Vector3(side * (0.73 + col * 0.24), 0.55 + row * 0.26, 0.66), "z", g.DARK, 8)
	g.block(top, Vector3(0.9, 0.5, 0.08), Vector3(0, 1.2, -0.3), g.METAL, 0, 0, 0, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3.ZERO))   # the radar face
	g.cyl(top, 0.05, 0.4, Vector3(0, 1.05, -0.3), "y", g.METAL, 6)
	parts.muzzle = 0.8

## A ground-attack aircraft (A-10, Su-25, Jaguar...): a long straight wing with
## many pylons, two engines in pods high at the rear, twin fins, a big nose gun.
static func attack_aircraft(c: RefCounted, st: SurfaceTool) -> void:
	var g: RefCounted = c.g
	var l := 8.6
	c.fuselage(st, l, [[0.0, 0.5, 0.35], [0.15, 0.62, 0.55], [0.55, 0.55, 0.5], [0.8, 0.38, 0.35], [1.0, 0.12, 0.15]], c.PAINT)
	g.prim(st, c._sphere(0.36), Transform3D(Basis().scaled(Vector3(0.9, 0.9, 1.9)), Vector3(0, 0.42, 2.6)), c.GLASS)
	g.cyl(st, 0.07, 0.9, Vector3(0, -0.2, l * 0.5 + 0.3), "z", c.METAL, 8)   # the nose gun
	for side: float in [-1.0, 1.0]:
		# A straight, deep wing with pylons and stores.
		c.surface(st, Vector3(side * 0.5, -0.1, 1.0), Vector3(side * 0.5, -0.1, -0.6), Vector3(side * 4.8, -0.05, 0.75), Vector3(side * 4.8, -0.05, -0.1), 0.2, 0.08, Vector3.UP, c.PAINT)
		for x: float in [1.4, 2.4, 3.4, 4.2]:
			g.block(st, Vector3(0.06, 0.25, 0.5), Vector3(side * x, -0.32, 0.4), c.METAL)
			c.missile(st, Vector3(side * x, -0.55, 0.3), 1.0)
		# An engine pod high on the rear fuselage, and the tail.
		g.cyl(st, 0.36, 1.9, Vector3(side * 0.85, 0.65, -2.0), "z", c.LIGHT, 12, 0.3)
		g.cyl(st, 0.26, 0.15, Vector3(side * 0.85, 0.65, -3.0), "z", c.DARK, 12)
		g.block(st, Vector3(0.12, 0.45, 0.5), Vector3(side * 0.6, 0.35, -2.0), c.PAINT)
		c.surface(st, Vector3(side * 0.3, 0.2, -3.2), Vector3(side * 0.3, 0.2, -4.0), Vector3(side * 1.9, 0.25, -3.5), Vector3(side * 1.9, 0.25, -4.0), 0.07, 0.04, Vector3.UP, c.PAINT)
		c.surface(st, Vector3(side * 1.8, 0.25, -3.4), Vector3(side * 1.8, 0.25, -4.0), Vector3(side * 1.8, 1.4, -3.6), Vector3(side * 1.8, 1.4, -4.0), 0.08, 0.04, Vector3.RIGHT, c.PAINT)
		c.roundel(st, Vector3(side * 3.0, 0.06, 0.3), 0.3)
	g.block(st, Vector3(0.12, 0.35, 0.45), Vector3(0, 1.1, -3.8), c.TEAM)

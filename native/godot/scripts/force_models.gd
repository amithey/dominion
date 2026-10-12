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
	g._mat = c.material_for(owner, "ship" if key in ["missileBoat", "carrier", "asFrigate"] else ("heli" if key == "scoutHelicopter" else "jet"))
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
		var deck: Callable = c.hull(st, 24.0, 4.6, 1.7, 1.3, 0.35)
		var top: float = float(deck.call(0.5))
		# The flight deck overhangs the hull, with an angled landing strip.
		g.block(st, Vector3(6.0, 0.25, 23.0), Vector3(0.4, top + 0.6, 0.2), c.DECK)
		g.block(st, Vector3(0.12, 0.02, 14.0), Vector3(-0.8, top + 0.74, -1.5), c.WHITE, 0, 0, 0, Transform3D(Basis(Vector3.UP, 0.15), Vector3.ZERO))
		g.block(st, Vector3(0.12, 0.02, 9.0), Vector3(1.4, top + 0.74, 6.0), c.WHITE)
		# The island on the starboard side, with its mast and radar.
		g.block(st, Vector3(1.5, 3.2, 4.0), Vector3(2.6, top + 2.2, -1.0), c.LIGHT, 0.06, 0.2)
		g.block(st, Vector3(1.4, 0.35, 2.6), Vector3(2.6, top + 3.6, -0.9), c.GLASS)
		c.mast(st, parts, Vector3(2.6, top + 3.8, -1.4), 3.0)
		g.block(st, Vector3(0.7, 0.3, 0.9), Vector3(2.7, top + 1.9, -2.7), c.TEAM)
		# Aircraft ranged on deck.
		for i in range(5):
			c.missile(st, Vector3(-1.6 + (i % 2) * 1.2, top + 0.9, -7.0 + i * 1.6), 1.6)
			g.block(st, Vector3(1.4, 0.06, 0.5), Vector3(-1.6 + (i % 2) * 1.2, top + 0.88, -7.0 + i * 1.6), c.DARK)
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

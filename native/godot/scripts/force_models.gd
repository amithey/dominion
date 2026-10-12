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
	g._mat = c.material_for(owner, "ship" if key in ["missileBoat", "carrier", "asFrigate"] else ("heli" if key in ["scoutHelicopter", "heavyLift"] else "jet"))
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
const CARRIER_STYLE := {"usa": ["super", 30.0], "china": ["super", 29.0], "eu": ["super", 25.0], "uk": ["twin", 27.5], "india": ["ski", 25.0], "turkiye": ["ski", 22.0], "japan": ["flat", 23.0], "iran": ["box", 23.0]}
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

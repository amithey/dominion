extends RefCounted
## Display-only family silhouettes. They represent the payload type, rather
## than claiming to be scale replicas of each nation's particular hardware.
## Separate from missiles.missile_mesh: no change to flight or bomb effects.

static func family(key: String, definition: Dictionary) -> String:
	if key == "poseidon": return "torpedo"
	if key in ["hypersonic", "nuclearGlide"]: return "glide"
	if key == "mirv": return "mirv"
	if key == "neutronBomb" or key == "mirvWarhead": return "warhead"
	if key == "tsarBomba" or key == "bunkerBuster": return "bomb"
	if str(definition.get("special", "")) in ["dirty", "chemical", "chlorine", "riot", "incapacitant", "anthrax", "bio"]: return "canister"
	if key in ["cruise", "antiShip", "brahmos", "nuclearCruise", "burevestnik"]: return "cruise"
	if key == "antiRadar": return "antiRadar"
	return "ballistic" if definition.get("arc", false) else "tactical"

static func build(key: String, definition: Dictionary) -> Node3D:
	if definition.is_empty(): return null
	var root := Node3D.new()
	var shape := family(key, definition)
	root.set_meta("munition_family", shape)
	root.set_meta("munition_key", key)
	var body := Node3D.new()
	body.rotation.x = -PI * 0.5
	root.add_child(body)
	var nuclear: bool = definition.get("nuclear", key == "nuke")
	var accent := Color("dcac4d") if nuclear else Color("588c9c")
	if key == "cluster": accent = Color("cb913f")
	if key in ["emp", "nuclearEmp"]: accent = Color("5fc1e2")
	if key == "thermobaricMissile": accent = Color("ce7548")
	if key == "bunkerMissile" or key == "bunkerBuster": accent = Color("979fa5")
	var hull := Color("e3e8e7") if nuclear else Color("c6d2d4")
	var length := 5.0 if shape in ["ballistic", "mirv"] else 3.8
	var radius := 0.32
	if key == "tacticalNuke":
		length = 3.3
		radius = 0.4
	elif key == "hydrogenBomb":
		length = 5.8
		radius = 0.46
	elif key == "antiShip":
		hull = Color("8199ac")
	if shape == "bomb":
		length = 3.2 if key == "tsarBomba" else 4.1
		radius = 0.68 if key == "tsarBomba" else 0.28
	elif shape == "torpedo":
		length = 5.3
		radius = 0.5
		hull = Color("839c91")
	elif shape == "warhead":
		length = 1.5
		radius = 0.62
	elif shape == "canister":
		length = 2.1
		radius = 0.65
		hull = Color("63725a")
		accent = Color("c6b451") if key in ["chemical", "chlorine", "riotAgent", "incapacitant"] else Color("b999ba")
	if shape == "glide":
		var wedge := PrismMesh.new()
		wedge.size = Vector3(1.65, 3.9, 0.65)
		part(body, wedge, hull, Vector3.ZERO)
		box(body, Vector3(2.6, 0.75, 0.12), accent, Vector3(0, -1.0, 0))
	else:
		cylinder(body, radius, radius, length, hull, Vector3.ZERO)
		if shape == "canister":
			cylinder(body, radius * 0.96, radius * 0.96, 0.15, Color("353f38"), Vector3(0, length * 0.5, 0))
			box(body, Vector3(0.6, 0.12, 0.15), hull, Vector3(0, length * 0.5 + 0.15, 0))
		elif shape == "mirv":
			# Exposed payload bus: three re-entry bodies distinguish it at card size.
			for i in range(3):
				var a := float(i) * TAU / 3.0
				cylinder(body, 0.2, 0.015, 1.25, accent, Vector3(cos(a) * 0.28, length * 0.5 + 0.45, sin(a) * 0.28))
		else:
			var tip_length := 1.25 if shape in ["ballistic", "warhead", "antiRadar"] else 0.65
			cylinder(body, radius, 0.045, tip_length, Color("37414a") if shape == "torpedo" else accent, Vector3(0, length * 0.5 + tip_length * 0.5, 0))
		if not shape in ["warhead", "canister"]:
			for i in range(4):
				var fin := box(body, Vector3(radius * 2.5, 0.8, 0.055), accent.darkened(0.2), Vector3.ZERO)
				var a := float(i) * PI * 0.5
				fin.rotation.y = a
				fin.position = Vector3(cos(a) * radius * 1.5, -length * 0.35, -sin(a) * radius * 1.5)
			cylinder(body, radius * 0.82, radius * 0.82, 0.22, Color("29333a"), Vector3(0, -length * 0.5 - 0.1, 0))
		if shape == "cruise":
			box(body, Vector3(2.9, 0.65, 0.08), hull.darkened(0.18), Vector3(0, 0.0, 0))
			box(body, Vector3(0.4, 1.3, 0.3), Color("40535d"), Vector3(0, -0.4, -radius))
		elif shape == "antiRadar":
			box(body, Vector3(1.8, 0.8, 0.06), hull.darkened(0.15), Vector3(0, 0.65, 0))
		if shape == "torpedo":
			for i in range(4):
				var propeller := box(body, Vector3(1.2, 0.08, 0.12), Color("b29c62"), Vector3(0, -length * 0.5 - 0.35, 0))
				propeller.rotation.y = float(i) * PI * 0.25
	# Coloured payload bands remain visible even in the small queue thumbnails.
	for y in [-length * 0.25, length * 0.25]:
		if shape != "glide": cylinder(body, radius * 1.02, radius * 1.02, 0.18, accent, Vector3(0, y, 0))
	if key == "hydrogenBomb": cylinder(body, radius * 1.04, radius * 1.04, 0.3, Color("48525c"), Vector3.ZERO)
	return root

static func cylinder(parent: Node3D, bottom: float, top: float, height: float, colour: Color, at: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 32
	return part(parent, mesh, colour, at)

static func box(parent: Node3D, dimensions: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return part(parent, mesh, colour, at)

static func part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.25
	material.roughness = 0.52
	instance.material_override = material
	parent.add_child(instance)
	return instance

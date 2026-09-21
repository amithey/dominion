extends Node3D

# All building corners are fitted to the same conservative circle inside the hex.
const INNER_RADIUS := 7.65
var host: Node3D
var batches: Dictionary = {}

func box(size: Vector3, at: Vector3, color: String) -> void:
	var key := color
	if not batches.has(key):
		batches[key] = []
	batches[key].append(Transform3D(Basis.from_scale(size),at))

func build(game: Node3D, variant: int) -> void:
	host = game
	var tile := CylinderMesh.new()
	tile.top_radius = 9
	tile.bottom_radius = 9
	tile.height = 0.16
	tile.radial_segments = 6
	host.mesh_node(tile,host.material(Color("777c70")),Vector3(0,0.07,0),self)
	# Two continuous avenues leave clear spacing between the building plots.
	box(Vector3(17,0.03,2.2),Vector3(0,0.17,0),"353d40")
	box(Vector3(2.0,0.03,14),Vector3(0,0.18,0),"353d40")
	for side in [-1,1]:
		box(Vector3(15,0.10,0.35),Vector3(0,0.20,side*1.3),"adb0a0")
	for x in range(-7,8,2):
		box(Vector3(0.8,0.015,0.06),Vector3(x,0.2,0),"c3b885")
	var city_models := ["building-a","building-b","building-c"]
	var houses := ["House_A","House_B","House_C"]
	for side in [-1,1]:
		for column in range(3):
			var at := Vector3((column-1)*4.4,0.23,side*3.5)
			var is_center := column == 1
			var asset: String = city_models[variant] if is_center else houses[(column+variant)%3]
			place_building(asset,at,2.9 if is_center else 2.6,PI if side<0 else 0.0,variant)
			box(Vector3(3.4,0.07,3.6),Vector3(at.x,0.18,at.z),"939486")
	for side in [-1,1]:
		for x in [-5.0,-2.0,2.0,5.0]:
			var at := Vector3(x,0.2,side*5.6)
			if Vector2(at.x,at.z).length()<7.6:
				make_tree(at)
		for x in [-6.5,6.5]:
			box(Vector3(0.08,1.5,0.08),Vector3(x,0.95,side*1.55),"424d50")
			box(Vector3(0.30,0.12,0.22),Vector3(x,1.72,side*1.55),"dacda7")
	# Roads remain presentation-only until the logistics simulation is ported.
	if variant < 2:
		box(Vector3(5,0.05,2.2),Vector3(11,0.03,0),"353d40")
		for x in [9.5,11.0,12.5]:
			box(Vector3(0.7,0.02,0.06),Vector3(x,0.065,0),"c3b885")
	flush_batches()

func place_building(asset: String, at: Vector3, width: float, yaw: float, variant: int) -> void:
	var packed: PackedScene = load("res://assets/"+asset+".glb")
	var pivot := Node3D.new()
	add_child(pivot)
	var model: Node3D = packed.instantiate()
	pivot.add_child(model)
	var bounds: AABB = host.model_bounds(model)
	var scale_factor := width/maxf(bounds.size.x,bounds.size.z)
	var footprint_radius := Vector2(bounds.size.x,bounds.size.z).length()*0.5*scale_factor
	var available := INNER_RADIUS-Vector2(at.x,at.z).length()
	scale_factor *= minf(1.0,available/maxf(footprint_radius,0.01))
	model.scale = Vector3.ONE*scale_factor
	model.position = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*scale_factor
	pivot.position = at
	pivot.rotation.y = yaw
	# Muted roof tones make the imported suburban set coherent with city materials.
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var source: Material = mesh.get_active_material(surface)
			if source is StandardMaterial3D and source.resource_name.to_lower() == "roof":
				var roof := source.duplicate() as StandardMaterial3D
				roof.albedo_color = [Color("697778"),Color("846754"),Color("63705c")][variant]
				roof.metallic = 0.0
				mesh.set_surface_override_material(surface,roof)

func make_tree(at: Vector3) -> void:
	box(Vector3(0.18,1.1,0.18),at+Vector3(0,0.55,0),"645643")
	var crown := SphereMesh.new()
	crown.radius = 0.65
	crown.height = 1.8
	crown.radial_segments = 8
	crown.rings = 4
	host.mesh_node(crown,host.material(Color("435c3e")),at+Vector3(0,1.35,0),self)

func flush_batches() -> void:
	for color in batches:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = BoxMesh.new()
		instances.instance_count = batches[color].size()
		for i in range(instances.instance_count):
			instances.set_instance_transform(i,batches[color][i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = instances
		node.material_override = host.material(Color(color))
		add_child(node)

extends RefCounted
## Structural damage states, building fires, fire spread across light structures,
## and national/local firefighting by Fire Stations (fireStation).
##
## 1. Structural Damage States (b.damage_stage: 0 intact, 1 damaged, 2 critical):
##    Buildings that take hits visibly darken with soot/scorch, settle/list slightly,
##    shed fallen masonry/rafters around their base, and vent thin distress smoke.
##    Repairing a building above the thresholds restores its clean materials and posture.
## 2. Fire Ignition, Burn & Spread (b.fire: 0.0 .. 1.0):
##    Incendiary and explosive weapons (TOS-1A, MLRS, HIMARS, bombers, strike drones,
##    missiles, artillery, sabotage) can set buildings alight. Light structures
##    (cottages, houses, residential blocks, farms, markets) ignite easily, burn
##    down rapidly to total collapse, and throw embers to neighbouring buildings.
## 3. Fire Stations (fireStation):
##    Each standing Fire Station fields CREWS_PER_STATION firefighting crews, suppresses
##    active blazes (faster when stationed nearby), cools burning frames so light homes
##    survive, and cuts ember spread nationwide. More Fire Stations let a nation handle
##    larger simultaneous barrages without being overwhelmed.

const STEP := 0.5
const CREWS_PER_STATION := 2
const STAGE1_HP := 0.85
const STAGE2_HP := 0.45

## Flammability by building key:
## > 0.95 = light / timber / residential or volatile fuel/munitions structures
## 0.45..0.85 = standard civic / commercial / military buildings
## < 0.30 = hardened reinforced concrete / steel structures
const FLAMMABILITY := {
	# Light homes & timber/light civic districts ("מבנה קליל")
	"cottage": 1.35, "workerHouse": 1.25, "luxuryVillas": 1.20, "housing": 1.15,
	"residential": 1.10, "farm": 1.30, "park": 1.25, "market": 1.12,
	"fishingWharf": 1.05, "foodDepot": 1.00, "warehouse": 0.95, "worship": 0.90,
	"school": 0.85, "library": 0.92, "villageCenter": 0.85,
	# Volatile industrial / munitions sites
	"oilRefinery": 1.30, "ammoDepot": 1.25,
	# Medium civic, industrial & military structures
	"apartments": 0.72, "hospital": 0.55, "cityHall": 0.55, "courthouse": 0.50,
	"bank": 0.55, "stockExchange": 0.55, "tvStation": 0.65, "museum": 0.65,
	"embassy": 0.55, "university": 0.55, "techPark": 0.60, "barracks": 0.55,
	"helipad": 0.60, "port": 0.65, "railwayStation": 0.60, "lighthouse": 0.42,
	"waterTreatment": 0.35, "solarFarm": 0.50, "extractor": 0.75, "powerPlant": 0.75,
	"stadium": 0.48, "policeStation": 0.38, "intelAgency": 0.32,
	# Hardened / concrete / steel / offshore structures
	"hq": 0.12, "cityCenter": 0.25, "bunker": 0.05, "missileSilo": 0.08,
	"commandCenter": 0.12, "strategicComplex": 0.12, "specialLab": 0.20,
	"samSite": 0.18, "nuclearReactor": 0.12, "prison": 0.20,
	"tankFactory": 0.35, "shipyard": 0.35, "airfield": 0.35, "chipFab": 0.35,
	"aiDataCenter": 0.30, "fusionCell": 0.18, "mountainMine": 0.15,
	"fireStation": 0.15, "offshoreRig": 0.35, "fishingPlatform": 0.22,
}

const LIGHT_KEYS := [
	"cottage", "workerHouse", "luxuryVillas", "housing", "residential",
	"farm", "park", "market", "fishingWharf", "foodDepot", "warehouse",
	"worship", "school", "library", "villageCenter",
]

## Cached scorched materials keyed by [source_material_instance_id, stage].
static var _damaged_mats := {}
static var _rubble_mats := {}
static var _flame_draw_mat: StandardMaterial3D
static var _smoke_draw_mat: StandardMaterial3D
static var _water_draw_mat: StandardMaterial3D
static var _flame_proc_mat: ParticleProcessMaterial
static var _smoke_proc_mat: ParticleProcessMaterial
static var _distress_proc_mat: ParticleProcessMaterial
static var _water_proc_mat: ParticleProcessMaterial
static var _quad_flame: QuadMesh
static var _quad_smoke: QuadMesh
static var _quad_water: QuadMesh

static func flammability_of(key: String) -> float:
	return float(FLAMMABILITY.get(key, 0.60))

static func is_light(key: String) -> bool:
	return key in LIGHT_KEYS

## Active, built, living, non-EMP-disabled Fire Stations owned by `owner`.
static func active_stations(w: Node, owner: int) -> Array:
	var out := []
	for b in w.buildings:
		if b.owner == owner and b.key == "fireStation" and b.built and not b.dead and not w.disabled(b):
			out.append(b)
	return out

static func station_count(w: Node, owner: int) -> int:
	return active_stations(w, owner).size()

## Total firefighting crews currently available to `owner`.
static func crew_capacity(w: Node, owner: int) -> int:
	var total := 0
	for s in active_stations(w, owner):
		total += CREWS_PER_STATION if s.get("supplied", true) else 1
	return total

## Currently burning buildings owned by `owner`.
static func burning_of(w: Node, owner: int) -> Array:
	var out := []
	for b in w.buildings:
		if b.owner == owner and b.built and not b.dead and float(b.get("fire", 0.0)) > 0.001:
			out.append(b)
	return out

# ---------------------------------------------------------------- damage states

static func stage_for_hp(hp: float, max_hp: float) -> int:
	var share := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if share >= STAGE1_HP:
		return 0
	if share >= STAGE2_HP:
		return 1
	return 2

static func _damaged_material(src: Material, stage: int) -> Material:
	if src == null or stage <= 0 or not (src is BaseMaterial3D):
		return src
	var key := [src.get_instance_id(), stage]
	if _damaged_mats.has(key):
		return _damaged_mats[key]
	var base := src as BaseMaterial3D
	var m := base.duplicate() as BaseMaterial3D
	if stage == 1:
		m.albedo_color = base.albedo_color * Color(0.70, 0.65, 0.60)
		m.roughness = maxf(base.roughness, 0.90)
		m.metallic = base.metallic * 0.65
		if m.emission_enabled:
			m.emission_energy_multiplier = base.emission_energy_multiplier * 0.42
	else:
		m.albedo_color = base.albedo_color * Color(0.42, 0.37, 0.33)
		m.roughness = 0.98
		m.metallic = base.metallic * 0.30
		if m.emission_enabled:
			m.emission_enabled = false
	_damaged_mats[key] = m
	return m

static func _rubble_material(stage: int, ember := false) -> StandardMaterial3D:
	var key := "ember" if ember else ("s%d" % stage)
	if _rubble_mats.has(key):
		return _rubble_mats[key]
	var m := StandardMaterial3D.new()
	if ember:
		m.albedo_color = Color(0.22, 0.10, 0.06)
		m.roughness = 0.95
		m.emission_enabled = true
		m.emission = Color(1.0, 0.36, 0.08)
		m.emission_energy_multiplier = 1.8
	else:
		m.albedo_color = Color(0.38, 0.35, 0.31) if stage == 1 else Color(0.23, 0.20, 0.18)
		m.roughness = 0.96
	_rubble_mats[key] = m
	return m

static func _ensure_particle_assets() -> void:
	if _quad_flame != null:
		return
	var tex: Texture2D = preload("res://scripts/effects.gd").cloud_texture()

	_flame_draw_mat = StandardMaterial3D.new()
	_flame_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_flame_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_draw_mat.vertex_color_use_as_albedo = true
	_flame_draw_mat.albedo_texture = tex
	_flame_draw_mat.disable_receive_shadows = true
	_quad_flame = QuadMesh.new()
	_quad_flame.size = Vector2(2.4, 2.8)
	_quad_flame.material = _flame_draw_mat

	_smoke_draw_mat = StandardMaterial3D.new()
	_smoke_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_smoke_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_draw_mat.vertex_color_use_as_albedo = true
	_smoke_draw_mat.albedo_texture = tex
	_smoke_draw_mat.disable_receive_shadows = true
	_quad_smoke = QuadMesh.new()
	_quad_smoke.size = Vector2(2.8, 2.8)
	_quad_smoke.material = _smoke_draw_mat

	_water_draw_mat = StandardMaterial3D.new()
	_water_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_water_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_draw_mat.vertex_color_use_as_albedo = true
	_water_draw_mat.albedo_texture = tex
	_water_draw_mat.disable_receive_shadows = true
	_quad_water = QuadMesh.new()
	_quad_water.size = Vector2(1.4, 1.4)
	_quad_water.material = _water_draw_mat

	# Rising fire tongues
	_flame_proc_mat = ParticleProcessMaterial.new()
	_flame_proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_flame_proc_mat.emission_sphere_radius = 1.8
	_flame_proc_mat.direction = Vector3(0.08, 1.0, 0.04)
	_flame_proc_mat.spread = 22.0
	_flame_proc_mat.initial_velocity_min = 1.6
	_flame_proc_mat.initial_velocity_max = 3.4
	_flame_proc_mat.gravity = Vector3(0.15, 1.2, 0.08)
	_flame_proc_mat.scale_min = 0.65
	_flame_proc_mat.scale_max = 1.35
	_flame_proc_mat.angle_min = -180.0
	_flame_proc_mat.angle_max = 180.0
	var fg := Gradient.new()
	fg.set_color(0, Color(1.0, 0.92, 0.45, 0.0))
	fg.add_point(0.18, Color(1.0, 0.72, 0.22, 0.92))
	fg.add_point(0.58, Color(0.95, 0.28, 0.06, 0.70))
	fg.set_color(fg.get_point_count() - 1, Color(0.35, 0.06, 0.02, 0.0))
	var fgt := GradientTexture1D.new()
	fgt.gradient = fg
	_flame_proc_mat.color_ramp = fgt

	# Thick black-grey fire smoke
	_smoke_proc_mat = ParticleProcessMaterial.new()
	_smoke_proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_smoke_proc_mat.emission_sphere_radius = 2.0
	_smoke_proc_mat.direction = Vector3(0.22, 1.0, 0.10)
	_smoke_proc_mat.spread = 16.0
	_smoke_proc_mat.initial_velocity_min = 1.8
	_smoke_proc_mat.initial_velocity_max = 3.2
	_smoke_proc_mat.gravity = Vector3(0.35, 0.45, 0.14)
	_smoke_proc_mat.scale_min = 0.8
	_smoke_proc_mat.scale_max = 1.9
	_smoke_proc_mat.angle_min = -180.0
	_smoke_proc_mat.angle_max = 180.0
	var sg := Gradient.new()
	sg.set_color(0, Color(0.16, 0.14, 0.13, 0.0))
	sg.add_point(0.15, Color(0.18, 0.16, 0.15, 0.68))
	sg.set_color(sg.get_point_count() - 1, Color(0.26, 0.25, 0.24, 0.0))
	var sgt := GradientTexture1D.new()
	sgt.gradient = sg
	_smoke_proc_mat.color_ramp = sgt

	# Lighter distress smoke for damaged (non-burning) buildings
	_distress_proc_mat = ParticleProcessMaterial.new()
	_distress_proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_distress_proc_mat.emission_sphere_radius = 1.1
	_distress_proc_mat.direction = Vector3(0.20, 1.0, 0.10)
	_distress_proc_mat.spread = 14.0
	_distress_proc_mat.initial_velocity_min = 0.9
	_distress_proc_mat.initial_velocity_max = 1.7
	_distress_proc_mat.gravity = Vector3(0.28, 0.25, 0.10)
	_distress_proc_mat.scale_min = 0.55
	_distress_proc_mat.scale_max = 1.15
	var dg := Gradient.new()
	dg.set_color(0, Color(0.34, 0.33, 0.32, 0.0))
	dg.add_point(0.18, Color(0.36, 0.34, 0.33, 0.38))
	dg.set_color(dg.get_point_count() - 1, Color(0.45, 0.44, 0.43, 0.0))
	var dgt := GradientTexture1D.new()
	dgt.gradient = dg
	_distress_proc_mat.color_ramp = dgt

	# Firefighting water/foam spray mist
	_water_proc_mat = ParticleProcessMaterial.new()
	_water_proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	_water_proc_mat.emission_ring_radius = 4.2
	_water_proc_mat.emission_ring_inner_radius = 3.2
	_water_proc_mat.emission_ring_height = 0.6
	_water_proc_mat.emission_ring_axis = Vector3.UP
	_water_proc_mat.direction = Vector3(0.0, 0.85, 0.0)
	_water_proc_mat.spread = 32.0
	_water_proc_mat.initial_velocity_min = 3.0
	_water_proc_mat.initial_velocity_max = 5.2
	_water_proc_mat.gravity = Vector3(0.0, -4.8, 0.0)
	_water_proc_mat.scale_min = 0.45
	_water_proc_mat.scale_max = 0.95
	var wg := Gradient.new()
	wg.set_color(0, Color(0.78, 0.93, 1.0, 0.0))
	wg.add_point(0.20, Color(0.82, 0.95, 1.0, 0.72))
	wg.set_color(wg.get_point_count() - 1, Color(0.92, 0.97, 1.0, 0.0))
	var wgt := GradientTexture1D.new()
	wgt.gradient = wg
	_water_proc_mat.color_ramp = wgt

static func _rebuild_damage_props(b: Dictionary, stage: int) -> void:
	var old: Node = b.root.get_node_or_null("DamageVisual")
	if old != null:
		b.root.remove_child(old)
		old.queue_free()
	if stage <= 0 or b.def.get("water", false):
		return
	var holder := Node3D.new()
	holder.name = "DamageVisual"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(b.root.position.x * 73.0 + b.root.position.z * 137.0)) + stage * 19
	var count := 4 if stage == 1 else 9
	var reach := clampf(float(b.footprint) * 0.46, 2.2, 6.2)
	var mat := _rubble_material(stage, false)
	for i in range(count):
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.28, 0.28)
		var r := reach * rng.randf_range(0.68, 1.08)
		var chunk := MeshInstance3D.new()
		var box := BoxMesh.new()
		var beam := i % 3 == 0
		box.size = Vector3(rng.randf_range(1.1, 1.9), rng.randf_range(0.16, 0.28), rng.randf_range(0.22, 0.36)) if beam else Vector3(rng.randf_range(0.45, 0.95), rng.randf_range(0.28, 0.62), rng.randf_range(0.42, 0.88))
		chunk.mesh = box
		chunk.material_override = _rubble_material(stage, stage == 2 and i == 1)
		chunk.position = Vector3(cos(a) * r, box.size.y * 0.42, sin(a) * r)
		chunk.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.0, TAU), rng.randf_range(-0.22, 0.22))
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(chunk)
	if DisplayServer.get_name() != "headless":
		_ensure_particle_assets()
		var wisp := GPUParticles3D.new()
		wisp.name = "DistressSmoke"
		wisp.amount = 6 if stage == 1 else 12
		wisp.lifetime = 2.8 if stage == 1 else 3.4
		wisp.process_material = _distress_proc_mat
		wisp.draw_pass_1 = _quad_smoke
		wisp.position = Vector3(0.0, clampf(float(b.footprint) * 0.42, 2.4, 5.2), 0.0)
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(wisp)
	b.root.add_child(holder)

## Updates a building's 3D structural state (materials, sag/list, rubble, distress smoke)
## to match its current HP ratio. Safe and O(1) when the stage has not changed.
static func sync_damage_state(_w: Node, b: Dictionary) -> void:
	if b.get("dead", false) or not b.get("built", false) or not is_instance_valid(b.get("model")) or not is_instance_valid(b.get("root")):
		return
	var stage := stage_for_hp(float(b.hp), float(b.max_hp))
	if int(b.get("damage_stage", 0)) == stage:
		return
	if not b.has("_base_scale_y"):
		b._base_scale_y = float(b.get("full_scale_y", b.model.scale.y))
		b._base_rot_x = float(b.model.rotation.x)
		b._base_rot_z = float(b.model.rotation.z)
	b.damage_stage = stage
	var base_y := float(b._base_scale_y)
	var sign_z := 1.0 if fmod(absf(b.root.position.x * 3.1 + b.root.position.z), 2.0) >= 1.0 else -1.0
	var sign_x := 1.0 if fmod(absf(b.root.position.x + b.root.position.z * 2.7), 2.0) >= 1.0 else -1.0
	match stage:
		0:
			b.model.scale.y = base_y
			b.model.rotation.x = float(b._base_rot_x)
			b.model.rotation.z = float(b._base_rot_z)
		1:
			b.model.scale.y = base_y * 0.95
			b.model.rotation.x = float(b._base_rot_x) + sign_x * 0.015
			b.model.rotation.z = float(b._base_rot_z) + sign_z * 0.024
		2:
			b.model.scale.y = base_y * 0.86
			b.model.rotation.x = float(b._base_rot_x) + sign_x * 0.032
			b.model.rotation.z = float(b._base_rot_z) + sign_z * 0.052

	var meshes: Array = b.model.find_children("*", "MeshInstance3D", true, false)
	if b.model is MeshInstance3D:
		meshes.append(b.model)
	for mi_node in meshes:
		var mi := mi_node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var surf_n := mi.mesh.get_surface_count()
		if not mi.has_meta("_orig_surf_mats"):
			var orig := []
			for s in range(surf_n):
				orig.append(mi.get_surface_override_material(s))
			mi.set_meta("_orig_surf_mats", orig)
		var saved: Array = mi.get_meta("_orig_surf_mats")
		for s in range(mini(surf_n, saved.size())):
			var base_mat: Material = saved[s] if saved[s] != null else mi.mesh.surface_get_material(s)
			if stage == 0:
				mi.set_surface_override_material(s, saved[s])
			else:
				mi.set_surface_override_material(s, _damaged_material(base_mat, stage))
	_rebuild_damage_props(b, stage)

# ---------------------------------------------------------------- fire ignition & visuals

## How strongly `source` starts fires (0 = bullets/EMP; >1 = thermobaric/incendiary).
static func incendiary_power(_w: Node, source: Dictionary) -> float:
	if bool(source.get("incendiary", false)):
		return 1.25
	# The munition it was hit with says what it sets alight (firepower.gd); a plain gun or small arms leave it to
	# the unit that fired (the table below).
	var by_munition: float = preload("res://scripts/firepower.gd").fire_of_source(source)
	if by_munition >= 0.0:
		return by_munition
	var key := str(source.get("key", ""))
	if key == "" or key in ["soldier", "sniper", "machineGunTeam", "scoutTeam", "medic", "worker", "apc", "ifv", "heavyAPC", "bushmaster", "gunboat", "incident"]:
		return 0.0
	if key in ["tos1a", "heavyRocket"]:
		return 1.30
	if key == "missile":
		var special := str(source.get("special", ""))
		if special in ["hemp", "emp", "antiRadar"]:
			return 0.0
		if special == "neutron":
			return 0.12
		if special == "thermobaric" or bool(source.get("nuclear", false)):
			return 1.35
		if special == "cluster":
			return 0.55
		return 0.85
	if key in ["mlrs", "himars", "bomber", "raider", "heavyBomberDrone", "shahed", "loiterer", "harop", "fpvTeam", "saboteurs", "insurgents", "covert"]:
		return 0.82
	if key in ["artillery", "k9", "towedHowitzer", "wheeledHowitzer", "mortarTeam", "attackJet", "jet", "stealthFighter", "raptor", "sixthGen", "gunship", "akinci", "drone", "seaDrone", "brahmos", "df17"]:
		return 0.52
	if key in ["rocketSoldier", "atgmTeam", "recoillessTeam", "tank", "directFire", "railgunShip", "destroyer", "corvette", "commando"]:
		return 0.32
	var base := preload("res://scripts/additional_factions.gd").base(key)
	if base != key and base != "":
		var copy := source.duplicate()
		copy.key = base
		return incendiary_power(_w, copy)
	return 0.20 if bool(source.get("vehicle", false)) else 0.0

static func _sync_fire_visual(b: Dictionary) -> void:
	if not is_instance_valid(b.get("root")):
		return
	var fire := float(b.get("fire", 0.0))
	var node: Node3D = b.root.get_node_or_null("FireVisual") as Node3D
	if fire <= 0.001 or b.get("dead", false):
		if node != null:
			b.root.remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = Node3D.new()
		node.name = "FireVisual"
		node.position = Vector3(0.0, clampf(float(b.footprint) * 0.30, 1.4, 3.8), 0.0)
		var light := OmniLight3D.new()
		light.name = "FireLight"
		light.light_color = Color(1.0, 0.54, 0.16)
		light.omni_range = clampf(float(b.footprint) * 1.9, 10.0, 22.0)
		light.position = Vector3(0.0, 2.2, 0.0)
		node.add_child(light)
		if DisplayServer.get_name() != "headless":
			_ensure_particle_assets()
			var flames := GPUParticles3D.new()
			flames.name = "Flames"
			flames.amount = 18
			flames.lifetime = 1.15
			flames.process_material = _flame_proc_mat
			flames.draw_pass_1 = _quad_flame
			flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(flames)

			var smoke := GPUParticles3D.new()
			smoke.name = "Smoke"
			smoke.amount = 16
			smoke.lifetime = 2.8
			smoke.position = Vector3(0.0, 1.2, 0.0)
			smoke.process_material = _smoke_proc_mat
			smoke.draw_pass_1 = _quad_smoke
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(smoke)

			var spray := GPUParticles3D.new()
			spray.name = "WaterSpray"
			spray.amount = 14
			spray.lifetime = 1.0
			spray.position = Vector3(0.0, 0.4, 0.0)
			spray.process_material = _water_proc_mat
			spray.draw_pass_1 = _quad_water
			spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spray.emitting = false
			node.add_child(spray)
		b.root.add_child(node)
	var light_node := node.get_node_or_null("FireLight") as OmniLight3D
	if light_node != null:
		light_node.light_energy = lerpf(1.1, 3.8, clampf(fire, 0.0, 1.0))
	var flames_node := node.get_node_or_null("Flames") as GPUParticles3D
	if flames_node != null:
		flames_node.amount_ratio = clampf(0.28 + 0.72 * fire, 0.25, 1.0)
	var smoke_node := node.get_node_or_null("Smoke") as GPUParticles3D
	if smoke_node != null:
		smoke_node.amount_ratio = clampf(0.30 + 0.70 * fire, 0.25, 1.0)
	var spray_node := node.get_node_or_null("WaterSpray") as GPUParticles3D
	if spray_node != null:
		spray_node.emitting = int(b.get("fire_crews", 0)) > 0

## Sets or intensifies a fire on `b`. Returns true if the building is now burning.
static func ignite(w: Node, b: Dictionary, intensity: float, by_owner := -1, from_spread := false) -> bool:
	if b.get("dead", false) or not b.get("built", false) or intensity <= 0.0:
		return false
	var was_burning := float(b.get("fire", 0.0)) > 0.02
	b.fire = clampf(maxf(float(b.get("fire", 0.0)), intensity) + (0.14 * intensity if was_burning else 0.0), 0.0, 1.0)
	if by_owner >= 0:
		b.fire_by = by_owner
	b.repairing = false
	_sync_fire_visual(b)
	if not was_burning and int(b.owner) == 0 and w.get("sitrep") != null and w.sitrep != null:
		var stations := station_count(w, 0)
		var crews := crew_capacity(w, 0)
		var fires := burning_of(w, 0).size()
		var suffix := " — build a Fire Station or it will spread." if stations == 0 else (" — Fire Station crews overwhelmed (%d fires / %d crews)." % [fires, crews] if fires > crews else " — Fire Station crews responding.")
		var msg := ("%s caught fire from nearby flames" if from_spread else "%s is on fire") % str(b.def.name) + suffix
		w.sitrep.record("attack", "crit" if stations == 0 or fires > crews else "warn", "fire:0:%s" % ("spread" if from_spread else str(b.key)), msg, b.root.position)
	return true

## Called from world.damage() whenever a living building takes damage.
static func on_damaged(w: Node, b: Dictionary, amount: float, source: Dictionary) -> void:
	if b.get("dead", false) or amount <= 0.0:
		return
	sync_damage_state(w, b)
	if not b.get("built", false) or b.hp <= 0.0:
		return
	var power := incendiary_power(w, source)
	if power <= 0.0:
		return
	var flam := flammability_of(str(b.key))
	if flam <= 0.06 and power < 1.1:
		return
	var stations := station_count(w, int(b.owner))
	var prevent := 1.0 / (1.0 + 0.15 * float(stations))
	var share_hit := clampf(amount / maxf(float(b.max_hp), 1.0), 0.04, 1.0)
	var chance := clampf(power * flam * (0.48 + 1.35 * share_hit) * prevent, 0.0, 0.98)
	if power >= 1.2 and flam >= 0.50:
		chance = maxf(chance, 0.96)
	if randf() < chance:
		var start_intensity := clampf(0.30 + 0.36 * power * minf(flam, 1.25), 0.24, 0.95)
		ignite(w, b, start_intensity, int(source.get("owner", -1)), false)

## Restores both structural damage visuals and active fire visuals after loading a save.
static func restore_building(w: Node, b: Dictionary) -> void:
	b.erase("damage_stage")
	sync_damage_state(w, b)
	_sync_fire_visual(b)

# ---------------------------------------------------------------- simulation tick

static func _nearest_station_dist(stations: Array, at: Vector3) -> float:
	var best := INF
	for s in stations:
		var d := Vector2(s.root.position.x - at.x, s.root.position.z - at.z).length()
		if d < best:
			best = d
	return best

static func update(w: Node, delta: float) -> void:
	var acc := float(w.get_meta("_fire_acc", 0.0)) + delta
	if acc < STEP:
		w.set_meta("_fire_acc", acc)
		return
	var dt := acc
	w.set_meta("_fire_acc", 0.0)

	var hex_r: float = float(w.logistics.radius) if w.get("logistics") != null else 12.0
	var local_reach := hex_r * sqrt(3.0) * 6.0   # ~6 hexes: fast local fire-engine turnout
	var spread_reach := hex_r * 2.55             # adjacent district hexes (~20.8 m centre-to-centre)

	# Group burning buildings by owner so each nation's Fire Stations allocate crews across its fires.
	var by_owner := {}
	for b in w.buildings:
		if b.dead or not b.built:
			continue
		if int(b.get("damage_stage", 0)) != stage_for_hp(float(b.hp), float(b.max_hp)):
			sync_damage_state(w, b)
		if float(b.get("fire", 0.0)) > 0.001:
			var o := int(b.owner)
			if not by_owner.has(o):
				by_owner[o] = []
			by_owner[o].append(b)
		elif int(b.get("fire_crews", 0)) != 0:
			b.fire_crews = 0

	if by_owner.is_empty():
		return

	var spread_ignitions := []   # [[target_b, intensity, by_owner, from_pos], ...]
	var to_destroy := []

	for owner in by_owner:
		var fires: Array = by_owner[owner]
		var stations := active_stations(w, owner)
		var crews_left := crew_capacity(w, owner)

		# Sort fires so crews prioritize town centres, fragile light homes near collapse, and fires near a station.
		fires.sort_custom(func(a, b):
			var da := _nearest_station_dist(stations, a.root.position)
			var db := _nearest_station_dist(stations, b.root.position)
			var sa := float(a.fire) * 1.5 + (1.0 - float(a.hp) / maxf(float(a.max_hp), 1.0)) - minf(da, 200.0) * 0.003
			var sb := float(b.fire) * 1.5 + (1.0 - float(b.hp) / maxf(float(b.max_hp), 1.0)) - minf(db, 200.0) * 0.003
			return sa > sb
		)

		for b in fires:
			b.fire_crews = 0
		# Pass 1: one crew per burning building up to capacity.
		for b in fires:
			if crews_left <= 0:
				break
			b.fire_crews = 1
			crews_left -= 1
		# Pass 2: extra Fire Stations reinforce active blazes (up to 3 crews on one fire) for faster knockdown!
		var safety := 0
		while crews_left > 0 and safety < 24:
			safety += 1
			var progressed := false
			for b in fires:
				if crews_left <= 0:
					break
				if int(b.fire_crews) < 3:
					b.fire_crews = int(b.fire_crews) + 1
					crews_left -= 1
					progressed = true
			if not progressed:
				break

		var national_contain := 1.0 / (1.0 + 0.35 * float(stations.size()))

		for b in fires:
			var flam := flammability_of(str(b.key))
			var assigned := int(b.get("fire_crews", 0))
			var near_d := _nearest_station_dist(stations, b.root.position)
			var local_mult := 1.45 if near_d <= local_reach else 1.0

			if assigned > 0:
				var engine_boost := 1.28 if b.get("fire_engine_on_scene", false) else 1.0
				var crew_power := (1.0 + 0.62 * float(assigned - 1)) * local_mult * engine_boost
				b.fire = maxf(0.0, float(b.fire) - 0.22 * crew_power * dt)
			else:
				if flam >= 0.42:
					b.fire = minf(1.0, float(b.fire) + (0.045 + 0.048 * flam) * dt)
				else:
					# Reinforced concrete starves flames on its own when not fed by fuel.
					b.fire = maxf(0.0, float(b.fire) - 0.06 * dt)

			var cur_fire := float(b.fire)
			if cur_fire <= 0.001:
				b.fire = 0.0
				b.fire_crews = 0
				_sync_fire_visual(b)
				continue

			# Burn damage over time: light structures suffer severe structural loss and collapse if unchecked.
			var weight_mult := 1.28 if is_light(str(b.key)) else (0.72 if flam >= 0.42 else 0.22)
			var cooling := 0.28 if assigned > 0 else 1.0
			var burn_dps := (10.0 + 28.0 * cur_fire) * flam * weight_mult * cooling
			b.hp -= burn_dps * dt
			b.last_hit = w.game_time
			b.repairing = false
			sync_damage_state(w, b)
			_sync_fire_visual(b)

			if b.hp <= 0.0:
				if int(b.get("fire_by", -1)) >= 0:
					b.last_by = int(b.fire_by)
				to_destroy.append(b)
				continue

			# Ember & flame spread to adjacent buildings (especially light houses).
			if cur_fire >= 0.38 and not b.def.get("water", false):
				var crew_contain := 0.16 if assigned > 0 else 1.0
				for nb in w.buildings:
					if nb.dead or not nb.built or is_same(nb, b) or nb.def.get("water", false):
						continue
					if nb.key == "hq" or float(nb.get("fire", 0.0)) >= 0.30:
						continue
					var nb_flam := flammability_of(str(nb.key))
					if nb_flam < 0.32:
						continue
					var d := Vector2(nb.root.position.x - b.root.position.x, nb.root.position.z - b.root.position.z).length()
					if d > spread_reach:
						continue
					var prox := clampf(1.25 - 0.55 * (d / maxf(spread_reach, 1.0)), 0.45, 1.25)
					var light_vuln := 1.35 if is_light(str(nb.key)) else 0.65
					var nb_contain := national_contain if int(nb.owner) == owner else (1.0 / (1.0 + 0.35 * float(station_count(w, int(nb.owner)))))
					var p_spread := clampf(0.20 * cur_fire * nb_flam * light_vuln * prox * crew_contain * nb_contain * dt, 0.0, 0.85)
					if randf() < p_spread:
						spread_ignitions.append([nb, 0.40, int(b.get("fire_by", -1)), b.root.position])

	for item in spread_ignitions:
		var nb: Dictionary = item[0]
		if not nb.dead and float(nb.get("fire", 0.0)) < 0.30:
			ignite(w, nb, float(item[1]), int(item[2]), true)
			if w.get("effects") != null and w.effects != null:
				w.effects.impact(nb.root.position + Vector3.UP * 2.4)

	for b in to_destroy:
		if not b.dead:
			b.fire = 0.0
			b.fire_crews = 0
			_sync_fire_visual(b)
			w.destroy_building(b)

## Human-readable status line for a selected building in hud.gd ("" when intact and idle).
static func hud_status(w: Node, b: Dictionary) -> String:
	if b.get("dead", false) or not b.get("built", false):
		return ""
	var lines := PackedStringArray()
	var fire := float(b.get("fire", 0.0))
	if fire > 0.001:
		var crews := int(b.get("fire_crews", 0))
		var pct := clampi(int(roundf(fire * 100.0)), 1, 100)
		if crews > 0:
			lines.append("ON FIRE (%d%%) — %d Fire Station crew%s extinguishing the blaze." % [pct, crews, "" if crews == 1 else "s"])
		else:
			var st := station_count(w, int(b.owner))
			lines.append("ON FIRE (%d%%) — %s" % [pct, "no Fire Station: flames will spread and destroy light structures." if st == 0 else "all Fire Station crews are busy: build more Fire Stations."])
	else:
		var stg := int(b.get("damage_stage", stage_for_hp(float(b.hp), float(b.max_hp))))
		if stg == 2:
			lines.append("Structurally critical — heavy battle/fire damage.")
		elif stg == 1:
			lines.append("Damaged structure — repair to restore full condition.")
	if str(b.key) == "fireStation":
		var o := int(b.owner)
		var st := station_count(w, o)
		var cap := crew_capacity(w, o)
		var active := burning_of(w, o).size()
		lines.append("Fire Service: %d station%s (%d firefighting crews) · %s" % [st, "" if st == 1 else "s", cap, "all crews standing by." if active == 0 else "%d burning building%s." % [active, "" if active == 1 else "s"]])
	return "\n".join(lines)

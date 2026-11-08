extends Control
## Strategic Map Lenses (Track 2A):
##   Mode 0: Standard view (no tactical tint)
##   Mode 1 (F2): Logistics & Supply — supplied hexes green, cut-off red, single-link bottleneck roads amber
##   Mode 2 (F3): Air Defence & Radar — friendly SAM/AA/radar domes cyan, spotted hostile domes red-orange
##   Mode 3 (F4): Homefront Emergency & Grid — active fires pulsing red, damaged amber, blackouts violet, Fire/Hospital coverage green

const MODE_NONE := 0
const MODE_LOGISTICS := 1
const MODE_AIR_DEFENCE := 2
const MODE_EMERGENCY := 3

const MODE_NAMES := ["Standard", "Supply (F2)", "Air Def (F3)", "Emergency (F4)"]
const MODE_DESCS := [
	"",
	"LENS: LOGISTICS — Green: supplied · Red: cut off · Amber: single-road bottleneck",
	"LENS: AIR DEFENCE — Cyan: friendly SAM/AA cover · Red: spotted hostile AA cover",
	"LENS: HOMEFRONT — Red: active fire · Violet: blackout · Amber: damaged · Green: station cover",
]

var world: Node
var mode := MODE_NONE
var _bar: PanelContainer
var _buttons: Array[Button] = []
var _banner: Label
var _pulse := 0.0
var _bottlenecks: Dictionary = {}   # edge_key -> true
var _bottleneck_timer := 0.0

func setup(world_node: Node, hud_root: Node) -> void:
	world = world_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_toolbar(hud_root)

func _build_toolbar(hud_root: Node) -> void:
	var UI := preload("res://scripts/ui_theme.gd")
	_bar = PanelContainer.new()
	_bar.name = "MapLensBar"
	_bar.anchor_left = 1.0
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -220
	_bar.offset_right = -12
	_bar.offset_top = -252
	_bar.offset_bottom = -224
	_bar.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.13, 0.15, 0.90), Color("3c5e63"), 1, 5, 2.0, 4))
	hud_root.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_child(row)

	var short_labels := ["Map", "Sup", "AA", "Emg"]
	var tips := [
		"Standard battlefield view",
		"Logistics & Supply Lens (F2)",
		"Air Defence & Radar Coverage Lens (F3)",
		"Homefront Emergency, Power & Damage Lens (F4)",
	]
	for i in range(4):
		var b := Button.new()
		b.text = short_labels[i]
		b.tooltip_text = tips[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(42, 22)
		b.add_theme_font_size_override("font_size", 11)
		var idx := i
		b.pressed.connect(func(): set_mode(MODE_NONE if mode == idx and idx != 0 else idx))
		row.add_child(b)
		_buttons.append(b)

	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_left = -270
	_banner.offset_right = 270
	_banner.offset_top = 96
	_banner.offset_bottom = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 13)
	_banner.add_theme_color_override("font_color", Color("f4e7bd"))
	_banner.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.08, 0.95))
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	hud_root.add_child(_banner)
	_sync_buttons()

func set_mode(next_mode: int) -> void:
	mode = clampi(next_mode, 0, 3)
	if mode == MODE_LOGISTICS:
		_recompute_bottlenecks()
	_sync_buttons()
	queue_redraw()
	if world != null and world.get("hud") != null and world.hud != null and world.hud.get("_minimap") != null:
		world.hud._minimap.queue_redraw()

func toggle_mode(target_mode: int) -> void:
	set_mode(MODE_NONE if mode == target_mode else target_mode)

func _sync_buttons() -> void:
	var UI := preload("res://scripts/ui_theme.gd")
	for i in range(_buttons.size()):
		var active := (mode == i)
		var bg := Color("285d63") if active else Color("12292c")
		var border := Color("f0d690") if active else Color("3c5e63")
		_buttons[i].add_theme_stylebox_override("normal", UI.box(bg, border, 1, 3, 1.0, 3))
		_buttons[i].add_theme_stylebox_override("hover", UI.box(bg.lightened(0.12), Color("f0d690"), 1, 3, 1.0, 3))
		_buttons[i].add_theme_stylebox_override("pressed", UI.box(Color("34747b"), Color("f0d690"), 1, 3, 1.0, 3))
		_buttons[i].add_theme_color_override("font_color", Color("fff3cf") if active else Color("b7c9cb"))
	if _banner != null:
		_banner.visible = mode != MODE_NONE
		_banner.text = MODE_DESCS[mode]

func _process(delta: float) -> void:
	if mode == MODE_NONE:
		return
	_pulse += delta / maxf(Engine.time_scale, 0.001)
	_bottleneck_timer -= delta
	if mode == MODE_LOGISTICS and _bottleneck_timer <= 0.0:
		_bottleneck_timer = 2.0
		_recompute_bottlenecks()
	queue_redraw()

## Finds single-point-of-failure supply links whose loss would cut off at least one settlement/district.
func _recompute_bottlenecks() -> void:
	_bottlenecks.clear()
	if world == null or world.get("logistics") == null:
		return
	var logi = world.logistics
	var cap_pos = null
	for b in world.buildings:
		if not b.dead and b.built and int(b.owner) == 0 and b.key == "hq":
			cap_pos = logi.world_hex(b.root.position)
			break
	if cap_pos == null:
		return
	var settlements: Array[Vector2i] = []
	for b in world.buildings:
		if not b.dead and b.built and int(b.owner) == 0 and b.key in ["cityCenter", "villageCenter", "tankFactory", "powerPlant", "nuclearReactor", "samSite", "airfield"]:
			var h: Vector2i = logi.world_hex(b.root.position)
			if h != cap_pos and not (h in settlements):
				settlements.append(h)
	if settlements.is_empty():
		return
	var my_edges := []
	for k in logi.edges.keys():
		var e: Dictionary = logi.edges[k]
		if int(e.owner) == 0 and float(e.hp) > 0.0:
			my_edges.append([k, e])
	for pair in my_edges:
		var skip_key: String = pair[0]
		var reach := _reach_without(logi, cap_pos, skip_key)
		for sh in settlements:
			if logi.reachable.get(0, {}).has(sh) and not reach.has(sh):
				_bottlenecks[skip_key] = true
				break

func _reach_without(logi, start_hex: Vector2i, skip_key: String) -> Dictionary:
	var seen := {start_hex: true}
	var q: Array[Vector2i] = [start_hex]
	var adj := {}
	for k in logi.edges.keys():
		if k == skip_key:
			continue
		var e: Dictionary = logi.edges[k]
		if int(e.owner) == 0 and float(e.hp) > 0.0:
			if not adj.has(e.a): adj[e.a] = []
			if not adj.has(e.b): adj[e.b] = []
			adj[e.a].append(e.b)
			adj[e.b].append(e.a)
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for nb in adj.get(cur, []):
			if not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	return seen

func _draw_world_ring(cam: Camera3D, centre: Vector3, radius: float, fill_col: Color, line_col: Color, steps := 40, line_w := 2.0) -> void:
	var pts := PackedVector2Array()
	var behind := false
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		var wx := centre.x + cos(a) * radius
		var wz := centre.z + sin(a) * radius
		var wy: float = world.height_at(wx, wz) + 0.35
		var p3 := Vector3(wx, wy, wz)
		if cam.is_position_behind(p3):
			behind = true
			break
		pts.append(cam.unproject_position(p3))
	if behind or pts.size() < 3:
		return
	if fill_col.a > 0.005 and pts.size() >= 3:
		var indices := Geometry2D.triangulate_polygon(pts)
		if not indices.is_empty():
			draw_polygon(pts, PackedColorArray([fill_col]))
	pts.append(pts[0])
	draw_polyline(pts, line_col, line_w, true)

func _draw() -> void:
	if mode == MODE_NONE or world == null or world.camera == null:
		return
	var cam: Camera3D = world.camera
	var pulse_a := 0.65 + 0.35 * sin(_pulse * 5.0)
	var fog = world.get("fog")

	if mode == MODE_LOGISTICS:
		var logi = world.get("logistics")
		var hex_r: float = float(logi.radius) if logi != null else 12.0
		for b in world.buildings:
			if b.dead or not b.built or int(b.owner) != 0:
				continue
			var supplied: bool = b.get("supplied", true)
			var col := Color(0.18, 0.85, 0.42) if supplied else Color(0.95, 0.24, 0.20)
			var alpha := 0.16 if supplied else (0.28 * pulse_a)
			_draw_world_ring(cam, b.root.position, hex_r * 0.92, Color(col, alpha), Color(col, 0.85), 6, 2.4)
		if logi != null:
			for k in logi.edges.keys():
				var e: Dictionary = logi.edges[k]
				if int(e.owner) != 0:
					continue
				var pa: Vector3 = logi.hex_center(e.a) + Vector3.UP * 0.6
				var pb: Vector3 = logi.hex_center(e.b) + Vector3.UP * 0.6
				if cam.is_position_behind(pa) or cam.is_position_behind(pb):
					continue
				var sa := cam.unproject_position(pa)
				var sb := cam.unproject_position(pb)
				if float(e.hp) <= 0.0:
					draw_line(sa, sb, Color(0.96, 0.22, 0.18, 0.92 * pulse_a), 4.0, true)
				elif _bottlenecks.has(k):
					draw_line(sa, sb, Color(0.98, 0.72, 0.16, 0.95 * pulse_a), 4.5, true)
				else:
					draw_line(sa, sb, Color(0.24, 0.88, 0.48, 0.65), 2.5, true)

	elif mode == MODE_AIR_DEFENCE:
		for b in world.buildings:
			if b.dead or not b.built:
				continue
			if b.key in ["samSite", "commandCenter", "airfield"]:
				if int(b.owner) != 0 and fog != null and not fog.shows(b):
					continue
				var rad := 95.0 if b.key == "samSite" else (70.0 if b.key == "commandCenter" else 60.0)
				if b.get("blackout", false):
					rad *= 0.70
				var friendly: bool = int(b.owner) == 0 or (world.diplomacy != null and world.diplomacy.allied(0, int(b.owner)))
				var c := Color(0.22, 0.82, 0.98) if friendly else Color(0.96, 0.32, 0.22)
				_draw_world_ring(cam, b.root.position, rad, Color(c, 0.08), Color(c, 0.78), 48, 2.2)
		for u in world.units:
			if u.dead or u.get("stowed", false):
				continue
			if u.key in ["aaVehicle", "samLauncher", "manpads", "laserAD", "irisT", "abmLauncher", "saudiThaad", "hpmVehicle", "shortRangeSAM", "ewVehicle", "aegisCruiser", "type45"]:
				if int(u.owner) != 0 and fog != null and not fog.shows(u):
					continue
				var friendly: bool = int(u.owner) == 0 or (world.diplomacy != null and world.diplomacy.allied(0, int(u.owner)))
				var c := Color(0.26, 0.88, 1.0) if friendly else Color(0.98, 0.36, 0.22)
				_draw_world_ring(cam, u.node.position, maxf(float(u.range), 42.0), Color(c, 0.07), Color(c, 0.75), 44, 2.0)

	elif mode == MODE_EMERGENCY:
		var hex_r: float = float(world.logistics.radius) if world.get("logistics") != null else 12.0
		for b in world.buildings:
			if b.dead or not b.built or int(b.owner) != 0:
				continue
			if b.key == "fireStation" and not world.disabled(b):
				_draw_world_ring(cam, b.root.position, hex_r * sqrt(3.0) * 6.0, Color(0.22, 0.86, 0.52, 0.06), Color(0.22, 0.86, 0.52, 0.65), 44, 1.8)
			elif b.key == "hospital" and not world.disabled(b) and not b.get("blackout", false):
				_draw_world_ring(cam, b.root.position, 95.0, Color(0.25, 0.82, 0.88, 0.05), Color(0.25, 0.82, 0.88, 0.55), 44, 1.6)

			if float(b.get("fire", 0.0)) > 0.01:
				_draw_world_ring(cam, b.root.position, hex_r * 1.02, Color(1.0, 0.22, 0.08, 0.32 * pulse_a), Color(1.0, 0.35, 0.10, 0.95), 6, 3.0)
			elif b.get("blackout", false):
				_draw_world_ring(cam, b.root.position, hex_r * 0.95, Color(0.56, 0.32, 0.96, 0.24), Color(0.68, 0.46, 1.0, 0.88), 6, 2.4)
			elif float(b.hp) < float(b.max_hp) * 0.98:
				_draw_world_ring(cam, b.root.position, hex_r * 0.92, Color(0.96, 0.72, 0.16, 0.20), Color(0.96, 0.76, 0.22, 0.85), 6, 2.2)

## Used by minimap.gd to tint building dots according to the active lens.
func building_minimap_color(b: Dictionary, fallback: Color) -> Color:
	if mode == MODE_NONE:
		return fallback
	if mode == MODE_LOGISTICS and int(b.owner) == 0:
		return Color("2ee06e") if b.get("supplied", true) else Color("ff3b30")
	if mode == MODE_AIR_DEFENCE:
		if b.key in ["samSite", "commandCenter", "airfield"]:
			return Color("3ad8ff") if int(b.owner) == 0 else Color("ff5838")
		return Color(fallback, 0.35)
	if mode == MODE_EMERGENCY and int(b.owner) == 0:
		if float(b.get("fire", 0.0)) > 0.01:
			return Color("ff4418")
		if b.get("blackout", false):
			return Color("9e64ff")
		if float(b.hp) < float(b.max_hp) * 0.98:
			return Color("f8be2c")
		if b.key in ["fireStation", "hospital"]:
			return Color("36e88a")
		return Color(fallback, 0.45)
	return fallback

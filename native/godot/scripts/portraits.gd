extends Node
## Picture cards for the interface, rendered from the game's own 3D models:
## every building, unit, ship and aircraft is posed in a small off-screen
## studio (three-quarter view, key and fill light, soft sky) and captured once
## into a texture. Requests are queued and rendered one per frame; until a
## picture is ready the caller gets null and is told through `portrait_ready`.

signal portrait_ready(key: String, texture: Texture2D)

const SIZE := Vector2i(224, 168)

var world: Node
var _cache := {}
var _queue: Array = []
var _busy := false
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D

func setup(world_node: Node) -> void:
	world = world_node
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb4c0")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	env.environment = e
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color("b9d4ff")
	_viewport.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 30
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)

## The picture for a unit or building key, or null while it is being made.
func get_portrait(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if not key in _queue:
		_queue.append(key)
	if not _busy:
		_render_next()
	return null

func _render_next() -> void:
	if _queue.is_empty() or DisplayServer.get_name() == "headless":
		_busy = false
		return
	_busy = true
	var key: String = _queue.pop_front()
	var model: Node3D = world.display_model(key)
	if model == null:
		_cache[key] = null
		_render_next.call_deferred()
		return
	_stage.add_child(model)
	# Frame it: a three-quarter view from above, sized to its bounds.
	var box: AABB = world.model_bounds(model)
	var centre := box.get_center()  # the model stands at the stage origin
	var radius := maxf(box.size.length() * 0.5, 0.5)
	if world.unit_defs.has(key) and key in world.INFANTRY:
		radius = box.size.y * 0.5  # a figure's arms spread its bounds; frame it by height
		centre.y = box.size.y * 0.5
	var dir := Vector3(0.62, 0.48, 0.62).normalized()
	_camera.position = centre + dir * radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.92
	_camera.look_at(centre, Vector3.UP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_cache[key] = texture
	model.queue_free()
	portrait_ready.emit(key, texture)
	_render_next()

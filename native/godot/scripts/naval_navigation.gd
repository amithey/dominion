extends RefCounted
const STEP := 10.0
const OPEN_SEA := 240.0   ## metres of navigable sea beyond each edge of the map
var world: Node
var grid := AStarGrid2D.new()
var half := 0.0
var open: Array[Vector2i] = []

func setup(w: Node) -> void:
	world = w
	# The sea goes on past the edge of the map: the grid does too, so a ship can
	# always sail round the island even where the land runs up to the map's edge.
	half = float(w.map.mapSize)*0.5 + OPEN_SEA
	var n := floori(half*2/STEP)
	grid.region = Rect2i(0,0,n,n)
	grid.cell_size = Vector2(STEP,STEP)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(n):
		for x in range(n):
			var id := Vector2i(x,z)
			var p := point(id)
			var wet := true
			for offset in [Vector3.ZERO,Vector3(8,0,0),Vector3(-8,0,0),Vector3(0,0,8),Vector3(0,0,-8)]:
				if not w.is_water(p+offset):
					wet = false
			grid.set_point_solid(id,not wet)
			if wet:
				open.append(id)

func point(id: Vector2i) -> Vector3:
	return Vector3(-half+(id.x+0.5)*STEP,0,-half+(id.y+0.5)*STEP)

func nearest(p: Vector3) -> Vector2i:
	var best := Vector2i(-1,-1)
	var d := INF
	for id in open:
		var q := point(id)
		var dist := Vector2(q.x-p.x,q.z-p.z).length_squared()
		if dist<d:
			d = dist
			best = id
	return best

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest(from)
	var b := nearest(to)
	var result := PackedVector3Array()
	if a.x < 0 or b.x < 0:
		return result
	for id in grid.get_id_path(a,b):
		result.append(point(id))
	return result

func move(u: Dictionary, goal: Vector3, delta: float) -> void:
	u.repath -= delta
	if u.path.is_empty() or u.path_goal.distance_to(goal)>8.0:
		if u.repath <= 0:
			u.path = route(u.node.position,goal)
			u.path_goal = goal
			u.repath = 1.0
	if u.path.is_empty():
		u.moving = false
		u.sailing_speed = 0.0
		world.place_on_ground(u,u.node.position)
		return
	while u.path.size()>1 and Vector2(u.path[0].x-u.node.position.x,u.path[0].z-u.node.position.z).length()<6:
		u.path.remove_at(0)
	var to: Vector3 = u.path[0]-u.node.position
	to.y = 0
	if u.path.size()==1 and to.length()<4:
		u.target = null
		u.moving = false
		u.sailing_speed = 0.0
		world.place_on_ground(u,u.node.position)
		return
	var desired := atan2(to.x,to.z)
	var best := desired
	var score := INF
	# Scan all headings instead of giving up when the bow touches shallow water.
	for i in range(24):
		var angle := desired+i*TAU/24
		var dir := Vector3(sin(angle),0,cos(angle))
		if not world.is_water(u.node.position+dir*maxf(5,u.length*0.6)):
			continue
		var cost := absf(angle_difference(desired,angle))+absf(angle_difference(u.heading,angle))*0.15
		if cost < score:
			score = cost
			best = angle
	u.heading = rotate_toward(u.heading,best,delta*0.8)
	var direction := Vector3(sin(u.heading),0,cos(u.heading))
	# Ease into motion, slow during a sharp turn and brake before the final waypoint.
	var alignment := clampf(cos(angle_difference(u.heading,best)),0.15,1.0)
	var cruise: float = u.speed*0.8
	var braking: float = minf(1.0,to.length()/16.0) if u.path.size()==1 else 1.0
	var wanted: float = cruise*alignment*braking if score<INF else 0.0
	u.sailing_speed = move_toward(float(u.get("sailing_speed",0.0)),wanted,cruise*delta*0.6)
	var next: Vector3 = u.node.position+direction*u.sailing_speed*delta
	# Old saves may contain a ship in shallows accepted by the previous mover.
	# Permit only motion toward deeper water until it reaches safe depth again.
	var depth_now: float = world.height_at(u.node.position.x,u.node.position.z)
	var depth_next: float = world.height_at(next.x,next.z)
	var escaping: bool = not world.is_water(u.node.position) and depth_next<depth_now and depth_next<float(world.map.seaLevel)-0.2
	u.moving = score < INF and (world.is_water(next) or escaping) and world.is_water(next+direction*maxf(3,u.length*0.45))
	if not u.moving:
		u.sailing_speed = 0.0
	world.place_on_ground(u,next if u.moving else u.node.position)

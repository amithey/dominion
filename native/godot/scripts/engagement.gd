extends RefCounted
## Limited operations permit local combat without marking nations as at war.
var world: Node
var operations := {} # nation ID -> expiration in match seconds
var incidents := {}
var policy := "limited"

func active(a: int,b: int) -> bool:
	return (a==0 or b==0) and float(operations.get(str(maxi(a,b)),0))>world.game_time

func authorize(id: int, action: Callable) -> void:
	if id<=0 or world.diplomacy.at_war(0,id) or (active(0,id) and policy=="limited"):
		action.call()
		return
	var mode := policy
	world.hud.ask("Attack %s?\n%s\nThis damages relations and may provoke retaliation or escalation. Cancel leaves the order unissued." % [world.diplomacy.name_of(id),"Declare full war" if mode=="war" else "Limited operation: 90 seconds; no automatic declaration of war"],func():
		begin(id,mode)
		action.call(),func():pass,"AUTHORIZE STRIKE")

func begin(id: int, mode: String) -> void:
	if mode=="war":
		world.diplomacy.declare_war(0,id)
		return
	operations[str(id)] = world.game_time+90.0
	incidents[str(id)] = int(incidents.get(str(id),0))+1
	world.diplomacy.change(0,id,-18.0)
	for grid in [world.diplomacy.alliance,world.diplomacy.pact,world.diplomacy.nap]:
		world.diplomacy.set_flag(grid,0,id,false)
	# Strongly hostile governments may escalate repeated operations; a first
	# incident can end with a diplomatic protest instead of compulsory war.
	if int(incidents[str(id)])>=3 and world.diplomacy.rel(0,id)<-65:
		world.diplomacy.declare_war(id,0,"Repeated strikes triggered a declaration of war.")
	else:
		world.hud.notice("Limited operation against %s. Relations -18; local forces may defend themselves." % world.diplomacy.name_of(id))
	world.diplomacy.changed.emit()

func update() -> void:
	for key in operations.keys():
		if world.game_time<float(operations[key]):
			continue
		operations.erase(key)
		var id := int(key)
		if world.diplomacy.at_war(0,id):
			continue
		for u in world.units:
			if u.owner==0 and u.has("ground_attack") and id in affected(u.ground_attack,6.0):
				u.enemy = null
				u.erase("ground_attack")
			if u.enemy!=null and ((u.owner==0 and u.enemy.owner==id) or (u.owner==id and u.enemy.owner==0)):
				u.enemy = null
		world.hud.notice("Limited operation ended. %s has not declared war." % world.diplomacy.name_of(id))

func affected(at: Vector3, radius: float) -> Array[int]:
	var result: Array[int] = []
	for e in world.units+world.buildings:
		if e.dead or e.owner<=0:
			continue
		var distance := Vector2(e.node.position.x-at.x,e.node.position.z-at.z).length()
		if distance <= radius+float(e.get("footprint",0))*0.5 and not e.owner in result:
			result.append(e.owner)
	for e in world.logistics.edges.values():
		if e.owner>0 and world.logistics.world_hex(at) in [e.a,e.b] and not e.owner in result:
			result.append(e.owner)
	return result

func authorize_area(at: Vector3,radius: float,action: Callable) -> void:
	var targets := affected(at,radius)
	targets = targets.filter(func(id):return not world.diplomacy.at_war(0,id) and not (active(0,id) and policy=="limited"))
	if targets.is_empty():
		action.call()
		return
	var names := PackedStringArray()
	for id in targets:
		names.append(world.diplomacy.name_of(id))
	var mode := policy
	world.hud.ask("This strike may hit %s.\n%s\nRelations will deteriorate; retaliation or escalation is possible." % [", ".join(names),"Full war" if mode=="war" else "Limited operation · 90 seconds"],func():
		for id in targets:
			begin(id,mode)
		action.call(),func():pass,"AUTHORIZE STRIKE")

extends RefCounted
## What a shot fired at a nation you are not at war with *means*.
##
## A soldier does not decide the politics. Ordered to fire, he fires; the order
## is carried out. Whether that shot is an incident or the opening of a war is
## settled at the level of the state: the cabinet holds standing orders (the
## doctrine, set in the Diplomacy screen) and every first strike goes to it for
## authorization. Under limited orders the action is deniable — ninety seconds,
## no declaration of war, and their local forces may defend themselves. Under
## full-war orders the same strike comes with a declaration.
##
## The other government then answers, and that answer is its own decision: it
## may contain the incident (a protest and colder relations), answer in kind
## (a limited operation of its own and a punitive column sent at your nearest
## holding), or call it war. Which one it picks depends on how far relations
## had already sunk, how many incidents it has swallowed, how its army compares
## to yours, and how aggressive its government is. When an AI nation opens an
## operation against you, the same three answers come to you as a letter from
## the cabinet.

const WINDOW := 90.0   ## how long an operation stays open, in match seconds

var world: Node
var operations := {}   # nation ID -> expiration in match seconds
var incidents := {}    # nation ID -> how many incidents it has swallowed
var policy := "limited"  # the cabinet's standing orders: "limited" or "war"

func active(a: int,b: int) -> bool:
	return (a==0 or b==0) and float(operations.get(str(maxi(a,b)),0))>world.game_time

## Seconds left in the operation against `id`, or 0.
func left(id: int) -> float:
	return maxf(float(operations.get(str(id),0))-world.game_time,0.0)

func doctrine_text() -> String:
	return "Limited operation · no declaration of war" if policy=="limited" else "Full war · the strike opens a declared war"

# ---------------------------------------------------------------- your orders

## The cabinet asks before the first shot at a nation you are not fighting.
func authorize(id: int, action: Callable) -> void:
	if id<=0 or world.diplomacy.at_war(0,id) or (active(0,id) and policy=="limited"):
		action.call()
		return
	var mode := policy
	world.hud.ask("Attack %s?\n%s\nTheir government answers as it sees fit: a protest, a strike of its own, or war. Cancel leaves the order unissued." % [world.diplomacy.name_of(id),
		"Standing orders: full war. The strike comes with a declaration of war." if mode=="war" else "Standing orders: a limited operation. Ninety seconds, no declaration of war."],func():
		begin(id,mode)
		action.call(),func():pass,"AUTHORIZE STRIKE")

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
	world.hud.ask("This strike may hit %s.\n%s\nRelations will deteriorate, and each government answers for itself." % [", ".join(names),
		"Standing orders: full war." if mode=="war" else "Standing orders: a limited operation · ninety seconds."],func():
		for id in targets:
			begin(id,mode)
		action.call(),func():pass,"AUTHORIZE STRIKE")

## The state acts: war outright, or an operation the other side must answer.
func begin(id: int, mode: String) -> void:
	if mode=="war":
		world.diplomacy.declare_war(0,id)
		return
	open(id)
	incidents[str(id)] = int(incidents.get(str(id),0))+1
	world.diplomacy.change(0,id,-18.0)
	for grid in [world.diplomacy.alliance,world.diplomacy.pact,world.diplomacy.nap]:
		world.diplomacy.set_flag(grid,0,id,false)
	world.hud.notice("Limited operation against %s. Relations -18; their forces may defend themselves." % world.diplomacy.name_of(id))
	answer(id)
	world.diplomacy.changed.emit()

func open(id: int) -> void:
	operations[str(id)] = world.game_time+WINDOW

# ---------------------------------------------------------------- their answer

## The struck government decides for itself what your operation was: an
## incident to be contained, something to answer in kind, or a war.
func answer(id: int) -> void:
	var d: Node = world.diplomacy
	if d.at_war(0,id) or d.defeated(id):
		return
	var swallowed: int = maxi(int(incidents.get(str(id),1))-1,0)
	var pressure: float = float(swallowed)*26.0 - float(d.rel(0,id))*0.45 + float(d.aggression)*45.0
	pressure += float(int(d.army_strength(id))-int(d.army_strength(0)))*2.0 + randf()*30.0
	# A first incident is never called a war: a government protests or answers
	# in kind, and only a grievance it has already swallowed can become one.
	if pressure>=105.0 and swallowed>0:
		d.declare_war(id,0,"%s calls your operation an act of war!" % d.name_of(id))
	elif pressure>=55.0:
		open(id)
		d.change(0,id,-6.0)
		world.hud.notice("%s answers in kind: a limited strike of its own, and no declaration of war." % d.name_of(id))
		punish(id)
	else:
		d.change(0,id,-8.0)
		world.hud.notice("%s protests and contains the incident. Relations sour further." % d.name_of(id))

## The punitive column a government sends when it answers in kind: whatever it
## has to hand, at your nearest holding.
func punish(id: int) -> void:
	if world.ai==null:
		return
	var column: Array = world.units.filter(func(u): return u.owner==id and not u.dead and u.dmg>0.0 and not u.get("naval",false) and not u.get("fly",false))
	if column.is_empty():
		return
	column = column.slice(0,maxi(3,column.size()/2))
	var target = world.ai.nearest_enemy_asset(column[0].node.position,[0])
	if target!=null:
		world.order_move(column,target.root.position,true)

# ---------------------------------------------------------------- their orders

## An AI government opens a limited operation against you. Your cabinet then
## puts the same three answers to you.
func raid(id: int) -> void:
	var d: Node = world.diplomacy
	if id<=0 or d.at_war(0,id) or d.defeated(id) or active(0,id):
		return
	open(id)
	incidents[str(id)] = int(incidents.get(str(id),0))+1
	d.change(0,id,-12.0)
	for grid in [d.alliance,d.pact,d.nap]:
		d.set_flag(grid,0,id,false)
	punish(id)
	world.hud.notice("%s has struck across the border and calls it a limited operation." % d.name_of(id))
	ask_player(id)
	d.changed.emit()

func ask_player(id: int) -> void:
	var d: Node = world.diplomacy
	var name: String = d.name_of(id)
	world.hud.choose("THE CABINET", "%s struck across the border and calls it a limited operation, not a war. Your forces may defend themselves either way. How does the state answer?" % name, [
		["Contain", "", func():
			world.hud.notice("The incident is contained. No declaration of war — this time.")],
		["Answer in kind", "", func():
			open(id)
			d.change(0,id,-10.0)
			d.changed.emit()
			world.hud.notice("A limited operation against %s is authorized. Your forces may engage theirs." % name)
			punish_reply(id)],
		["Declare war", "bad", func():
			d.declare_war(0,id,"You answered %s with a declaration of war." % name)],
	])

## Answering in kind puts the incident on their books too: one more swallowed
## grievance, and a government that runs out of patience declares war itself.
func punish_reply(id: int) -> void:
	incidents[str(id)] = int(incidents.get(str(id),0))+1
	if int(incidents[str(id)])>=4 and world.diplomacy.rel(0,id)<-70.0:
		world.diplomacy.declare_war(id,0,"%s will swallow no more: it has declared war." % world.diplomacy.name_of(id))

# ---------------------------------------------------------------- upkeep

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
		world.hud.notice("The operation against %s is over. Neither state declared war." % world.diplomacy.name_of(id))

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

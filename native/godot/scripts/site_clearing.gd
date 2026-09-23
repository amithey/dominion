extends RefCounted
## What stands on a building site, and clearing it.
##
## Before you build where trees grow or on a natural resource, the game asks:
## clear the site (the trees are felled for a little timber money; a resource
## deposit is destroyed for good) or cancel. A building that belongs on a
## deposit (an extractor or an offshore rig) does not count its own deposit.
## Rival nations and the buildings the map starts with clear trees without
## asking, and never destroy a deposit.

const TIMBER := 4.0   ## money for each tree felled

## Trees (keys into world.tree_parts) and deposits in the way of `key` at `at`.
static func conflicts(w: Node, key: String, at: Vector3) -> Dictionary:
	var reach := radius(w, key)
	var trees := []
	for k in w.tree_parts:
		var p: Vector2 = k
		if not w.tree_parts[k].is_empty() and Vector2(p.x - at.x, p.y - at.z).length() < reach:
			trees.append(k)
	var deposits := []
	var own = null
	if w.building_defs[key].get("onDeposit", false):
		own = w.deposit_near(at, 6.0)
	for d in w.deposits:
		if is_same(d, own) or d.get("gone", false):
			continue
		if Vector2(d.pos.x - at.x, d.pos.z - at.z).length() < reach + 4.0:
			deposits.append(d)
	return {"trees": trees, "deposits": deposits}

## How far round its centre a building clears the ground.
static func radius(w: Node, key: String) -> float:
	return float(w.logistics.radius) * 0.95 if w.is_district(key) else w.footprint_of(key) * 0.6

## Fells the trees (their instances shrink to nothing) and returns how many.
static func fell(w: Node, keys: Array) -> int:
	var felled := 0
	for k in keys:
		var parts: Array = w.tree_parts.get(k, [])
		if parts.is_empty():
			continue
		for part in parts:
			var mm: MultiMesh = part[0]
			var xf: Transform3D = mm.get_instance_transform(part[1])
			mm.set_instance_transform(part[1], Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
		w.tree_parts[k] = []
		felled += 1
	return felled

## Destroys deposits for good.
static func destroy(w: Node, deposits: Array) -> void:
	for d in deposits:
		d.gone = true
		if is_instance_valid(d.node):
			w.effects.debris.scatter(d.pos + Vector3.UP, 10, 6.0, 0.4, Color(0.3, 0.27, 0.22))
			d.node.queue_free()
		for k in range(w.deposits.size()):
			if is_same(w.deposits[k], d):  # by identity: deposit and extractor refer to each other
				w.deposits.remove_at(k)
				break

## The player's build order at a site with something on it: asks first.
## `build` places the building once the ground is clear.
static func ask(w: Node, key: String, at: Vector3, found: Dictionary, build: Callable) -> void:
	var lines := PackedStringArray()
	if not found.trees.is_empty():
		lines.append("%d tree%s will be felled (+$%d timber)." % [found.trees.size(), "" if found.trees.size() == 1 else "s", int(found.trees.size() * TIMBER)])
	for d in found.deposits:
		lines.append("The %s will be destroyed for good: it can never be mined." % d.def.name)
	w.site_answers = [
		["Clear the site and build", "bad" if not found.deposits.is_empty() else "good", func():
			var felled := fell(w, found.trees)
			if felled > 0:
				w.economy.res.money += felled * TIMBER
			destroy(w, found.deposits)
			build.call()],
		["Cancel", "", func(): pass],
	]
	w.hud.choose("CLEARING THE SITE", "Building %s here:\n%s" % [w.building_defs[key].name, "\n".join(lines)], w.site_answers)

## --site-test: the question comes, Cancel leaves the ground alone, Clear
## fells the trees (with timber money) or destroys the deposit and builds;
## a building's own deposit is no conflict; rivals clear trees unasked.
static func run(w: Node) -> void:
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	var keys: Array = w.tree_parts.keys()
	var k0: Vector2 = keys[0]
	var at := Vector3(k0.x, w.height_at(k0.x, k0.y), k0.y)
	var found := conflicts(w, "farm", at)
	if not k0 in found.trees:
		failures.append("a tree on the site was not found")
	var built := [false]
	ask(w, "farm", at, found, func(): built[0] = true)
	if w.site_answers.size() != 2:
		failures.append("no clearing question was asked")
	w.site_answers[1][2].call()  # Cancel
	if built[0] or (w.tree_parts[k0] as Array).is_empty():
		failures.append("Cancel still built or felled")
	var money: float = w.economy.res.money
	ask(w, "farm", at, found, func(): built[0] = true)
	w.site_answers[0][2].call()  # Clear the site and build
	var part: Array = w.tree_parts[k0]
	if not built[0] or not part.is_empty():
		failures.append("clearing did not fell the tree or did not build")
	if w.economy.res.money < money + TIMBER:
		failures.append("no timber money for the felled trees")
	var land: Array = w.deposits.filter(func(d): return not d.get("water", false))
	var d0: Dictionary = land[0]
	var d1: Dictionary = land[1]
	if conflicts(w, "extractor", d1.pos).deposits.any(func(d): return is_same(d, d1)):
		failures.append("an extractor counted its own deposit as in the way")
	var on_deposit := conflicts(w, "farm", d0.pos)
	if not on_deposit.deposits.any(func(d): return is_same(d, d0)):
		failures.append("a farm on a deposit did not notice it")
	ask(w, "farm", d0.pos, on_deposit, func(): pass)
	w.site_answers[0][2].call()
	if w.deposits.any(func(d): return is_same(d, d0)):
		failures.append("the deposit was not destroyed after the player agreed")
	var k1: Vector2 = keys[keys.size() / 2]
	w.place_building("farm", Vector3(k1.x, w.height_at(k1.x, k1.y), k1.y), 1, true)
	if not (w.tree_parts[k1] as Array).is_empty():
		failures.append("a rival building left a tree growing through it")
	if failures.is_empty():
		print("SITE_TEST PASS")
	else:
		for f in failures:
			print("SITE_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)

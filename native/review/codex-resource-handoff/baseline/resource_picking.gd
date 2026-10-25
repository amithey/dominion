extends RefCounted
## Resource markers float above their deposit. At a low camera angle their
## screen position projects onto terrain/water many metres behind the site.
## Prefer an actual marker hit, then let the normal placement rules validate it.
static func marker_at(world: Node, screen: Vector2):
	var best = null
	var nearest := 18.0
	for dep in world.deposits:
		if not is_instance_valid(dep.get("node")): continue
		var icon: Node3D = dep.node.get_node_or_null("Icon")
		if icon == null or not icon.is_visible_in_tree(): continue
		if world.camera.is_position_behind(icon.global_position): continue
		var gap: float = world.camera.unproject_position(icon.global_position).distance_to(screen)
		if gap < nearest:
			nearest = gap
			best = dep
	return best

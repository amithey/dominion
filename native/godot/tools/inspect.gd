extends SceneTree
# Prints the node, mesh, surface-material and animation layout of a model.
# Usage: godot --headless --path native/godot --script res://tools/inspect.gd -- res://assets/Tank.fbx
func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var root: Node = load(path).instantiate()
		print("== ", path)
		dump(root, 0)
		for player in root.find_children("*", "AnimationPlayer", true, false):
			print("  animations: ", player.get_animation_list())
		root.free()
	quit()

func dump(node: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + node.name + " (" + node.get_class() + ")"
	if node is MeshInstance3D and node.mesh:
		var mats := []
		for i in node.mesh.get_surface_count():
			var m = node.mesh.surface_get_material(i)
			mats.append(m.resource_name if m else "none")
		line += " verts~%d mats=%s" % [node.mesh.get_faces().size(), mats]
	print(line)
	for child in node.get_children():
		dump(child, depth + 1)

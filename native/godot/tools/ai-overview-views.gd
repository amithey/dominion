extends SceneTree
## Screenshots of the AI overview page for a nation at the top of the ladder (the United States) and one with a
## low limit (Pakistan), and of the tabs each gets (window needed). Output: res://build/ai-overview-<nation>.png
const Kit := preload("res://tools/audit_kit.gd")
const Registry := preload("res://scripts/nation_registry.gd")
var K
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/%s.png" % name)
func run() -> void:
	K = Kit.new(self, "ai-overview-views")
	var ids: Array = Registry.column("id")
	for id in ["usa", "pakistan"]:
		var w: Node = await K.boot({"map": "island", "players": 4, "nation": ids.find(id), "opening": "light"}, "easy")
		root.size = Vector2i(1600, 900)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		w.menu.close()
		for i in range(30): await process_frame
		var h: Node = w.hud
		if is_instance_valid(h._guide): h._guide.queue_free(); h._guide = null
		h.toggle_panel("diplomacy", true)   # (the side panels are created the first time one opens)
		for i in range(4): await process_frame
		h._panels.defence_tab = "ai"
		w.directorate.ui_tab = "overview"
		h.toggle_panel("defence", true)
		await shot("ai-overview-" + id)
		var tabs := []
		for b in h._side_rows.find_children("*", "Button", true, false):
			if b.toggle_mode: tabs.append(b.text.strip_edges())
		print("AIVIEW ", id, " tabs: ", ", ".join(PackedStringArray(tabs)))
	quit(0)

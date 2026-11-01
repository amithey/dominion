extends SceneTree
## Screenshots of the notification dock (window needed): a busy moment with every kind of message, one card open,
## and the same with the Build catalogue open. Output: res://build/dock-*.png
const Kit := preload("res://tools/audit_kit.gd")
var K
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/%s.png" % name)
func run() -> void:
	K = Kit.new(self, "dock-views")
	var w: Node = await K.boot({"map": "island", "players": 4, "nation": 0, "opening": "light"}, "easy")
	root.size = Vector2i(1600, 900)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	w.menu.close()
	for i in range(30): await process_frame
	var h: Node = w.hud
	if is_instance_valid(h._guide): h._guide.queue_free(); h._guide = null
	h.notice("Intelligence: a missile launch from Iran, impact in 4 minutes.", w.start)
	h.notice("Your barracks is under attack: 40% health left.", w.start + Vector3(10, 0, 5))
	h.notice("China declares war on you.")
	h.notice("Shortage: your army is out of oil and has halted.")
	h.notice("Research complete: Industrial Forestry.")
	h.notice("Barracks complete.")
	h.notice("Not enough Money")
	for i in range(20): await process_frame
	h._dock._open_card(h._dock.entries[h._dock.entries.size() - 2], 999.0)
	await shot("dock-1")
	h.toggle_build()
	await shot("dock-2")
	print("DOCK entries: ", h._dock.entries.size(), " ", h._dock.entries.map(func(e): return e.cat + "/" + e.sev))
	quit(0)

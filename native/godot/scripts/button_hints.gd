extends Node
## Covers buttons created by every native screen, including later-created menu,
## AI and diplomatic widgets. No click behavior, costs or game state are changed.
const Copy := preload("res://scripts/action_copy.gd")
var registered := 0

func _ready() -> void:
	get_tree().node_added.connect(_added)
	_scan(get_tree().root)

func _scan(node: Node) -> void:
	if node is BaseButton: _register(node)
	for child in node.get_children(): _scan(child)

func _added(node: Node) -> void:
	if node is BaseButton: _register.call_deferred(node)

func _register(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta("copy_registered"): return
	button.set_meta("copy_registered", true)
	registered += 1
	button.mouse_entered.connect(func(): update(button))
	button.focus_entered.connect(func(): update(button))
	update(button)

func update(button: BaseButton) -> void:
	if not is_instance_valid(button): return
	var original: String = button.tooltip_text
	if original == str(button.get_meta("copy_output", "")):
		original = str(button.get_meta("copy_original", ""))
	button.set_meta("copy_original", original)
	var current := original
	if button.has_meta("cost") and not bool(button.get_meta("locked", false)):
		var hud: Node = get_parent()
		var price: Dictionary = button.get_meta("cost")
		if hud.economy != null and not hud.economy.can_afford(price):
			current += "\nUnavailable: need " + hud.economy.missing(price) + "."
	button.tooltip_text = Copy.tooltip(button, current)
	button.set_meta("copy_output", button.tooltip_text)

extends PanelContainer
## The beginner's guide: a short card at the start of a campaign that walks a
## new player through the first minutes (build list, a farm, homes, research,
## diplomacy, speed) and ticks each step off as the game shows it done. Skip
## it once and it never returns (user://beginner_guide.cfg).

const UI := preload("res://scripts/ui_theme.gd")
const FILE := "user://beginner_guide.cfg"

var world: Node
var hud: Node
var step := 0
var base := {}
var _title: Label
var _detail: Label
var _count: Label
var _action: Button
var _finished_at := -1.0
var _clock := 0.0
var steps: Array = []

static func wanted() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(FILE) != OK or not bool(cfg.get_value("guide", "done", false))

static func finish() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("guide", "done", true)
	cfg.save(FILE)

func setup(w: Node, h: Node) -> void:
	world = w
	hud = h
	base = {"farm": _count_of("farm", false), "farm_built": _count_of("farm", true), "home": _homes(), "speed": w.game_speed}
	steps = [
		["Open the build list", "Press B, or click Build in the top bar.", func(): return hud.prod_open or world.placing != "" or _count_of("farm", false) > base.farm],
		["Place a Farm", "Pick Farm in the list, then click a green hex in your territory. Food keeps your people and soldiers alive.", func(): return _count_of("farm", false) > base.farm],
		["Let a worker finish it", "Workers build on their own. If the site stays empty, click a worker, then right-click the site.", func(): return _count_of("farm", true) > base.farm_built],
		["Make room for more people", "Build a Cottage Row (or another home) so your population can grow.", func(): return _homes() > base.home],
		["Start a discovery", "Press Y, click a discovery in the Founding Era, then Develop. Research makes everything stronger.", func(): return not world.research.queue.is_empty() or world.research.progress.values().any(func(p): return int(p.stage) > 0 or float(p.work) > 0.0)],
		["Meet your neighbours", "Press G for Diplomacy: see who is friendly, who is cold, and what you can offer.", func(): return hud.side_mode == "diplomacy"],
		["Control the pace", "Press Space to pause, + and - to change speed, or use the buttons beside the era.", func(): return not is_equal_approx(world.game_speed, base.speed)],
	]
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.95), Color(UI.PANEL_LOW, 0.95), UI.GOLD, 10.0, UI.LIFT, Color(0, 0, 0, 0), 0, 8))
	offset_left = 12
	offset_top = 112
	custom_minimum_size = Vector2(330, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var tag := Label.new()
	tag.text = UI.caps("First steps")
	tag.add_theme_color_override("font_color", UI.GOLD)
	tag.add_theme_font_size_override("font_size", 13)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", UI.MUTED)
	head.add_child(_count)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", UI.CREAM)
	col.add_child(_title)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = 300
	_detail.add_theme_font_size_override("font_size", 14)
	_detail.add_theme_color_override("font_color", UI.TEXT)
	col.add_child(_detail)
	_action = Button.new()
	_action.custom_minimum_size.y = 34
	_action.focus_mode = Control.FOCUS_NONE
	_action.pressed.connect(_take_action)
	col.add_child(_action)
	var skip := Button.new()
	skip.text = "Skip the guide"
	skip.focus_mode = Control.FOCUS_NONE
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(close)
	col.add_child(skip)
	_show()

func _count_of(key: String, built_only: bool) -> int:
	var n := 0
	for b in world.buildings:
		if b.owner == 0 and not b.dead and b.key == key and (b.built or not built_only):
			n += 1
	return n

func _homes() -> int:
	return _count_of("cottage", false) + _count_of("housing", false) + _count_of("residential", false) + _count_of("villageCenter", false) + _count_of("cityCenter", false)

func _show() -> void:
	_action.visible = step < steps.size()
	if step >= steps.size():
		_title.text = "You are under way"
		_detail.text = "Next: a Barracks for troops, a Market to trade, a School for research. Your rivals are watching."
		_count.text = ""
		return
	_title.text = steps[step][0]
	_detail.text = steps[step][1]
	_count.text = "%d / %d" % [step + 1, steps.size()]
	_action.text = ["Open Build · B", "Place a Farm", "Assign workers to the Farm", "Place Cottage Row", "Open Research · Y", "Open Diplomacy · G", "Try 2× speed"][step]

## These buttons use the same commands as the normal HUD. Nothing is granted
## or completed for the player, and repeat clicks never toggle a panel shut.
func _take_action() -> void:
	match step:
		0: hud.set_production_open(true)
		1: world.begin_placement("farm")
		2:
			var sites: Array = world.buildings.filter(func(b): return b.owner == 0 and b.key == "farm" and not b.built and not b.dead)
			if not sites.is_empty(): world.resume_construction(sites[-1])
		3: world.begin_placement("cottage")
		4:
			if hud._rs == null or not hud._rs.visible: hud.toggle_research()
		5: hud.toggle_panel("diplomacy", true)
		6: world.set_speed(2.0)

func close() -> void:
	finish()
	queue_free()

func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.4 or world == null:
		return
	_clock = 0.0
	if step < steps.size():
		if steps[step][2].call():
			step += 1
			_show()
			if step >= steps.size():
				_finished_at = Time.get_ticks_msec() / 1000.0
	elif Time.get_ticks_msec() / 1000.0 - _finished_at > 15.0:
		close()

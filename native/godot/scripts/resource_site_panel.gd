extends PanelContainer
## A deposit's usable output and the normal, paid construction path.
const UI := preload("res://scripts/ui_theme.gd")
var world: Node
var deposit: Dictionary
var _title: Label
var _description: Label
var _status: Label
var _action: Button
var _elapsed := 0.0

func setup(w: Node) -> void:
	world = w
	name = "ResourceSite"
	position = Vector2(12, 120)
	custom_minimum_size.x = 410
	z_index = 12
	add_theme_stylebox_override("panel", UI.plate(UI.PANEL_TOP, UI.PANEL_LOW, UI.GOLD, 14.0, UI.LIFT, Color.TRANSPARENT, 0, 8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = "HeaderLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	head.add_child(close)
	_description = paragraph(col)
	_status = paragraph(col)
	_status.add_theme_color_override("font_color", UI.GOLD)
	_action = Button.new()
	_action.name = "ResourceBuildAction"
	_action.pressed.connect(place)
	col.add_child(_action)
	hide()

func paragraph(parent: Control) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 380
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)
	return label

func open(dep: Dictionary) -> void:
	deposit = dep
	show()
	refresh()

func building_key() -> String:
	return "fishingPlatform" if deposit.type == "fish" else ("offshoreRig" if deposit.get("water", false) else "extractor")

func refresh() -> void:
	if deposit.get("gone", false) or not is_instance_valid(deposit.get("node")):
		hide(); return
	if world.get("fog") != null and world.fog.enabled and not world.fog.charted(deposit.pos):
		hide(); return
	var key := building_key()
	var def: Dictionary = world.building_defs[key]
	_title.text = str(deposit.def.name)
	if deposit.type == "fish":
		_description.text = "Fish become FOOD. Put a Fishing Platform on this shoal (inside your own waters), or a Fishing Wharf on a dry coastal hex within 60 m of it.\n\nA supplied wharf produces 2 food/s, plus 2 per nearby shoal (up to 6 food/s before national bonuses). Connect it to your supply network."
		var working := 0
		for b in world.buildings:
			if b.dead or b.owner != 0 or not b.key in ["fishingWharf", "fishingPlatform"] or not b.built: continue
			if b.root.position.distance_to(deposit.pos) <= 60 and b.get("supplied", true): working += 1
		_status.text = "%d supplied fishing platform(s) or wharf(s) currently use this shoal." % working
	else:
		var output: String = "MONEY (treasury)" if deposit.def.res == "money" else str(deposit.def.res).to_upper()
		_description.text = "Base output: +%.1f %s per second.\n\nBuild %s directly on this deposit, finish construction and connect it to your supply network." % [float(deposit.def.rate), output, str(def.name)]
		if deposit.def.res == "money": _description.text += " Gold and diamonds add spendable money directly to your treasury."
		var mine = deposit.get("extractor")
		_status.text = ("Producing" if mine.built and mine.get("supplied", true) else ("Needs a supply connection" if mine.built else "Construction in progress")) if mine != null and not mine.dead else world.site_problem(key, deposit.pos, 0)
		if _status.text == "": _status.text = "Available: place the extractor on the resource marker."
	_action.text = "Place %s · %s" % [str(def.name), world.hud.cost_text(def.cost)]
	_action.disabled = not world.economy.can_afford(def.cost) or (deposit.get("extractor") != null and not deposit.extractor.dead)
	_action.tooltip_text = "Not enough " + world.economy.missing(def.cost) if not world.economy.can_afford(def.cost) else "Choose the building site; payment occurs when placement is confirmed."

func place() -> void:
	refresh()
	if _action.disabled: return
	world.begin_placement(building_key())
	if world.placing != "":
		world.hud.notice("Click on the fish school to place the Fishing Platform (inside your waters)." if deposit.type == "fish" else "Click this deposit's resource marker to place the extractor. Claim the land first if it is outside your territory.")
		hide()

func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0
		refresh()

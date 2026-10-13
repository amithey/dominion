extends RefCounted
const Data := preload("res://scripts/arsenal_diversity_data.gd")
const Factions := preload("res://scripts/factions.gd")
const Forces := preload("res://scripts/force_catalog.gd")
const Variants := preload("res://scripts/national_variants.gd")
const DOMAINS := {"land": "Land forces", "air": "Aircraft", "sea": "Maritime", "fires": "Fires & air defence", "support": "Sustainment", "limits": "Evidence limits"}

static func paragraph(hud: Node, parent: Control, text: String, colour: Color) -> void:
	var label: Label = hud._text(text, 15, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)

static func draw(panel: RefCounted) -> void:
	var hud: Node = panel.hud
	var w: Node = hud.world
	if panel.arsenal_country == "": panel.arsenal_country = Factions.identity(w, 0)
	var id: String = panel.arsenal_country
	var picker := OptionButton.new()
	picker.name = "ArsenalCountry"
	picker.add_theme_font_size_override("font_size", 16)
	picker.custom_minimum_size.y = 38
	for i in range(Factions.IDS.size()):
		picker.add_item(Factions.NAMES[i], i)
		if Factions.IDS[i] == id: picker.select(i)
	picker.item_selected.connect(func(index: int):
		panel.arsenal_country = Factions.IDS[index]
		hud.refresh_side())
	hud._side_rows.add_child(picker)
	var dossier: Dictionary = Data.PROFILES.get(id, {})
	if dossier.is_empty(): return
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 5)
	hud._side_rows.add_child(tabs)
	for domain: String in DOMAINS:
		var picked: String = domain
		var b: Button = hud._button(tabs, DOMAINS[domain], func():
			panel.arsenal_domain = picked
			hud.refresh_side()
			return "")
		b.toggle_mode = true
		b.button_pressed = panel.arsenal_domain == domain
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text(DOMAINS[panel.arsenal_domain], 18, hud.UI.CREAM, true))
	paragraph(hud, card, str(dossier[panel.arsenal_domain]), hud.UI.TEXT)
	paragraph(hud, card, "Public evidence only. Representative types, not stock counts. Production represents acquisition and support; prices and performance are game balance.", hud.UI.MUTED)
	var own: bool = id == Factions.identity(w, 0)
	var ix: int = Factions.IDS.find(id)
	if panel.arsenal_domain in ["land", "fires"]:
		var units: VBoxContainer = hud._card()
		units.add_child(hud._text("New researched choices", 18, hud.UI.CREAM, true))
		var count := 0
		for key: String in Data.ROSTER:
			if not Data.ROSTER[key].has(id): continue
			if panel.arsenal_domain == "land" and key != "recoillessTeam": continue
			if panel.arsenal_domain == "fires" and key == "recoillessTeam": continue
			if panel.arsenal_domain in ["air", "sea", "support", "limits"]: continue
			count += 1
			var row: Array = Data.ROSTER[key][id]
			units.add_child(hud._text(str(row[0]), 17, hud.UI.GOLD, true))
			paragraph(hud, units, str(Forces.ROLES[key].desc), hud.UI.TEXT)
			paragraph(hud, units, Data.evidence(key, id), hud.UI.MUTED)
			var def: Dictionary = Forces.ROLES[key]
			var home: String = Forces.HOME[key]
			var facility: String = str(w.building_defs[home].name)
			var need: String = str(def.get("requires", ""))
			var gate: String = "Available without research" if need == "" else "Research: " + str(w.research.discoveries.get(need, {}).get("name", need))
			paragraph(hud, units, "Production: %s. %s. %s" % [facility, gate, "Your country's choice" if own else "Other country's choice"], hud.UI.MUTED)
			if own:
				var existing: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == home and not b.dead and not b.get("constructing", false))
				if not existing.is_empty():
					var building: Dictionary = existing[0]
					hud._button(units, "Open " + facility + " production", func():
						hud.world.cam_focus = building.node.position
						hud.show_building(building)
						return "")
		if count == 0: paragraph(hud, units, "No additional production choice in this category. See Land forces and Fires & air defence for the new units. Orders and uncertain inventories do not unlock production.", hud.UI.MUTED)
	if panel.arsenal_domain in ["land", "air", "sea", "fires"]:
		var existing: VBoxContainer = hud._card()
		existing.add_child(hud._text("Established game roster", 18, hud.UI.CREAM, true))
		paragraph(hud, existing, "Existing game abstractions are listed for comparison; this is not a newly verified real-world inventory.", hud.UI.MUTED)
		var lines := PackedStringArray()
		# Read country names without changing the live world's player identity.
		for key: String in w.unit_defs:
			if not Variants.fields(key, Factions.ARSENALS[ix]): continue
			var def: Dictionary = w.unit_defs[key]
			if not Variants.admits(def.get("nation", ""), Factions.ARSENALS[ix]): continue
			var is_air: bool = bool(def.get("fly", false))
			var is_sea: bool = bool(def.get("naval", false))
			var base: String = preload("res://scripts/additional_factions.gd").base(key)
			var fires: bool = base in ["artillery", "mlrs", "samLauncher", "aaVehicle", "himars", "atgmTeam", "manpads"]
			if panel.arsenal_domain == "air" and not is_air: continue
			if panel.arsenal_domain == "sea" and not is_sea: continue
			if panel.arsenal_domain == "fires" and not fires: continue
			if panel.arsenal_domain == "land" and (is_air or is_sea or fires): continue
			if panel.arsenal_domain in ["support", "limits"]: continue
			var name: String = str(Forces.names(key).get(id, preload("res://scripts/arsenal_catalog.gd").UNIT_NAMES.get(key, {}).get(id, Variants.NAMES.get(key, {}).get(Factions.ARSENALS[ix], def.get("generic", def.name)))))
			lines.append(name)
		paragraph(hud, existing, " · ".join(lines) if not lines.is_empty() else "See the doctrine and evidence notes above.", hud.UI.TEXT)
	var watch: VBoxContainer = hud._card(hud.UI.BAD)
	watch.add_child(hud._text("Not granted by this research", 17, hud.UI.CREAM, true))
	for item: String in dossier.watch: paragraph(hud, watch, item, hud.UI.TEXT)
	var sources: VBoxContainer = hud._card()
	sources.add_child(hud._text("Research sources", 17, hud.UI.CREAM, true))
	for source: String in dossier.sources:
		var link := LinkButton.new()
		link.text = undated(str(Data.SOURCES[source][0]))   # dates stay in the research doc and the link
		link.add_theme_font_size_override("font_size", 14)
		link.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var url: String = Data.SOURCES[source][1]
		link.tooltip_text = url
		link.pressed.connect(func(): OS.shell_open(url))
		sources.add_child(link)

## The game's text names no years (the source's date is in its link and the research doc):
## "Rostec: first Malva delivery (2023; supplier statement)" -> "... (supplier statement)".
static func undated(text: String) -> String:
	return Data.undated(text)

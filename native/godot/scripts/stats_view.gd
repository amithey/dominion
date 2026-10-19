extends RefCounted
## Diplomacy > Statistics: the published figures of every nation as a chart over time and a ranking
## (world_stats.gd). Click a nation in the list to hide or show its line.
const UI := preload("res://scripts/ui_theme.gd")
const Stats := preload("res://scripts/world_stats.gd")

static func draw(panel: RefCounted) -> void:
	var hud: Node = panel.hud
	var w: Node = hud.world
	var S: RefCounted = w.stats
	if S == null:
		return
	if S.series.is_empty():
		S.release()
	var metric: String = panel.stats_metric
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	hud._side_rows.add_child(tabs)
	for m in Stats.METRICS:
		var which: String = m
		var b: Button = hud._button(tabs, Stats.TITLES[m], func():
			panel.stats_metric = which
			hud.refresh_side()
			return "")
		b.toggle_mode = true
		b.button_pressed = m == metric
		b.tooltip_text = Stats.NOTES[m]
	var card: VBoxContainer = hud._card(UI.GOLD)
	card.add_child(hud._text("%s  (%s)" % [Stats.TITLES[metric], Stats.UNITS[metric]], 17, UI.CREAM, true))
	var note: Label = hud._text(Stats.NOTES[metric], 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 440
	card.add_child(note)
	var ids: Array = S.series.keys()
	ids.sort()
	var visible_ids: Array = ids.filter(func(id): return not panel.stats_hidden.get(id, false))
	card.add_child(chart(hud, S, metric, visible_ids, Vector2(470, 230)))
	# The ranking: the legend, the latest figure, the change over two minutes, and the error of an estimate.
	var rank := 0
	for pair in S.ranking(metric):
		var id: int = pair[0]
		rank += 1
		var row: HBoxContainer = hud._row(card, 8)
		var hidden: bool = panel.stats_hidden.get(id, false)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = hud._nation_colour(id) if not hidden else Color(0.4, 0.45, 0.5)
		row.add_child(dot)
		var name: String = "You" if id == 0 else w.diplomacy.name_of(id)
		var label: Label = hud._text("%d.  %s" % [rank, name], 14, (hud._nation_colour(id).lightened(0.35) if not hidden else UI.MUTED), id == 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var c: float = S.change(id, metric)
		var arrow := "▲" if c > 0.005 else ("▼" if c < -0.005 else "–")
		row.add_child(hud._text("%s %d%%" % [arrow, int(roundf(absf(c) * 100.0))], 13, UI.GOOD if c > 0.005 else (UI.BAD if c < -0.005 else UI.MUTED)))
		var value: Label = hud._text(Stats.format(metric, pair[1]) + ("" if id == 0 or not metric in ["military", "infra"] else "  ±%d%%" % int(roundf(S.error(id) * 100.0))), 14, UI.CREAM, true)
		value.custom_minimum_size.x = 120
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		var toggle := Button.new()
		toggle.flat = true
		toggle.text = "hide" if not hidden else "show"
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.pressed.connect(func():
			panel.stats_hidden[id] = not panel.stats_hidden.get(id, false)
			hud.refresh_side())
		row.add_child(toggle)
	if metric in ["military", "infra"]:
		var est: Label = hud._text("Figures for other nations are estimates. Intelligence on a nation (Intel, Dossiers) narrows the error.", 12, UI.MUTED)
		est.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		est.custom_minimum_size.x = 440
		card.add_child(est)

## The chart: one line per nation, you drawn thicker, with the axes labelled.
static func chart(hud: Node, S: RefCounted, metric: String, ids: Array, size: Vector2) -> Control:
	var control := Control.new()
	control.custom_minimum_size = size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = UI.font(500)
	var lines := {}
	var t0 := INF
	var t1 := -INF
	var hi := 0.0
	for id in ids:
		var pts: Array = S.points(id, metric)
		lines[id] = pts
		for p in pts:
			t0 = minf(t0, float(p.t))
			t1 = maxf(t1, float(p.t))
			hi = maxf(hi, float(p.v))
	hi = maxf(hi * 1.08, 1.0)
	var left := 52.0
	var bottom := 22.0
	control.draw.connect(func():
		control.draw_style_box(UI.box(Color("0b1b29"), Color("36516b"), 1, 4, 0.0), Rect2(Vector2.ZERO, size))
		var plot := Rect2(left, 8, size.x - left - 10, size.y - bottom - 12)
		for tick in range(0, 5):
			var y: float = plot.position.y + plot.size.y * float(tick) / 4.0
			control.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.7, 0.8, 0.9, 0.12), 1.0)
			control.draw_string(font, Vector2(4, y + 4), Stats.format(metric, hi * (1.0 - float(tick) / 4.0)), HORIZONTAL_ALIGNMENT_LEFT, left - 8, 11, Color(0.75, 0.82, 0.88, 0.8))
		var span := maxf(t1 - t0, 1.0)
		control.draw_string(font, Vector2(plot.position.x, size.y - 6), "%d min ago" % int(roundf(span / 60.0)) if span >= 60.0 else "start", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.75, 0.82, 0.88, 0.8))
		control.draw_string(font, Vector2(plot.end.x - 40, size.y - 6), "now", HORIZONTAL_ALIGNMENT_RIGHT, 40, 11, Color(0.75, 0.82, 0.88, 0.8))
		for id in ids:
			var pts: Array = lines[id]
			if pts.size() < 2:
				continue
			var line := PackedVector2Array()
			for p in pts:
				line.append(Vector2(plot.position.x + plot.size.x * (float(p.t) - t0) / span, plot.end.y - plot.size.y * float(p.v) / hi))
			var colour: Color = hud._nation_colour(id)
			control.draw_polyline(line, Color(0, 0, 0, 0.5), 4.0 if id == 0 else 3.0, true)
			control.draw_polyline(line, colour.lightened(0.15), 3.0 if id == 0 else 2.0, true)
			control.draw_circle(line[line.size() - 1], 3.5, colour.lightened(0.3)))
	return control

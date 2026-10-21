extends SceneTree
## Audit of every picture (native/ALPHA-1.0-REPORT.md), in a real window: the portrait of each unit and building
## (rendered from its 3D model) and of each missile. A picture fails when it is missing, blank (one colour) or almost
## empty (the model is too small or off-centre in its frame); contact sheets of all of them go to
## res://build/audit-portraits/ (units-N.png, buildings-N.png, missiles.png) to be looked at.
## Table: res://build/audit/portraits.txt     Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tools/audit-portraits.gd
const Kit := preload("res://tools/audit_kit.gd")
var K
var w: Node
func _initialize() -> void: call_deferred("run")

## Share of pixels that differ from the picture's most common colour (a blank frame has none) and the share
## that are not the background corner colour.
func coverage(img: Image) -> float:
	var corner := img.get_pixel(1, 1)
	var other := 0
	var total := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			total += 1
			var c := img.get_pixel(x, y)
			if absf(c.r - corner.r) + absf(c.g - corner.g) + absf(c.b - corner.b) > 0.08:
				other += 1
	return float(other) / maxf(float(total), 1.0)

## True when something other than the background touches the picture's edge (the model is cut by its frame).
func cropped(img: Image) -> bool:
	var corner := img.get_pixel(1, 1)
	var w := img.get_width()
	var h := img.get_height()
	var touching := 0
	for i in range(0, w, 2):
		for y in [1, h - 2]:
			var c := img.get_pixel(i, y)
			if absf(c.r - corner.r) + absf(c.g - corner.g) + absf(c.b - corner.b) > 0.12: touching += 1
	for j in range(0, h, 2):
		for x in [1, w - 2]:
			var c := img.get_pixel(x, j)
			if absf(c.r - corner.r) + absf(c.g - corner.g) + absf(c.b - corner.b) > 0.12: touching += 1
	return touching >= 3

func sheet(keys: Array, textures: Dictionary, name: String, columns := 8, cell := 150) -> void:
	var pages := ceili(keys.size() / float(columns * 6))
	for page in range(maxi(pages, 1)):
		var chunk := keys.slice(page * columns * 6, (page + 1) * columns * 6)
		var rows := ceili(chunk.size() / float(columns))
		var out := Image.create(columns * cell, maxi(rows, 1) * (cell + 18), false, Image.FORMAT_RGBA8)
		out.fill(Color("0b1b29"))
		for i in range(chunk.size()):
			var tex: Texture2D = textures.get(chunk[i])
			if tex == null: continue
			var img := tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(cell - 8, cell - 8, Image.INTERPOLATE_BILINEAR)
			out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % columns) * cell + 4, (i / columns) * (cell + 18) + 4))
		DirAccess.make_dir_recursive_absolute("res://build/audit-portraits")
		out.save_png("res://build/audit-portraits/%s-%d.png" % [name, page + 1])
		var f := FileAccess.open("res://build/audit-portraits/%s-%d.txt" % [name, page + 1], FileAccess.WRITE)
		f.store_string("\n".join(PackedStringArray(chunk.map(func(k): return str(k)))))
		f.close()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("audit-portraits needs a window: run without --headless")
		quit(2)
		return
	K = Kit.new(self, "portraits")
	w = await K.boot({"map": "island", "players": 3, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	var textures := {}
	var keys: Array = []
	for key in w.unit_defs: keys.append(key)
	for key in w.building_defs: keys.append(key)
	keys.sort()
	var pending := {}
	for key in keys:
		var t: Texture2D = w.portraits.get_portrait(key)
		if t != null: textures[key] = t
		else: pending[key] = true
	var guard := 0
	while not pending.is_empty() and guard < 6000:
		await process_frame
		guard += 1
		for key in pending.keys():
			var t: Texture2D = w.portraits.get_portrait(key)
			if t != null:
				textures[key] = t
				pending.erase(key)
	K.ok("portraits", "requested", "%d pictures, %d rendered, %d never arrived" % [keys.size(), textures.size(), pending.size()])
	for key in pending:
		K.fail("portrait", key, "never rendered")
	var unit_keys: Array = []
	var building_keys: Array = []
	for key in keys:
		if w.unit_defs.has(key): unit_keys.append(key)
		elif w.building_defs.has(key): building_keys.append(key)
	for key in textures:
		var img: Image = textures[key].get_image()
		var cov: float = coverage(img)
		var kind := "unit" if w.unit_defs.has(key) else "building"
		if cov < 0.015:
			K.fail("portrait-" + kind, key, "blank or nearly empty: %.1f%% of the frame is anything" % (cov * 100.0))
		elif cov < 0.06:
			K.warn("portrait-" + kind, key, "very small in its frame: %.1f%%" % (cov * 100.0))
		elif kind == "unit" and cov > 0.5 and cropped(img):
			K.warn("portrait-" + kind, key, "cut by its frame (%.0f%% of the frame)" % (cov * 100.0))
		else:
			K.ok("portrait-" + kind, key, "%.0f%% of the frame, %dx%d" % [cov * 100.0, img.get_width(), img.get_height()])
	sheet(unit_keys, textures, "units")
	sheet(building_keys, textures, "buildings")
	# missiles
	var mtex := {}
	var mkeys: Array = []
	for m in w.missiles.types():
		if w.missiles.def_of(m).get("hidden", false): continue
		mkeys.append(m)
		var t: Texture2D = w.portraits.get_portrait("missile:" + m)
		if t == null:
			for i in range(600):
				await process_frame
				t = w.portraits.get_portrait("missile:" + m)
				if t != null: break
		if t == null:
			K.fail("portrait-missile", m, "never rendered")
			continue
		mtex[m] = t
		var cov: float = coverage(t.get_image())
		if cov < 0.01: K.fail("portrait-missile", m, "blank")
		else: K.ok("portrait-missile", m, "%.0f%% of the frame" % (cov * 100.0))
	sheet(mkeys, mtex, "missiles")
	quit(K.finish())

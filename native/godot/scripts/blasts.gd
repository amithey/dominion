extends Node3D
## Explosions by kind (effects.blast -> play): a grenade, a tank shell, a shaped charge, an artillery shell, an aircraft
## bomb, a fuel-air cloud, a burst in the air, a torpedo and a nuclear warhead do not look alike, so each is a *look*: a
## short list of layers played together, some after a delay. The layers are the building blocks:
##
##   flash     a white-hot flash at the point of burst            light     the light it throws on the ground around
##   book      a filmed sheet (effects.BOOKS: the ground burst, the air burst, the fireball, the smoke column, a puff,
##             the dust of an impact, a splash), any size, shape and tint
##   fire      tongues of fire: filmed fireballs round the point of burst (glowing particles on Low)
##   smoke     what is left: soft smoke, dust or vapour that rises, spreads and thins, tinted by its palette, with a film
##   sparks    a shower of sparks                                 streaks   fragments flying out, drawn as streaks
##   dirt      a fountain of earth and clods thrown from the hole dust      a low ring of dust rolling out along the ground
##   dome      the pressure wave of a big burst, a thin shell     ring      the shock front along the ground
##   scorch    the burnt mark on the ground                       embers    glowing embers drifting down
##   fires     patches of ground left burning                     water     a column of white water and spray
##   pops      many small bursts scattered over an area (a look of their own, at random moments)
##   sound, shake, mushroom (the nuclear cloud), emp (a pulse), classic (the old explosion)
##
## A munition's profile names its look (firepower.gd: `look`) and its `fx` is the size. Whether it leaves a crater is
## the profile's to say (`crater`), not the look's: a burst on the ground with a crater gets one whatever it looks like.
## A new weapon takes a look that exists or adds a row to LOOKS; tools/explosion-view.gd films every look and
## tools/explosion-check.gd checks them.
##
## Lengths are for size 1 and grow with the size (as size^0.85, like the old blast). "Ground" layers are skipped for a
## burst in the air or at sea; a burst at the sea's surface throws up water whatever its look.

var fx: Node   # effects.gd: the shared particle materials, lights, films, debris and sound

const GROUND := ["dirt", "dust", "ring", "scorch", "fires"]
## Every layer a look may use (tools/explosion-check.gd fails on any other).
const LAYERS := ["flash", "light", "book", "fire", "smoke", "sparks", "streaks", "dirt", "dust", "dome", "ring", "scorch", "embers",
	"fires", "water", "pops", "sound", "shake", "mushroom", "emp", "classic"]
## Layers a warm-up burst leaves out: what would be heard, felt, left on the ground or shown far and wide.
const NOT_IN_WARMUP := ["light", "scorch", "fires", "pops", "sound", "shake", "mushroom", "emp", "classic"]
## Looks that make their own crater (they are the old explosion, or the mushroom has its own).
const OWN_CRATER := ["classic", "nuclear", "pulse"]

## What smoke and fire are made of: [soot (the smoke's own colour), the film it is shown with, the tint of the fire's
## film]. The films are photographs of grey smoke and orange fire; the tint colours them.
const PALETTES := {
	"he": [Color(0.2, 0.19, 0.18), "smoke", Color(1.0, 1.0, 1.0)],          # high explosive: a quick yellow fire, grey-black smoke
	"fuel": [Color(0.11, 0.1, 0.095), "smoke", Color(1.0, 0.78, 0.55)],     # burning fuel: deep orange, thick black smoke
	"smoke": [Color(0.2, 0.19, 0.18), "smoke", Color(1.0, 1.0, 1.0)],         # dark grey smoke
	"grey": [Color(0.46, 0.45, 0.43), "puff", Color(1.0, 1.0, 1.0)],          # light grey smoke
	"dust": [Color(0.42, 0.35, 0.26), "dust", Color(1.0, 1.0, 1.0)],          # earth thrown up
	"mist": [Color(0.78, 0.79, 0.77), "puff", Color(1.0, 1.0, 1.0)],          # an aerosol cloud, water vapour
	"blue": [Color(0.4, 0.42, 0.46), "puff", Color(0.72, 0.86, 1.15)],        # a hypervelocity strike: white-blue plasma
}

const LOOKS := {
	# A rail gun: the slug arrives as plasma. A blue-white flash, long streaks, a puff of what it struck.
	"railgun": [
		["flash", {"s": 2.6, "col": Color(0.8, 0.9, 1.0)}],
		["light", {"e": 9.0, "life": 0.3, "col": Color(0.6, 0.78, 1.0)}],
		["fire", {"n": 1, "w": 2.8, "life": 0.45, "pal": "blue"}],
		["streaks", {"n": 26, "speed": 1.6, "life": 0.7, "col": Color(0.75, 0.88, 1.0)}],
		["sparks", {"n": 36}],
		["book", {"kind": "dust", "w": 5.2, "life": 1.3}],
		["dirt", {"n": 12, "debris": 8}],
		["smoke", {"pal": "grey", "w": 3.5, "life": 2.4, "n": 5, "delay": 0.15}],
		["ring", {}], ["scorch", {"s": 2.4}],
		["sound", {}], ["shake", {}],
	],
	# A hand grenade, a grenade launcher: a sharp crack, a puff of dust and grey smoke, fragments. Hardly any fire.
	"grenade": [
		["flash", {"s": 1.6}],
		["light", {"e": 6.0, "life": 0.18}],
		["book", {"kind": "dust", "w": 2.8, "life": 0.9}],
		["fire", {"n": 1, "w": 1.3, "life": 0.3}],
		["streaks", {"n": 22, "speed": 1.1, "life": 0.45, "spread": 85.0}],
		["smoke", {"pal": "grey", "w": 3.2, "life": 2.2, "n": 5, "delay": 0.08}],
		["dust", {"n": 10, "reach": 2.2}],
		["scorch", {"s": 2.2}],
		["sound", {"vol": -5.0}], ["shake", {"k": 0.18}],
	],
	# A gun's high-explosive shell on a flat path: the ground burst, a short fireball, earth thrown up, dark smoke.
	"shell": [
		["flash", {"s": 2.2}],
		["light", {}],
		["book", {"kind": "ground", "w": 5.0, "life": 1.7}],
		["fire", {"n": 1, "w": 2.4, "life": 0.5, "up": 0.5}],
		["sparks", {"n": 18}],
		["dirt", {"n": 12, "debris": 8}],
		["smoke", {"pal": "smoke", "w": 4.2, "life": 3.6, "n": 6, "delay": 0.3}],
		["ring", {}], ["scorch", {}],
		["sound", {}], ["shake", {}],
	],
	# A shaped charge (a rocket, an anti-tank missile, an FPV drone's warhead): a white-hot point, a jet of spall
	# thrown back the way it came, thin grey smoke. Little fire and little earth.
	"heat": [
		["flash", {"s": 2.6, "col": Color(1.0, 0.97, 0.9), "life": 0.08}],
		["light", {"e": 12.0, "life": 0.22}],
		["fire", {"n": 1, "w": 2.3, "life": 0.35, "up": 0.4}],
		["book", {"kind": "dust", "w": 2.6, "life": 0.8}],
		["streaks", {"n": 34, "speed": 1.6, "life": 0.4, "spread": 24.0, "dir": "back"}],
		["sparks", {"n": 26}],
		["smoke", {"pal": "grey", "w": 3.2, "life": 2.4, "n": 5, "up": 0.5, "delay": 0.1}],
		["scorch", {"s": 2.4}],
		["sound", {}], ["shake", {"k": 0.2}],
	],
	# A mortar bomb: it comes down steeply, so the earth goes straight up in a tall spout; fragments fly low and wide.
	"mortar": [
		["flash", {"s": 1.8}],
		["light", {"e": 7.0}],
		["book", {"kind": "dust", "w": 3.6, "life": 1.4, "aspect": 1.7}],
		["book", {"kind": "ground", "w": 3.8, "life": 1.4}],
		["dirt", {"n": 20, "h": 1.5, "debris": 10}],
		["streaks", {"n": 24, "speed": 1.2, "life": 0.5, "spread": 88.0}],
		["dust", {"n": 14, "reach": 3.0}],
		["smoke", {"pal": "dust", "w": 4.2, "life": 3.2, "n": 6, "delay": 0.25}],
		["ring", {}], ["scorch", {}],
		["sound", {}], ["shake", {}],
	],
	# A heavy artillery shell: a big ground burst, a tall fountain of earth, fragments, a ring of dust, a column that stands.
	"artillery": [
		["flash", {"s": 3.0}],
		["light", {}],
		["book", {"kind": "ground", "w": 6.6, "life": 2.0}],
		["fire", {"n": 2, "w": 2.4, "life": 0.6, "spread": 0.6, "up": 0.6}],
		["dirt", {"n": 26, "h": 1.7, "debris": 14}],
		["streaks", {"n": 30, "speed": 1.4, "life": 0.6, "spread": 82.0}],
		["dust", {"n": 22, "reach": 4.5}],
		["smoke", {"pal": "smoke", "w": 6.0, "life": 5.0, "n": 10, "delay": 0.35}],
		["ring", {}], ["scorch", {}],
		["sound", {}], ["shake", {}],
	],
	# Rockets with a high-explosive head (a salvo, a helicopter's pods): orange fire and black smoke, less earth.
	"rocket": [
		["flash", {"s": 2.0}],
		["light", {}],
		["book", {"kind": "ground", "w": 4.6, "life": 1.6}],
		["fire", {"n": 2, "w": 2.2, "life": 0.6, "spread": 0.5, "up": 0.5, "pal": "fuel"}],
		["sparks", {"n": 22}],
		["streaks", {"n": 12, "speed": 1.0, "life": 0.5}],
		["dust", {"n": 12, "reach": 3.0}],
		["smoke", {"pal": "fuel", "w": 4.8, "life": 4.0, "n": 7, "delay": 0.25}],
		["ring", {}], ["scorch", {}],
		["sound", {}], ["shake", {}],
	],
	# A guided missile's warhead and what is left of its motor: a fireball, burning pieces, black smoke.
	"missile": [
		["flash", {"s": 2.8}],
		["light", {}],
		["book", {"kind": "ground", "w": 5.6, "life": 1.9}],
		["fire", {"n": 3, "w": 2.4, "life": 0.7, "spread": 0.6, "up": 0.6}],
		["streaks", {"n": 20, "speed": 1.3, "life": 0.65}],
		["sparks", {"n": 24}],
		["dirt", {"n": 10, "debris": 8}],
		["smoke", {"pal": "he", "w": 6.0, "life": 4.6, "n": 9, "delay": 0.3}],
		["ring", {}], ["scorch", {}],
		["sound", {}], ["shake", {}],
	],
	# An aircraft bomb, a demolition charge: the biggest conventional burst. The pressure wave shows; the column towers.
	"bomb": [
		["flash", {"s": 4.0}],
		["light", {"e": 12.0}],
		["dome", {"reach": 11.0, "life": 0.34, "strength": 0.25}],
		["book", {"kind": "ground", "w": 8.0, "life": 2.3}],
		["fire", {"n": 4, "w": 3.0, "life": 0.9, "spread": 0.8, "up": 0.8, "stagger": 0.04}],
		["dirt", {"n": 34, "h": 1.9, "debris": 22}],
		["streaks", {"n": 34, "speed": 1.6, "life": 0.75, "spread": 80.0}],
		["dust", {"n": 30, "reach": 6.0}],
		["smoke", {"pal": "he", "w": 9.0, "life": 6.5, "n": 14, "delay": 0.35, "aspect": 1.3}],
		["ring", {}], ["scorch", {}],
		["sound", {}], ["shake", {}],
	],
	# A fuel-air warhead: a pale cloud spreads low and wide, then the whole cloud burns at once and goes on burning;
	# thick black smoke after it.
	"thermobaric": [
		["smoke", {"pal": "mist", "w": 7.0, "life": 0.7, "n": 8, "aspect": 0.45, "rise": 0.1, "density": 0.6}],
		["flash", {"s": 4.5, "delay": 0.25, "col": Color(1.0, 0.86, 0.55)}],
		["light", {"e": 14.0, "life": 0.9, "delay": 0.25}],
		["dome", {"reach": 12.0, "life": 0.4, "strength": 0.3, "delay": 0.27}],
		["book", {"kind": "ground", "w": 9.0, "life": 2.4, "aspect": 0.8, "delay": 0.25}],
		["fire", {"n": 6, "w": 3.0, "life": 1.4, "spread": 1.4, "up": 0.5, "aspect": 0.6, "pal": "fuel", "delay": 0.25, "stagger": 0.025}],
		["dust", {"n": 30, "reach": 6.5, "delay": 0.3}],
		["embers", {"n": 40, "reach": 2.2, "delay": 0.5}],
		["fires", {"n": 4, "reach": 1.8, "life": 9.0, "delay": 0.7}],
		["smoke", {"pal": "fuel", "w": 9.0, "life": 7.0, "n": 14, "delay": 0.8, "aspect": 1.2}],
		["ring", {"delay": 0.27}], ["scorch", {"s": 5.0}],
		["sound", {"delay": 0.25}], ["shake", {"delay": 0.25}],
	],
	# A warhead that bursts in the air beside an aircraft: a flash, a black puff that hangs, fragments every way.
	"flak": [
		["flash", {"s": 2.4}],
		["light", {"e": 7.0, "life": 0.25}],
		["book", {"kind": "air", "w": 3.4, "life": 1.4}],
		["fire", {"n": 1, "w": 1.5, "life": 0.3}],
		["streaks", {"n": 30, "speed": 1.3, "life": 0.5, "dir": "all"}],
		["sparks", {"n": 16}],
		["smoke", {"pal": "smoke", "w": 3.2, "life": 4.0, "n": 6, "rise": 0.15, "delay": 0.05, "film": "puff", "tint": Color(0.2, 0.19, 0.19)}],
		["sound", {"vol": -2.0}], ["shake", {"k": 0.1}],
	],
	# A torpedo under a hull: the sea is thrown up in a tall column, with a dull flash inside it, and spray drifts off.
	"torpedo": [
		["light", {"e": 5.0, "life": 0.3}],
		["fire", {"n": 1, "w": 1.4, "life": 0.3, "pal": "fuel"}],
		["water", {"n": 46, "h": 1.6}],
		["book", {"kind": "splash", "w": 6.5, "life": 2.3, "aspect": 1.6}],
		["smoke", {"pal": "mist", "w": 6.0, "life": 3.2, "n": 6, "delay": 0.45}],
		["sound", {}], ["shake", {}],
	],
	# One bomblet of a cluster warhead (the pops of "cluster").
	"bomblet": [
		["flash", {"s": 1.8}],
		["book", {"kind": "dust", "w": 3.4, "life": 1.0}],
		["fire", {"n": 1, "w": 1.9, "life": 0.3}],
		["sparks", {"n": 8}],
		["scorch", {"s": 2.0}],
	],
	# Bomblets over an area: no single fireball, a crackle of small bursts and a haze of dust over the whole area.
	"cluster": [
		["pops", {"n": 18, "look": "bomblet", "reach": 0.7, "over": 0.9, "size": 0.24}],
		["dust", {"n": 26, "reach": 5.0, "delay": 0.4}],
		["smoke", {"pal": "dust", "w": 6.0, "life": 4.0, "n": 10, "aspect": 0.6, "delay": 0.6}],
		["sound", {}], ["shake", {"k": 0.15}],
	],
	# A penetrator: it goes in with hardly a mark, then the ground heaves from below: earth and dust, little fire.
	"penetrator": [
		["flash", {"s": 1.2}],
		["streaks", {"n": 12, "speed": 0.9, "life": 0.35, "spread": 30.0}],
		["book", {"kind": "dust", "w": 6.5, "life": 2.0, "aspect": 1.3, "delay": 0.35}],
		["dirt", {"n": 40, "h": 1.3, "debris": 26, "delay": 0.35}],
		["dust", {"n": 34, "reach": 5.5, "delay": 0.35}],
		["fire", {"n": 1, "w": 1.6, "life": 0.5, "up": 0.5, "delay": 0.4}],
		["smoke", {"pal": "dust", "w": 7.0, "life": 5.0, "n": 10, "delay": 0.5}],
		["ring", {"delay": 0.35}], ["scorch", {}],
		["sound", {"delay": 0.35}], ["shake", {"delay": 0.35}],
	],
	# A chemical or biological warhead: a small burster charge opens it, and the agent spreads as a pale low cloud
	# (the cloud that lingers and does the harm is wmd.gd's).
	"aerosol": [
		["flash", {"s": 1.2, "col": Color(1.0, 0.9, 0.7)}],
		["fire", {"n": 1, "w": 1.2, "life": 0.3}],
		["smoke", {"pal": "mist", "w": 8.0, "life": 6.0, "n": 10, "aspect": 0.4, "rise": 0.1, "density": 0.5}],
		["dust", {"n": 12, "reach": 3.0}],
		["sound", {"vol": -6.0}], ["shake", {"k": 0.08}],
	],
	# A nuclear burst: the fireball and the cloud are effects.mushroom(); a blinding flash and the pressure wave go with it.
	"nuclear": [
		["flash", {"s": 9.0, "life": 0.35, "col": Color(1.0, 1.0, 0.96)}],
		["dome", {"reach": 16.0, "life": 0.9, "strength": 0.35}],
		["classic", {}],
		["mushroom", {}],
		["dust", {"n": 40, "reach": 9.0, "delay": 0.3}],
	],
	# A pulse: no fire at all.
	"pulse": [["emp", {}]],
	# The explosion as it was before looks (a burst that names no look of its own).
	"classic": [["classic", {}]],
}

var _dome_mesh: SphereMesh
var _streak_mesh: BoxMesh
var _streak_mat: StandardMaterial3D
var _streaks := {}        # "axis:spread:speed" -> ParticleProcessMaterial
var _smokes := {}         # "palette:rise:density" -> ParticleProcessMaterial
var _dust: ParticleProcessMaterial
var _dust_mesh: QuadMesh
var _embers: ParticleProcessMaterial
var _spray: ParticleProcessMaterial
var _spray_mesh: QuadMesh
var _live: Array[Dictionary] = []     # the pressure waves this node animates
var _wait: Array[Dictionary] = []     # layers that play after a delay: {t, call}
var played := {}                      # look -> how many times it was played (tests)

func setup(effects: Node) -> void:
	fx = effects
	var dome_mat := ShaderMaterial.new()
	dome_mat.shader = preload("res://shaders/fx_shockdome.gdshader")
	_dome_mesh = SphereMesh.new()
	_dome_mesh.radius = 1.0
	_dome_mesh.height = 1.0
	_dome_mesh.is_hemisphere = true
	_dome_mesh.radial_segments = 28
	_dome_mesh.rings = 8
	_dome_mesh.material = dome_mat
	# Fragments: a thin bright bar laid along its own flight, so it reads as a streak from any side.
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_mat.vertex_color_use_as_albedo = true
	_streak_mesh = BoxMesh.new()
	_streak_mesh.size = Vector3(0.07, 1.1, 0.07)
	_streak_mesh.material = _streak_mat
	# Dust rolling out along the ground: thrown flat in every direction, slowing fast, hanging.
	_dust = fx._particle_material(Vector3.RIGHT, 180.0, 5.0, 9.0, Vector3(0, 0.25, 0), 3.2,
		[Color(0.45, 0.39, 0.31, 0.0), Color(0.45, 0.39, 0.31, 0.32), Color(0.52, 0.47, 0.4, 0.18), Color(0.56, 0.52, 0.46, 0.0)],
		[0.0, 0.12, 0.55, 1.0], 1.6, 2.8, [0.6, 1.6, 2.8])
	_dust.flatness = 1.0
	_dust_mesh = fx._quad(2.2, fx._billboard(fx.cloud_texture(), false, true))
	_embers = fx._particle_material(Vector3.UP, 60.0, 2.0, 6.0, Vector3(0, -1.6, 0), 1.4,
		[Color(1.0, 0.8, 0.4, 1), Color(1.0, 0.45, 0.1, 1), Color(0.5, 0.1, 0.02, 0)],
		[0.0, 0.6, 1.0], 0.5, 1.1, [1.0, 0.9, 0.5])
	_embers.turbulence_influence_max = 0.5
	_spray = fx._particle_material(Vector3.UP, 16.0, 9.0, 17.0, Vector3(0, -9.8, 0), 0.2,
		[Color(0.95, 0.97, 1.0, 0.0), Color(0.95, 0.97, 1.0, 0.85), Color(0.86, 0.9, 0.95, 0.5), Color(0.8, 0.86, 0.92, 0.0)],
		[0.0, 0.06, 0.6, 1.0], 0.6, 1.3, [0.5, 1.3, 2.0])
	_spray_mesh = fx._quad(1.4, fx._billboard(fx.cloud_texture(), false, false))

## Draws one burst of every look out of sight (below the map) at the start of a match, so the graphics card
## builds each kind of particle and film the first time here, not with a stutter in the first battle.
func warm() -> void:
	for look in LOOKS:
		if not look in ["nuclear", "pulse", "classic"]:
			play(look, Vector3(0, -400, 0), 1.0, {"on_ground": true, "crater": false, "warmup": true})

func has(look: String) -> bool:
	return LOOKS.has(look)

func _low() -> bool:
	return fx.world_ref != null and str(fx.world_ref.get("quality")) == "low"

## Plays `look` at `at` for a burst of `size`. opts: on_ground (default: by the height over the ground), crater
## (default true), dir (the way the round was flying, for what is thrown back), radius (a strategic burst's radius).
func play(look: String, at: Vector3, size: float, opts := {}) -> void:
	if not LOOKS.has(look):
		push_error("blasts: no explosion look '%s' (add it to Blasts.LOOKS)" % look)
		look = "classic"
	var warmup: bool = opts.get("warmup", false)
	if not warmup:
		played[look] = int(played.get(look, 0)) + 1
	var ctx := {"size": size, "g": pow(maxf(size, 0.2), 0.85), "c": clampf(size, 0.4, 4.0), "ground": bool(opts.get("on_ground", true)), "sea": false,
		"crater": bool(opts.get("crater", true)), "dir": Vector3(opts.get("dir", Vector3.ZERO)), "radius": float(opts.get("radius", size * 4.5)),
		"low": _low(), "books": fx.books_on(), "warmup": warmup}
	if fx.world_ref != null and not warmup:
		var floor_y: float = fx.world_ref.height_at(at.x, at.z)
		var sea_y: float = fx.world_ref.map.seaLevel
		if not opts.has("on_ground"):
			ctx.ground = at.y - maxf(floor_y, sea_y) < 1.5 and floor_y >= sea_y - 0.5
		# Over water a burst near the surface throws up the sea, not earth.
		if floor_y < sea_y - 0.5:
			ctx.ground = false
			ctx.sea = at.y < sea_y + 4.0
	if ctx.sea and not look in ["torpedo", "pulse", "classic", "nuclear"]:
		_layer("water", Vector3(at.x, float(fx.world_ref.map.seaLevel), at.z), {"n": 26, "h": 1.0}, ctx)
	for entry in LOOKS[look]:
		var layer: String = entry[0]
		var p: Dictionary = entry[1]
		if layer in GROUND and not ctx.ground:
			continue
		if warmup and layer in NOT_IN_WARMUP:
			continue
		var delay: float = p.get("delay", 0.0)
		if delay > 0.0:
			_wait.append({"t": delay, "call": _layer.bind(layer, at, p, ctx)})
		else:
			_layer(layer, at, p, ctx)
	# The crater is the munition's: a burst on the ground that leaves one gets one, whatever it looks like.
	if ctx.ground and ctx.crater and not look in OWN_CRATER and fx.world_ref != null and fx.world_ref.get("battle_scars") != null:
		fx.world_ref.battle_scars.add_crater(at, size)

func _layer(layer: String, at: Vector3, p: Dictionary, ctx: Dictionary) -> void:
	var size: float = ctx.size
	var g: float = ctx.g
	var c: float = ctx.c
	match layer:
		"flash":
			var flash := MeshInstance3D.new()
			flash.mesh = fx._flash_mesh
			flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flash.scale = Vector3.ONE * float(p.get("s", 2.0)) * g
			if p.has("col"):
				var m: StandardMaterial3D = fx._flash_mesh.material.duplicate()
				m.albedo_color = p.col
				flash.material_override = m
			fx.add_child(flash)
			flash.global_position = at + Vector3.UP * 0.4 * g
			fx._live.append({"node": flash, "age": 0.0, "life": float(p.get("life", 0.1)), "kind": "flash"})
		"light":
			var light := OmniLight3D.new()
			light.light_color = p.get("col", Color(1.0, 0.62, 0.3))
			var energy: float = float(p.get("e", 9.0)) * size
			light.light_energy = energy
			light.omni_range = 10.0 + 8.0 * size
			light.shadow_enabled = false
			fx.add_child(light)
			light.global_position = at + Vector3.UP * size
			fx._live.append({"node": light, "age": 0.0, "life": float(p.get("life", 0.35)) + 0.1 * size, "kind": "light", "energy": energy})
		"book":
			if ctx.books:
				fx.flipbook(str(p.kind), at + Vector3.UP * float(p.get("up", 0.0)) * g, float(p.get("w", 5.0)) * g,
					float(p.get("life", 1.7)) * (1.0 + 0.05 * minf(size, 12.0)), 0.0, p.get("tint", Color.WHITE), false, float(p.get("aspect", 1.0)))
		"fire":
			var n: int = int(p.get("n", 1))
			if ctx.low:
				n = (n + 1) >> 1
			var pal: Array = PALETTES[p.get("pal", "he")]
			for i in range(n):
				# The first tongue of fire is on the point of burst; the others crowd round it.
				var off := Vector3.ZERO
				if i > 0:
					var a := TAU * (float(i) / float(maxi(n - 1, 1))) + randf() * 0.7
					off = Vector3(cos(a), randf_range(-0.1, 0.3), sin(a)) * float(p.get("spread", 0.5)) * g * randf_range(0.7, 1.1)
				var where: Vector3 = at + Vector3.UP * float(p.get("up", 0.4)) * g + off
				var width: float = float(p.get("w", 2.0)) * g * randf_range(0.85, 1.15)
				var life: float = float(p.get("life", 0.6)) * (1.0 + 0.06 * minf(size, 10.0))
				var delay: float = float(p.get("stagger", 0.0)) * i
				if ctx.books:
					fx.flipbook("fireball", where, width, maxf(life * 1.7, 0.45), delay, pal[2], false, float(p.get("aspect", 1.0)))
				elif delay <= 0.0:
					fx._burst(fx._fire, fx._fire_mesh, where, int(10.0 * width), life + 0.3, width * 0.35)
				else:
					_wait.append({"t": delay, "call": fx._burst.bind(fx._fire, fx._fire_mesh, where, int(10.0 * width), life + 0.3, width * 0.35)})
		"smoke":
			var pal: Array = PALETTES[p.get("pal", "smoke")]
			var width: float = float(p.get("w", 4.0)) * g
			var life: float = float(p.get("life", 3.0)) * (1.0 + 0.05 * minf(size, 12.0))
			var aspect: float = p.get("aspect", 1.0)
			var mat := _smoke_for(str(p.get("pal", "smoke")), float(p.get("rise", 1.0)), float(p.get("density", 1.0)))
			var count := int(float(p.get("n", 6)) * minf(c, 2.5) * (0.5 if ctx.low else 1.0))
			# Soft smoke that rises and thins (the particles carry the motion); the film gives it its folds.
			fx._burst(mat, fx._smoke_mesh, at + Vector3.UP * float(p.get("up", 0.5)) * g, count, life, width * 0.22)
			var film: String = p.get("film", pal[1])
			if ctx.books and film != "":
				var tint: Color = p.get("tint", _film_tint(pal, film))
				tint.a = float(p.get("density", 1.0)) * tint.a
				fx.flipbook(film, at, width, life, 0.0, tint, false, aspect)
		"sparks":
			fx._burst(fx._sparks, fx._spark_mesh, at + Vector3.UP * 0.3, int(float(p.get("n", 18)) * c), float(p.get("life", 1.3)), 1.0)
		"streaks":
			var way: String = p.get("dir", "up")
			if not ctx.ground and way == "up":
				way = "all"   # nothing below it to stop the fragments
			var axis := Vector3.UP
			var spread: float = p.get("spread", 75.0)
			if way == "all":
				spread = 180.0
			elif way == "back":
				var d: Vector3 = ctx.dir
				axis = (-Vector3(d.x, 0.0, d.z).normalized() + Vector3.UP * 0.7).normalized() if Vector3(d.x, 0.0, d.z).length() > 0.01 else Vector3.UP
			var k: float = p.get("speed", 1.0)
			var key := "%s:%d:%.2f" % [str(axis.snappedf(0.25)), int(spread), k]
			if not _streaks.has(key):
				var m: ParticleProcessMaterial = fx._particle_material(axis, spread, 13.0 * k, 30.0 * k, Vector3(0, -9.8, 0), 0.5,
					[Color(1.0, 0.95, 0.7, 1), Color(1.0, 0.6, 0.18, 0.9), Color(0.6, 0.15, 0.03, 0)], [0.0, 0.45, 1.0], 0.6, 1.3, [1.0, 0.8, 0.3])
				m.particle_flag_align_y = true
				m.angle_min = 0.0
				m.angle_max = 0.0
				m.angular_velocity_min = 0.0
				m.angular_velocity_max = 0.0
				m.turbulence_enabled = false
				if _streaks.size() > 48:
					_streaks.clear()   # (thrown-back jets come from every bearing; the cache does not grow without end)
				_streaks[key] = m
			var burst: GPUParticles3D = fx._burst(_streaks[key], _streak_mesh, at + Vector3.UP * 0.3, int(float(p.get("n", 16)) * minf(c, 2.5)), float(p.get("life", 0.6)), 0.8 + 0.2 * g)
			if p.has("col"):
				var tinted: StandardMaterial3D = _streak_mat.duplicate()
				tinted.albedo_color = p.col
				burst.material_override = tinted
		"dirt":
			var h: float = p.get("h", 1.0)
			fx._burst(fx._dirt, fx._dirt_mesh, at, int(float(p.get("n", 12)) * minf(c, 3.0)), 1.4 * sqrt(h), size * 0.6 * h)
			fx.debris.scatter(at, int(float(p.get("debris", 8)) * minf(c, 3.0)), (6.0 + 3.0 * size) * sqrt(h), 0.28 + 0.1 * minf(size, 3.0), Color(0.27, 0.22, 0.16))
		"dust":
			fx._burst(_dust, _dust_mesh, at + Vector3.UP * 0.5, int(float(p.get("n", 16)) * minf(c, 2.5) * (0.5 if ctx.low else 1.0)), float(p.get("life", 2.6)), float(p.get("reach", 3.0)) * g / 3.0)
		"dome":
			if ctx.low:
				return
			var dome := MeshInstance3D.new()
			dome.mesh = _dome_mesh
			dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dome.set_instance_shader_parameter("age", 0.0)
			dome.set_instance_shader_parameter("strength", float(p.get("strength", 0.3)))
			dome.set_instance_shader_parameter("tint", p.get("tint", Color(1.0, 0.93, 0.8)))
			add_child(dome)
			dome.global_position = at
			dome.scale = Vector3.ONE * 0.5
			_live.append({"node": dome, "age": 0.0, "life": float(p.get("life", 0.3)) * (1.0 + 0.08 * minf(size, 10.0)), "reach": float(p.get("reach", 8.0)) * g})
		"ring":
			if size < 0.9:
				return
			var shock := MeshInstance3D.new()
			shock.mesh = fx._shock_mesh
			shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fx.add_child(shock)
			shock.global_position = at + Vector3.UP * 0.25
			shock.scale = Vector3.ONE * 0.5
			fx._live.append({"node": shock, "age": 0.0, "life": 0.28 + 0.06 * size, "kind": "shock", "reach": 5.0 + 4.5 * size})
		"scorch":
			var mark := Decal.new()
			mark.texture_albedo = fx._scorch
			var s: float = float(p.get("s", 3.4)) * size
			mark.size = Vector3(s, 4.0, s)
			mark.rotation.y = randf() * TAU
			fx.add_child(mark)
			mark.global_position = at
			fx._live.append({"node": mark, "age": 0.0, "life": 45.0, "kind": "scorch"})
		"embers":
			if not ctx.low:
				var reach: float = float(p.get("reach", 2.0)) * g
				fx._burst(_embers, fx._spark_mesh, at + Vector3.UP * 1.2 * g, int(float(p.get("n", 30)) * minf(c, 2.5)), 2.6, reach / 2.0)
		"fires":
			for i in range(int(p.get("n", 3))):
				var a := randf() * TAU
				var where := at + Vector3(cos(a), 0, sin(a)) * float(p.get("reach", 1.5)) * g * randf_range(0.3, 1.0)
				if fx.world_ref != null:
					where.y = fx.world_ref.height_at(where.x, where.z)
				fx.burn(where, float(p.get("life", 8.0)) * randf_range(0.7, 1.2))
		"water":
			var top: float = p.get("h", 1.0)
			fx._burst(_spray, _spray_mesh, at, int(float(p.get("n", 30)) * minf(c, 2.5)), 1.7 * sqrt(top), (0.6 + 0.5 * g) * top)
			if ctx.books:
				fx.flipbook("splash", at, 5.0 * g, 1.9, 0.0, Color.WHITE, false, top)
		"pops":
			var reach: float = ctx.radius * float(p.get("reach", 0.8))
			for i in range(int(float(p.get("n", 12)) * (0.5 if ctx.low else 1.0))):
				var a := randf() * TAU
				var where := at + Vector3(cos(a), 0, sin(a)) * reach * sqrt(randf())
				if fx.world_ref != null:
					where.y = maxf(fx.world_ref.height_at(where.x, where.z), float(fx.world_ref.map.seaLevel))
				_wait.append({"t": randf() * float(p.get("over", 0.9)), "call": play.bind(str(p.get("look", "bomblet")), where, maxf(0.45, size * float(p.get("size", 0.16))), {"crater": false})})
		"sound":
			if fx.audio:
				fx.audio.play("explosion", at, float(p.get("vol", -4.0 + 3.0 * minf(size, 3.0))), 1.6 + size)
		"shake":
			fx.shake.emit(float(p.get("k", 0.25)) * size, at)
		"mushroom":
			fx.mushroom(at, minf(float(ctx.radius), 70.0))
		"emp":
			fx.emp_flash(at, float(ctx.radius))
		"classic":
			fx.explosion(at, size, ctx.ground, ctx.crater)
		_:
			push_error("blasts: no layer '%s'" % layer)

## The tint that turns a smoke film into a palette's smoke: the films are photographs of grey smoke, so the tint is the
## palette's colour against the film's own grey.
func _film_tint(pal: Array, film: String) -> Color:
	var own: float = {"smoke": 0.22, "puff": 0.62, "dust": 0.5}.get(film, 0.5)
	var soot: Color = pal[0]
	return Color(soot.r / own, soot.g / own, soot.b / own, 1.0)

## Soft smoke of a palette: it rises (by `rise`), swells, and its colour lightens and thins as it ages.
func _smoke_for(palette: String, rise: float, density: float) -> ParticleProcessMaterial:
	var key := "%s:%.2f:%.2f" % [palette, rise, density]
	if _smokes.has(key):
		return _smokes[key]
	var soot: Color = PALETTES[palette][0]
	var aged := Color(minf(soot.r * 1.5 + 0.12, 1.0), minf(soot.g * 1.5 + 0.12, 1.0), minf(soot.b * 1.5 + 0.12, 1.0))
	var m: ParticleProcessMaterial = fx._particle_material(Vector3.UP, 35.0, 0.6 + 1.2 * rise, 1.6 + 2.6 * rise, Vector3(0, 0.9 * rise, 0), 1.3,
		[Color(soot, 0.0), Color(soot, 0.85 * density), Color(aged, 0.5 * density), Color(aged, 0.0)],
		[0.0, 0.08, 0.5, 1.0], 1.0, 2.0, [0.5, 1.6, 3.0])
	_smokes[key] = m
	return m

## Advances the pressure waves and the delayed layers (effects._physics_process calls it).
func step(delta: float) -> void:
	for i in range(_wait.size() - 1, -1, -1):
		var w: Dictionary = _wait[i]
		w.t -= delta
		if w.t <= 0.0:
			_wait.remove_at(i)
			(w.call as Callable).call()
	for i in range(_live.size() - 1, -1, -1):
		var e: Dictionary = _live[i]
		e.age += delta
		var node: MeshInstance3D = e.node
		var k: float = minf(e.age / e.life, 1.0)
		var eased := 1.0 - (1.0 - k) * (1.0 - k)
		node.scale = Vector3.ONE * lerpf(0.5, float(e.reach), eased)
		node.set_instance_shader_parameter("age", k)
		if e.age >= e.life:
			node.queue_free()
			_live.remove_at(i)

## Everything of this node's still playing (tests: nothing is left behind).
func busy() -> int:
	return _live.size() + _wait.size()

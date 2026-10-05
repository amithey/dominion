extends RefCounted
## The space layer. Research and sources: native/SPACE-RESEARCH-2026-10-04.md.
##
## Satellites, launched from a missile silo once Satellite Recon is researched
## (nations without their own launchers buy a launch at +50%; Syria and
## Afghanistan have no space programme):
##   recon     an imaging pass over the nation you watch every 40 s (staggered):
##             the land round its towns is seen through the fog for 12 s, its
##             buildings go on the map, and your intelligence on it grows by 3;
##   nav       a navigation constellation (2 or more): guided weapons +10%
##             accuracy. A nation without its own (GPS, BeiDou, GLONASS, Galileo,
##             NavIC, QZSS) relies on GPS, and loses 10% at war with the US;
##   comms     a communications constellation (2 or more, Starlink-like): your
##             drones are half as easily jammed;
##   warning   early-warning satellites: +5% missile interception each (up to 2).
## Anti-satellite missiles (the United States, China, Russia and India, after
## their discovery Anti-Satellite Weapons): an attack on a nation's satellites,
## an act of war; each kill throws debris into orbit that can destroy anyone's
## satellites, its own launcher's too, until it decays.
## Rivals put satellites up as their technology grows; theirs watch the player.

const Factions := preload("res://scripts/factions.gd")
const KINDS := ["recon", "nav", "comms", "warning"]
const COST := {"recon": {"money": 900, "silicon": 60}, "nav": {"money": 700, "silicon": 50}, "comms": {"money": 600, "silicon": 40}, "warning": {"money": 1000, "silicon": 60}}
const NAMES := {"recon": "Reconnaissance satellite", "nav": "Navigation satellite", "comms": "Communications satellite", "warning": "Early-warning satellite"}
const LAUNCHERS := ["usa", "china", "russia", "eu", "india", "japan", "israel", "iran", "north_korea", "south_korea"]
const NO_SPACE := ["syria", "afghanistan"]
const GNSS := {"usa": "GPS", "china": "BeiDou", "russia": "GLONASS", "eu": "Galileo", "india": "NavIC", "japan": "QZSS"}
const ASAT := ["blue", "red", "russia", "india"]
const ASAT_COST := 1500.0
const PASS_SECONDS := 40.0
const REVEAL_SECONDS := 12.0
const REVEAL_RADIUS := 90.0
const DISCOVERIES := {
	"antiSatellite": {"name": "Anti-Satellite Weapons", "cost": 700, "branch": "strategic", "era": 4, "nation": ASAT,
		"reqDiscovery": "satelliteRecon", "reqBuilding": "missileSilo", "fx": {"asat": 1.0},
		"desc": "A direct-ascent missile that destroys a satellite in orbit (tested by China 2007, the United States 2008, India 2019, Russia 2021). Firing it is an act of war, and its debris threatens every nation's satellites, yours too."},
}

var w: Node
var sats := {}                # owner -> {kind: count}
var watch := {}               # owner -> nation its recon satellites pass over
var debris := 0.0             # 0..100: fragments in orbit
var reveals: Array = []       # the player's recon passes: {at, radius, until}
var _pass := {}               # owner -> time of the next recon pass
var _tick := 0.0
var _ai_tick := 0.0

func _init(world: Node) -> void:
	w = world
	for owner in range(w.map.nations.size()):
		sats[owner] = {"recon": 0, "nav": 0, "comms": 0, "warning": 0}

static func apply(world: Node) -> void:
	var discoveries: Dictionary = world.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)

func ident(owner: int) -> String:
	return Factions.identity(w, owner)

func count(owner: int, kind: String) -> int:
	return int(sats.get(owner, {}).get(kind, 0))

func total(owner: int) -> int:
	var n := 0
	for k in KINDS: n += count(owner, k)
	return n

## Why the player cannot launch `kind` now, or "".
func launch_blocked(kind: String) -> String:
	var id := ident(0)
	if id in NO_SPACE:
		return "No space programme."
	if w.research == null or not w.research.done("satelliteRecon"):
		return "Research Satellite Recon first."
	if id in LAUNCHERS and w.economy.owned("missileSilo") == 0:
		return "Needs a Missile Silo as the launch pad."
	if not w.economy.can_afford(price(kind)):
		return "Costs %s." % w.hud.cost_text(price(kind))
	return ""

func price(kind: String) -> Dictionary:
	var c: Dictionary = COST[kind].duplicate()
	if not ident(0) in LAUNCHERS:
		for r in c: c[r] = ceilf(float(c[r]) * 1.5)   # a launch bought abroad
	return c

func launch(kind: String) -> String:
	var why := launch_blocked(kind)
	if why != "":
		return why
	if not w.economy.pay(price(kind)):
		return "Insufficient resources."
	sats[0][kind] = count(0, kind) + 1
	_rocket(0)
	if kind == "recon" and not watch.has(0):
		watch[0] = _default_watch(0)
	if kind == "recon" and not _pass.has(0):
		_pass[0] = w.game_time + 5.0   # the first pass soon after it reaches orbit
	if w.research != null:
		w.research._recompute()
	var where := "from your launch pad" if ident(0) in LAUNCHERS else "on a launch bought abroad"
	return "%s launched %s: you have %d in orbit." % [NAMES[kind], where, count(0, kind)]

## A rocket climbing from the owner's silo (or capital).
func _rocket(owner: int) -> void:
	var pad = null
	for b in w.buildings:
		if b.owner == owner and not b.dead and b.key == "missileSilo":
			pad = b
	if pad == null:
		for b in w.buildings:
			if b.owner == owner and not b.dead and b.key == "hq":
				pad = b
	if pad == null or w.effects == null:
		return
	var from: Vector3 = pad.root.position + Vector3.UP * 4.0
	w.effects.projectile("missile", from, from + Vector3(8, 160, 4), func(_at): pass)

func _default_watch(owner: int) -> int:
	var d: Node = w.diplomacy
	var enemies: Array = d.enemies_of(owner).filter(func(e): return e != owner)
	if not enemies.is_empty():
		return enemies[0]
	var worst := -1
	for i in range(d.n):
		if i != owner and not d.defeated(i) and (worst < 0 or d.rel(owner, i) < d.rel(owner, worst)):
			worst = i
	return worst

## The accuracy factor of `owner`'s guided weapons: its navigation satellites.
func nav_factor(owner: int) -> float:
	var id := ident(owner)
	var own_system: bool = GNSS.has(id)
	if count(owner, "nav") >= 2:
		return 1.1
	if not own_system:
		var us := -1
		for i in range(w.map.nations.size()):
			if ident(i) == "usa": us = i
		if us >= 0 and us != owner and w.diplomacy.at_war(owner, us):
			return 0.9   # GPS denied
	return 1.0

## How likely jamming is to bring down `owner`'s drones (a factor on the roll).
func jam_factor(owner: int) -> float:
	return 0.5 if count(owner, "comms") >= 2 else 1.0

## The player's satellites as research bonuses (research._recompute).
func bonuses() -> Dictionary:
	var n := mini(count(0, "warning"), 2)
	return {"interceptPct": 0.05 * n} if n > 0 else {}

func update(delta: float) -> void:
	_tick += delta
	_ai_tick += delta
	# Recon passes.
	for owner in sats.keys():
		if count(owner, "recon") <= 0 or w.diplomacy.defeated(owner) and owner > 0:
			continue
		var next: float = float(_pass.get(owner, w.game_time + PASS_SECONDS / count(owner, "recon")))
		if not _pass.has(owner):
			_pass[owner] = next
		elif w.game_time >= next:
			_pass[owner] = w.game_time + PASS_SECONDS / count(owner, "recon")
			_recon_pass(owner)
	for r in reveals.duplicate():
		if w.game_time > float(r.until):
			reveals.erase(r)
	if _tick >= 30.0:
		_tick = 0.0
		_orbit_decay()
	if _ai_tick >= 10.0:
		_ai_tick = 0.0
		_ai_space()

func _recon_pass(owner: int) -> void:
	var target: int = int(watch.get(owner, -1))
	if target < 0 or target == owner or w.diplomacy.defeated(target):
		target = _default_watch(owner)
		watch[owner] = target
	if target < 0:
		return
	var towns: Array = w.buildings.filter(func(b): return b.owner == target and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"])
	if owner == 0:
		for t in towns:
			reveals.append({"at": t.root.position, "radius": REVEAL_RADIUS, "until": w.game_time + REVEAL_SECONDS})
		for b in w.buildings:
			if b.owner == target and not b.dead and towns.any(func(t): return t.root.position.distance_to(b.root.position) < REVEAL_RADIUS):
				b.seen = true
		var e = w.get("espionage")
		if e != null:
			e.intel[target] = minf(100.0, float(e.intel.get(target, 0.0)) + 3.0)
		if w.fog != null:
			w.fog.refresh()
	elif target == 0:
		# A rival's satellite finds the player's buildings round its towns.
		for b in w.buildings:
			if b.owner == 0 and not b.dead and towns.any(func(t): return t.root.position.distance_to(b.root.position) < REVEAL_RADIUS):
				if not b.has("known_by"): b.known_by = {}
				b.known_by[owner] = true

## Debris: every satellite in orbit may be struck; the fragments slowly fall.
func _orbit_decay() -> void:
	if debris <= 0.0:
		return
	for owner in sats.keys():
		for kind in KINDS:
			for i in range(count(owner, kind)):
				if randf() < debris / 1000.0:
					sats[owner][kind] = count(owner, kind) - 1
					if owner == 0:
						w.hud.notice("SPACE: debris in orbit destroyed your %s." % NAMES[kind].to_lower())
	debris = maxf(0.0, debris - 0.5)
	if w.research != null:
		w.research._recompute()

## Why the player cannot fire an anti-satellite missile at `target`, or "".
func asat_blocked(target: int) -> String:
	if not preload("res://scripts/national_arsenal.gd").identity(w, 0) in ASAT:
		return "Only the United States, China, Russia and India have them."
	if w.research == null or not w.research.done("antiSatellite"):
		return "Research Anti-Satellite Weapons first."
	if total(target) == 0:
		return "%s has nothing in orbit." % w.diplomacy.name_of(target)
	if w.economy.res.money < ASAT_COST:
		return "Costs $%d." % int(ASAT_COST)
	return ""

## An anti-satellite missile from `owner` at `target`'s satellites.
func fire_asat(owner: int, target: int, roll := -1.0) -> String:
	if owner == 0:
		var why := asat_blocked(target)
		if why != "":
			return why
		w.economy.pay({"money": ASAT_COST})
	var d: Node = w.diplomacy
	_rocket(owner)
	var hit: bool = (randf() if roll < 0.0 else roll) < 0.85
	var lost := ""
	if hit:
		var kinds: Array = KINDS.filter(func(k): return count(target, k) > 0)
		var kind: String = kinds[randi() % kinds.size()]
		sats[target][kind] = count(target, kind) - 1
		lost = NAMES[kind].to_lower()
		debris = minf(100.0, debris + 12.0)
	if not d.at_war(owner, target):
		d.declare_war(owner, target, "%s shot down a satellite of %s's: an act of war!" % [d.name_of(owner), d.name_of(target)] if hit else "")
	d.change(owner, target, -25.0)
	for other in range(d.n):
		if other != owner and other != target and not d.defeated(other):
			d.change(owner, other, -6.0)   # the world condemns the debris
	if w.research != null:
		w.research._recompute()
	var who: String = "Your" if owner == 0 else d.name_of(owner) + "'s"
	var text := ("SPACE: %s anti-satellite missile destroyed %s's %s. Debris in orbit: %d." % [who, "your" if target == 0 else d.name_of(target), lost, int(debris)]) if hit else ("SPACE: %s anti-satellite missile missed." % who)
	w.hud.notice(text)
	return text

const ORBITAL_NUKE_COST := 3000.0

## Why the player cannot detonate a nuclear weapon in orbit, or "".
func orbital_nuke_blocked() -> String:
	if not preload("res://scripts/cbrn_data.gd").has(w, 0, "nuclearAsat"):
		return "Only Russia is developing one (Cosmos 2553)."
	if w.research == null or not w.research.done("antiSatellite") or not w.research.done("nuclearProgram"):
		return "Research Anti-Satellite Weapons and the Nuclear Program first."
	if w.get("defcon") != null and w.defcon != null and w.defcon.release_blocked() != "":
		return w.defcon.release_blocked()
	if w.economy.res.money < ORBITAL_NUKE_COST:
		return "Costs $%d." % int(ORBITAL_NUKE_COST)
	return ""

## A nuclear weapon detonated in orbit (wmd.orbital_burst): most satellites in
## low orbit are lost, everyone's, the debris lingers, and it breaks the Outer
## Space Treaty of 1967.
func orbital_nuke(owner: int) -> String:
	if owner == 0:
		var why := orbital_nuke_blocked()
		if why != "":
			return why
		w.economy.pay({"money": ORBITAL_NUKE_COST})
	_rocket(owner)
	var lost: int = w.wmd.orbital_burst(owner) if w.get("wmd") != null and w.wmd != null else 0
	return "SPACE: a nuclear detonation in orbit destroyed %d satellites, yours and everyone's." % lost

## Rivals put satellites up with their technology, and the four with
## anti-satellite weapons may use them on a player they are at war with.
func _ai_space() -> void:
	if w.ai == null:
		return
	for n in w.ai.nations:
		var owner: int = int(n.id)
		if n.defeated or ident(owner) in NO_SPACE:
			continue
		var tech: float = w.research.ai_tech(owner)
		if tech < 6.0:
			continue
		var want := {"recon": int(tech / 3.0), "nav": 2 if tech >= 7.0 and GNSS.has(ident(owner)) else 0, "comms": 2 if tech >= 8.0 else 0, "warning": 1 if tech >= 8.0 else 0}
		for kind in want:
			if count(owner, kind) < int(want[kind]) and float(n.money) > 2500.0:
				n.money -= float(COST[kind].money)
				sats[owner][kind] = count(owner, kind) + 1
				break
		if not watch.has(owner) or w.diplomacy.defeated(int(watch[owner])):
			watch[owner] = _default_watch(owner)
		if preload("res://scripts/cbrn_data.gd").has(w, owner, "nuclearAsat") and w.get("defcon") != null and w.defcon != null and w.defcon.existential(owner) and w.diplomacy.at_war(owner, 0) and total(0) >= 4 and randf() < 0.01:
			orbital_nuke(owner)
		if preload("res://scripts/national_arsenal.gd").identity(w, owner) in ASAT and tech >= 8.0 and w.diplomacy.at_war(owner, 0) and total(0) > 0 and float(n.money) > 4000.0 and randf() < 0.02:
			n.money -= ASAT_COST
			fire_asat(owner, 0)

func capture() -> Dictionary:
	var s := {}
	for k in sats: s[str(k)] = sats[k]
	var wt := {}
	for k in watch: wt[str(k)] = watch[k]
	return {"sats": s, "watch": wt, "debris": debris}

func restore(data: Dictionary) -> void:
	for k in data.get("sats", {}):
		var row: Dictionary = data.sats[k]
		sats[int(k)] = {}
		for kind in KINDS: sats[int(k)][kind] = int(row.get(kind, 0))
	watch.clear()
	for k in data.get("watch", {}): watch[int(k)] = int(data.watch[k])
	debris = float(data.get("debris", 0.0))
	if w.research != null:
		w.research._recompute()

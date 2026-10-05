extends RefCounted
## Units that learn from battle. Research: native/STAGE5-RESEARCH-2026-10-05.md.
##
## A unit earns experience from the damage it deals to the enemy, and more for
## each kill (half the victim's health). Its rank follows from experience
## measured against its own health, so a rifle squad and a tank both rank up
## after doing roughly their own weight in damage:
##   Regular   the unit as it leaves the factory
##   Veteran   1x its health dealt:  +10% damage, -7% damage taken
##   Elite     3x:                   +20% damage, -14% damage taken, steadier aim
##   Heroic    6x:                   +30% damage, -20% damage taken, and it
##                                   patches itself up out of combat
## The rival's units rank up the same way. A general's Inspiring trait
## (generals.gd) speeds it up. The experience is saved with the unit.

const RANKS := ["Regular", "Veteran", "Elite", "Heroic"]
const NEED := [0.0, 1.0, 3.0, 6.0]          # experience, in multiples of the unit's health
const DAMAGE := [1.0, 1.1, 1.2, 1.3]
const TAKEN := [1.0, 0.93, 0.86, 0.8]
const AIM := [0.0, 0.02, 0.05, 0.08]        # added to the unit's accuracy
const KILL_SHARE := 0.5                     # a kill adds half the victim's health
const HEAL_PER_SECOND := 0.006              # a Heroic unit, 8 s after its last hit
const CHEVRON := Color("e8c66a")

static func rank(u: Dictionary) -> int:
	return int(u.get("rank", 0))

static func rank_name(u: Dictionary) -> String:
	return RANKS[rank(u)]

static func damage_mult(source: Dictionary) -> float:
	return DAMAGE[rank(source)] if source.has("rank") else 1.0

static func taken_mult(target: Dictionary) -> float:
	return TAKEN[rank(target)] if target.has("rank") else 1.0

static func aim(u: Dictionary) -> float:
	return AIM[rank(u)] if u.has("rank") else 0.0

## Experience still needed for the next rank, or -1 at the top.
static func to_next(u: Dictionary) -> float:
	var r := rank(u)
	if r >= RANKS.size() - 1:
		return -1.0
	return maxf(0.0, NEED[r + 1] * float(u.max_hp) - float(u.get("xp", 0.0)))

## `source` dealt `amount` to `target` (world.damage): experience, and a rank.
static func credit(w: Node, source: Dictionary, target: Dictionary, amount: float) -> void:
	if source.get("dead", true) or source.get("is_building", false) or not source.has("max_hp") or amount <= 0.0:
		return
	if int(source.owner) == int(target.owner):
		return
	var gain: float = minf(amount, float(target.hp) + amount)   # no credit past the victim's last point
	if float(target.hp) <= 0.0 and not target.get("is_building", false):
		gain += float(target.max_hp) * KILL_SHARE
	elif float(target.hp) <= 0.0:
		gain += float(target.max_hp) * KILL_SHARE * 0.3   # a building is worth less than its bulk
	if w.get("generals") != null and w.generals != null:
		gain *= w.generals.xp_mult(source)
		if float(target.hp) <= 0.0 and not target.get("is_building", false):
			w.generals.credit_kill(source)   # the general's record
	add(w, source, gain)

## A saved unit's experience, without the promotion notices.
static func set_xp(u: Dictionary, xp: float) -> void:
	u.xp = xp
	var r := 0
	while r < RANKS.size() - 1 and xp >= NEED[r + 1] * float(u.max_hp):
		r += 1
	u.rank = r

static func add(w: Node, u: Dictionary, gain: float) -> void:
	u.xp = float(u.get("xp", 0.0)) + gain
	var r := rank(u)
	while r < RANKS.size() - 1 and float(u.xp) >= NEED[r + 1] * float(u.max_hp):
		r += 1
	if r > rank(u):
		u.rank = r
		if int(u.owner) == 0 and w.hud != null:
			w.hud.notice("PROMOTED: your %s is now %s (+%d%% damage)." % [w.unit_defs.get(u.key, {}).get("name", u.key), RANKS[r], roundi((DAMAGE[r] - 1.0) * 100.0)])
	elif not u.has("rank"):
		u.rank = r

## Once a second: Heroic units patch themselves up out of combat.
static func update(w: Node, delta: float) -> void:
	for u in w.units:
		if u.dead or rank(u) < 3 or float(u.hp) >= float(u.max_hp):
			continue
		if w.game_time - float(u.get("last_hit", -100.0)) > 8.0:
			u.hp = minf(float(u.max_hp), float(u.hp) + float(u.max_hp) * HEAL_PER_SECOND * delta)

## The player's units by rank: [regular, veteran, elite, heroic].
static func census(w: Node, owner := 0) -> Array:
	var out := [0, 0, 0, 0]
	for u in w.units:
		if not u.dead and int(u.owner) == owner:
			out[rank(u)] += 1
	return out

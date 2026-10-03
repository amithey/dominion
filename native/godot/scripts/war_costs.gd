extends RefCounted
## Operating costs in game units, not real-world dollars or litres.
const SORTIE_SECONDS := 90.0
const GUN := {"tank": 1.2, "heavyTank": 1.6, "apc": 0.25, "aaVehicle": 0.25,
	"gunboat": 0.6, "corvette": 1.0, "destroyer": 1.6}
const INTERCEPT := {"samSite": 5.0, "samLauncher": 5.0, "irisT": 6.0,
	"abmLauncher": 18.0, "saudiThaad": 18.0, "laserAD": 0.35,
	"railgunShip": 2.0, "aegisCruiser": 12.0, "type45": 10.0}
const SALVO := {"bomb": 4.0, "missile": 6.0, "sam": 5.0, "atgm": 3.0,
	"fpv": 1.5, "laser": 0.35, "railgun": 2.0, "hgv": 14.0,
	"guided": 8.0, "thermobaric": 6.0, "brahmos": 12.0, "swarm": 7.0,
	"rockets": 3.0, "rocket": 1.0, "torpedo": 7.0, "shell_arc": 2.0,
	"rocket_salvo": 6.0, "kamikaze": 0.0, "detonate": 0.0}
static func fuel_per_metre(u: Dictionary) -> float:
	if u.get("fly", false): return 0.0 # prepaid bounded sorties
	if u.get("key", "") in ["nuclearSub", "orca", "seaDrone"]: return 0.0
	if u.get("naval", false): return 0.045
	if not u.get("vehicle", false): return 0.0
	var base: String = preload("res://scripts/additional_factions.gd").base(str(u.key))
	return 0.035 if base in ["tank", "heavyTank"] else (0.018 if base in ["apc", "aaVehicle"] else 0.025)
static func shot_cost(u: Dictionary, weapon: String) -> float:
	if weapon != "": return float(SALVO.get(weapon, 1.0))
	var base: String = preload("res://scripts/additional_factions.gd").base(str(u.key))
	return float(GUN.get(base, 1.2 if u.get("vehicle", false) or u.get("naval", false) else 0.08))
static func sortie_fuel(u: Dictionary) -> float:
	return 12.0 if u.key in ["bomber", "raider"] else (4.0 if u.key in ["drone", "akinci"] else 7.0)
static func can_pay(w: Node, owner: int, money: float, oil := 0.0) -> bool:
	if owner == 0:
		return w.economy != null and float(w.economy.res.get("money", 0.0)) >= money and float(w.economy.res.get("oil", 0.0)) >= oil
	if w.ai != null:
		for n in w.ai.nations:
			if int(n.id) == owner: return float(n.money) >= money + oil * 3.0
	return false
static func pay(w: Node, owner: int, money: float, oil := 0.0, kind := "") -> bool:
	if not is_finite(money) or not is_finite(oil) or money < 0.0 or oil < 0.0: return false
	if owner == 0:
		if w.economy == null: return false
		var res: Dictionary = w.economy.res
		if float(res.get("money", 0.0)) < money or float(res.get("oil", 0.0)) < oil: return false
		res.money = maxf(0.0, float(res.get("money", 0.0)) - money)
		res.oil = maxf(0.0, float(res.get("oil", 0.0)) - oil)
		if w.economy.get("military_spending") != null:
			for k in ["money", "oil"]:
				var amount: float = money if k == "money" else oil
				w.economy.military_spending[k] += amount
				w.economy.military_flow[k] += amount
			if kind != "": w.economy.military_spending[kind] = float(w.economy.military_spending.get(kind, 0.0)) + 1.0
		return true
	if w.ai == null: return false
	for n in w.ai.nations:
		if int(n.id) != owner: continue
		var bill := money + oil * 3.0 # same materials conversion as AI.price()
		if float(n.money) < bill: return false
		n.money = maxf(0.0, float(n.money) - bill)
		n.operating_spent = float(n.get("operating_spent", 0.0)) + bill
		return true
	return false
static func blocked(w: Node, u: Dictionary, reason: String) -> void:
	u.operating_shortage = reason
	if int(u.owner) == 0 and w.hud != null and w.economy != null and float(w.economy.operating_notices.get(reason, -30.0)) + 15.0 <= w.game_time:
		w.economy.operating_notices[reason] = w.game_time
		w.hud.notice("Operations paused: %s. Buy supplies in World market or restore income." % reason)
static func travel(w: Node, u: Dictionary, from: Vector3, to: Vector3) -> bool:
	var oil := Vector2(to.x - from.x, to.z - from.z).length() * fuel_per_metre(u)
	if oil <= 0.0: return true
	if not pay(w, int(u.owner), 0.0, oil):
		blocked(w, u, "fuel")
		return false
	u.operating_shortage = ""
	return true
static func shot(w: Node, u: Dictionary, weapon: String) -> bool:
	if not pay(w, int(u.owner), shot_cost(u, weapon), 0.0, "shots"):
		blocked(w, u, "ammunition budget")
		return false
	u.operating_shortage = ""
	return true
static func summary(w: Node) -> String:
	var s: Dictionary = w.economy.military_spending
	return "Military operations: $%.1f spent · %.1f oil used · %d salvos · %d defensive attempts" % [s.money, s.oil, int(s.get("shots", 0)), int(s.get("intercepts", 0))]

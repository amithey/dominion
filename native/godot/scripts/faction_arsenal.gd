extends RefCounted
## National weapons of the five factions Codex added (factions.gd: russia,
## india, japan, turkiye, israel), each after a weapon that nation fields or
## has used in 2025-2026. Like national_arsenal.gd's, only that nation may
## build it (the AI plays them too). A nation's arsenal key comes from
## national_arsenal.identity().
##
##   russia   tos1a        TOS-1A Solntsepyok: a tracked launcher of 24
##                         thermobaric rockets, a short-range area weapon that
##                         bunkers and cover do not stop
##   india    brahmos      BrahMos coastal battery: a Mach 3 cruise missile six
##                         hexes out; none of the 15-19 fired in Operation
##                         Sindoor (May 2025) was reported intercepted
##   japan    aegisCruiser Aegis System Equipped Vessel (laid down July 2025):
##                         a cruiser with SM-3 Block IIA and SM-6 interceptors,
##                         missile defence at sea, and strike missiles
##   turkiye  akinci       Bayraktar Akinci: a heavy armed drone with a long
##                         endurance and precision munitions, from a runway
##   israel   harop        IAI Harop: a loitering munition that hunts air
##                         defence (used against Iran's radars in June 2025)

const NAMES := {"russia": "Russia", "india": "India", "japan": "Japan", "turkiye": "Turkiye", "israel": "Israel"}
const HAROP_PREY := ["samSite", "samLauncher", "aaVehicle", "irisT", "laserAD", "abmLauncher", "manpads", "hpmVehicle", "ewVehicle"]
const HAROP_FACTOR := 3.0   # against air defence and radars

const UNITS := {
	"tos1a": {"name": "TOS-1A Solntsepyok", "nation": ["russia", "iraq"], "hp": 360, "dmg": 60, "range": 40, "cooldown": 20.0, "aggro": 44, "speed": 9,
		"fly": false, "naval": false, "cost": {"money": 780, "iron": 90, "oil": 30}, "trainTime": 24, "pop": 3,
		"requires": "compositeArmor",
		"desc": "Fielded by Russia and Iraq. Thermobaric rocket launcher; short range and a long reload leave it exposed. Combat multipliers are game balance."},
	"brahmos": {"name": "BrahMos Battery", "nation": "india", "hp": 250, "dmg": 1, "range": 60, "cooldown": 22.0, "aggro": 60, "speed": 12,
		"fly": false, "naval": false, "cost": {"money": 950, "iron": 70, "oil": 30, "silicon": 35}, "trainTime": 26, "pop": 3,
		"requires": "guidedMunitions",
		"desc": "Indian BrahMos coastal battery. Supersonic, not a hypersonic glide weapon. Combat range and interception chances are game balance."},
	"aegisCruiser": {"name": "Maya-class Aegis destroyer", "nation": "japan", "hp": 1000, "dmg": 70, "range": 60, "cooldown": 3.0, "aggro": 65, "speed": 10,
		"fly": false, "naval": true, "cost": {"money": 1700, "iron": 170, "oil": 50, "silicon": 70}, "trainTime": 38, "pop": 4,
		"requires": "missileDefence",
		"desc": "Japan only. Missile defence at sea: SM-3 and SM-6 interceptors stop 80% of ballistic and 40% of hypersonic missiles within 250 m, and its strike missiles reach 60 m inland."},
	"akinci": {"name": "Bayraktar Akinci", "nation": "turkiye", "hp": 240, "dmg": 55, "range": 30, "cooldown": 2.4, "aggro": 45, "speed": 14,
		"fly": true, "naval": false, "cost": {"money": 650, "iron": 30, "oil": 20, "silicon": 30}, "trainTime": 20, "pop": 2,
		"requires": "microchips",
		"desc": "Turkiye only. A heavy armed drone: eight precision strikes before it lands to rearm, cheap for its punch, and too big and far off for jammers. Slow: air defence can catch it."},
	"harop": {"name": "Harop", "nation": "israel", "hp": 50, "dmg": 170, "range": 14, "cooldown": 1.0, "aggro": 90, "speed": 18,
		"fly": true, "naval": false, "cost": {"money": 260, "oil": 5, "silicon": 18}, "trainTime": 10, "pop": 1,
		"requires": "droneSwarms",
		"desc": "Israel only. A loitering munition that hunts radars: it seeks out air defence 90 m around and dives on it for triple damage. One use; launched from a canister."},
}

const PROFILES := {
	"tos1a": {"infantry": 1.8, "light": 1.2, "armor": 0.6, "air": 0.0, "naval": 0.3, "building": 1.8},
	"brahmos": {"infantry": 0.3, "light": 0.8, "armor": 1.0, "air": 0.0, "naval": 2.0, "building": 1.5},
	"aegisCruiser": {"infantry": 0.6, "light": 1.0, "armor": 1.0, "air": 1.8, "naval": 1.4, "building": 1.2},
	"akinci": {"infantry": 0.9, "light": 1.3, "armor": 1.3, "air": 0.0, "naval": 0.8, "building": 0.9},
	"harop": {"infantry": 0.3, "light": 1.0, "armor": 0.8, "air": 0.0, "naval": 0.6, "building": 0.8},
}

const TRAINS := {"tankFactory": ["tos1a", "brahmos"], "shipyard": ["aegisCruiser"], "airfield": ["akinci", "harop"]}

## BrahMos: fired only by its battery, never built in a silo.
const MISSILES := {
	"brahmos": {"name": "BrahMos", "dmg": 380, "radius": 8, "speed": 150, "special": "brahmos",
		"desc": "A Mach 3 supersonic cruise missile."},
}

static func apply(w: Node) -> void:
	for key in UNITS:
		w.unit_defs[key] = UNITS[key].duplicate(true)
	for key in PROFILES:
		w.damage_profile[key] = PROFILES[key].duplicate()
	for b in TRAINS:
		if not w.building_defs.has(b):
			continue
		var list: Array = w.building_defs[b].get("trains", [])
		for key in TRAINS[b]:
			if not key in list:
				list.append(key)
		w.building_defs[b].trains = list
	var hex: float = float(w.map.logistics.hexRadius) * sqrt(3.0)
	w.unit_defs.brahmos.range = hex * 6.0
	w.unit_defs.brahmos.aggro = hex * 6.0

## Damage multiplier for the Harop against air defence and radars.
static func harop_factor(target: Dictionary) -> float:
	return HAROP_FACTOR if str(target.get("key", "")) in HAROP_PREY else 1.0

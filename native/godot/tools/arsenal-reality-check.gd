extends SceneTree
## 2026-10-22 audit: nations only field the systems they really have (native/ARSENAL-AUDIT-2026-10-22.md).
var errors: Array[String] = []
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func _initialize() -> void:
	var NV = preload("res://scripts/national_variants.gd")
	for id in ["saudi", "brazil", "indonesia", "egypt", "iraq", "syria", "afghanistan"]:
		check(not NV.fields("himars", id), "%s has no precision long-range rocket launcher" % id)
	for id in ["blue", "red", "russia", "india", "turkiye", "israel", "ukraine", "australia", "pakistan", "north_korea", "france", "uk", "south_korea", "green", "japan", "gold"]:
		check(NV.fields("himars", id), "%s does field precision rocket artillery" % id)
	var names: Dictionary = NV.table("names")["himars"]
	check(names.get("north_korea", "") != "" and not str(names.north_korea).contains("HIMARS"), "North Korea's launcher is not called HIMARS (%s)" % names.get("north_korea", ""))
	check(not str(names.get("france", "HIMARS")).contains("HIMARS") and not str(names.get("pakistan", "HIMARS")).contains("HIMARS"), "France and Pakistan do not field the US HIMARS")
	for id in ["afghanistan", "syria", "iraq", "saudi", "brazil", "egypt", "indonesia", "australia", "pakistan", "south_korea"]:
		check(not NV.fields("ewVehicle", id), "%s has no jammer vehicle in its roster" % id)
	for id in ["afghanistan", "syria", "iraq", "saudi", "brazil", "egypt", "indonesia", "australia"]:
		check(not NV.fields("loiterer", id), "%s fields no loitering munition" % id)
	check(NV.fields("ewVehicle", "russia") and NV.fields("loiterer", "russia"), "Russia keeps its Krasukha and Lancet")
	print("ARSENAL_REALITY ", "PASS" if errors.is_empty() else "FAIL %d" % errors.size())
	quit(0 if errors.is_empty() else 1)

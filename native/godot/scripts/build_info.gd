extends RefCounted
## Which build this is: the numeric version (project.godot config/version, the same one the installer and the
## release gate use) and a display label ("ALPHA") from config/version_label. Shown on the opening screen, in
## the window title, in saves and in the problem report.

static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))

static func label() -> String:
	return str(ProjectSettings.get_setting("application/config/version_label", ""))

## "1.0.0 ALPHA" (or "1.0.0" without a label).
static func full() -> String:
	var l := label()
	return version() + (" " + l if l != "" else "")

static func title() -> String:
	return "DOMINION  %s" % full()

## Numeric parts of a version string: "0.9.101" -> [0, 9, 101].
static func parts(v: String) -> Array:
	var out := []
	for p in v.split("."):
		out.append(int(p))
	while out.size() < 3:
		out.append(0)
	return out

## True when version `a` is older than `b`.
static func older(a: String, b: String) -> bool:
	var pa := parts(a)
	var pb := parts(b)
	for i in range(3):
		if int(pa[i]) != int(pb[i]):
			return int(pa[i]) < int(pb[i])
	return false

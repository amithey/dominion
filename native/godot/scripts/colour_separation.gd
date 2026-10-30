extends RefCounted
## Two nations in one match whose flags are nearly the same colour cannot be told apart on the map, the
## minimap or the health bars (the registry has pairs a few shades apart, e.g. two green flags). When a match
## is set up the player keeps their own colour and each later nation keeps its flag colour unless it is too
## close to one chosen before it: then it takes the nearest colour (smallest turn of hue, then of lightness)
## that is clear of them all. The result depends only on the roster order, so a loaded save gets the same colours.
## The nation's flag colour stays in "flag_color"; nothing identifies a nation by "color" (identity is "id").

## Colour distance ("redmean", close to how the eye separates two flags); below ~60 they read as one colour.
const MIN_GAP := 90.0

static func gap(a: Color, b: Color) -> float:
	var r := (a.r + b.r) * 0.5
	var dr := (a.r - b.r) * 255.0
	var dg := (a.g - b.g) * 255.0
	var db := (a.b - b.b) * 255.0
	return sqrt((2.0 + r) * dr * dr + 4.0 * dg * dg + (3.0 - r) * db * db)

## The distance from `c` to the nearest of nations[0 .. before - 1].
static func nearest(c: Color, nations: Array, before: int) -> float:
	var best := INF
	for j in range(before):
		best = minf(best, gap(c, Color(str(nations[j].color))))
	return best

## Re-colours, in place, any nation closer than MIN_GAP to an earlier one.
static func separate(nations: Array) -> void:
	for i in range(1, nations.size()):
		var flag := Color(str(nations[i].color))
		if nearest(flag, nations, i) >= MIN_GAP:
			continue
		var best := flag
		var best_gap := nearest(flag, nations, i)
		var chosen := false
		# smallest change first: hue turns of 15, -15, 30, -30 ... degrees, each with a few lightness steps
		for turn in range(1, 13):
			for dir in [1, -1]:
				for lift in [0.0, 0.12, -0.12, 0.24, -0.24]:
					var h := fposmod(flag.h + dir * turn * 15.0 / 360.0, 1.0)
					var s := clampf(flag.s if flag.s > 0.35 else 0.55, 0.45, 1.0)
					var v := clampf(flag.v + lift, 0.4, 1.0)
					var candidate := Color.from_hsv(h, s, v)
					var g := nearest(candidate, nations, i)
					if g > best_gap:
						best = candidate
						best_gap = g
					if g >= MIN_GAP:
						chosen = true
						break
				if chosen: break
			if chosen: break
		nations[i]["flag_color"] = str(nations[i].color)
		nations[i]["color"] = "#" + best.to_html(false)

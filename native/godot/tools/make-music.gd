extends SceneTree
## Synthesises the game's music and interface sounds into res://audio/:
##   music_loop.wav   a calm, slow strategic theme (about 96 s, loops cleanly):
##                    a string-like pad over a low drone in D minor
##                    (Dm - Bb - F - C - Gm - Bb - Dm - A), with sparse bell
##                    notes above it; quiet enough to play under a long session
##   ui_click.wav     a soft wooden click for every button
## Built from sines, detuned saws and envelopes: nothing recorded, nothing to
## license. Usage: godot --headless --path native/godot --script res://tools/make-music.gd

const RATE := 22050
const BEAT := 8.0   # seconds a chord lasts
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 1789
	DirAccess.make_dir_recursive_absolute("res://audio")
	save("music_loop", music())
	save("ui_click", click())
	quit()

func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

## A chord's notes (MIDI), lowest first.
const CHORDS := [[50, 57, 62, 65], [46, 58, 62, 65], [41, 57, 60, 65], [48, 55, 60, 64],
	[43, 55, 58, 62], [46, 53, 58, 62], [50, 57, 62, 65], [45, 57, 61, 64],
	[50, 57, 62, 69], [46, 58, 62, 65], [41, 57, 60, 65], [45, 57, 61, 64]]

func music() -> PackedFloat32Array:
	var total := BEAT * CHORDS.size()
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# The pad: each chord swells in and out, overlapping the next by 2 s.
	for c in range(CHORDS.size()):
		var start := c * BEAT
		var notes: Array = CHORDS[c]
		for k in range(notes.size()):
			var f := midi(float(notes[k]) + (0.0 if k == 0 else 12.0))
			var level := 0.05 if k == 0 else 0.032
			for voice in [-0.08, 0.0, 0.07]:
				var ff := f * pow(2.0, voice / 12.0)
				var from := int((start - 1.0) * RATE)
				var to := int((start + BEAT + 2.0) * RATE)
				var phase := rng.randf() * TAU
				for i in range(from, to):
					var t := float(i) / RATE - start
					var env := smoothstep(-1.0, 1.8, t) * (1.0 - smoothstep(BEAT - 0.5, BEAT + 2.0, t))
					if env <= 0.0: continue
					var x := float(i) / RATE
					# A soft, string-like tone: the fundamental and a little of two harmonics.
					var s := sin(TAU * ff * x + phase) + 0.28 * sin(TAU * 2.0 * ff * x + phase) + 0.1 * sin(TAU * 3.0 * ff * x)
					var j := posmod(i, n)
					out[j] += s * env * level / 3.0
	# The drone: D, very low, breathing slowly.
	for i in range(n):
		var x := float(i) / RATE
		out[i] += 0.035 * sin(TAU * midi(38) * x) * (0.75 + 0.25 * sin(TAU * x / 16.0))
	# Bells: a few notes of the chord, high and sparse, each ringing out.
	for c in range(CHORDS.size()):
		var notes: Array = CHORDS[c]
		for b in range(2):
			if rng.randf() < 0.35: continue
			var at := c * BEAT + 1.5 + b * 3.5 + rng.randf() * 1.5
			var f := midi(float(notes[1 + rng.randi() % 3]) + 24.0)
			var from := int(at * RATE)
			for i in range(from, from + int(3.5 * RATE)):
				var t := float(i - from) / RATE
				var env := exp(-t * 1.6) * minf(1.0, t * 80.0)
				out[posmod(i, n)] += 0.03 * env * (sin(TAU * f * t) + 0.35 * sin(TAU * 2.76 * f * t) * exp(-t * 3.0))
	# A gentle low-pass, then normalise to a quiet peak.
	var y := 0.0
	var a := 1.0 - exp(-TAU * 2400.0 / RATE)
	var raw := out.duplicate()
	for i in range(n - RATE, n):   # prime the filter with the loop's end: no click at the seam
		y += a * (raw[i] - y)
	for i in range(n):
		y += a * (raw[i] - y)
		out[i] = y
	var peak := 0.0
	for v in out: peak = maxf(peak, absf(v))
	for i in range(n): out[i] = out[i] / maxf(peak, 0.001) * 0.6
	return out

func click() -> PackedFloat32Array:
	var n := int(0.06 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-t * 90.0)
		out[i] = env * (0.6 * sin(TAU * 1250.0 * t) + 0.4 * sin(TAU * 2600.0 * t) + 0.25 * rng.randf_range(-1.0, 1.0) * exp(-t * 300.0))
	return out

func save(name: String, data: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in range(data.size()):
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if name == "music_loop":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size()
	wav.save_to_wav("res://audio/%s.wav" % name)
	print("wrote audio/%s.wav (%.1f s)" % [name, data.size() / float(RATE)])

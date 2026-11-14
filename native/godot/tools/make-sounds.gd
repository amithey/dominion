extends SceneTree
## Synthesises the game's sound effects and organic ambience loops into res://audio/*.wav.
## No recordings are needed and there is nothing to license: every sound is
## built from filtered noise, swept sines, formant resonances and envelopes.
## Usage: godot --headless --path native/godot --script res://tools/make-sounds.gd

const RATE := 44100
var rng := RandomNumberGenerator.new()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://audio")
	for i in range(3):
		save("rifle_%d" % (i + 1), rifle(i))
	save("mg_burst", mg_burst())
	save("cannon", cannon())
	save("artillery_fire", artillery_fire())
	save("missile_launch", missile_launch())
	for i in range(3):
		save("explosion_%d" % (i + 1), explosion(i))
	save("nuke_blast", nuke_blast())
	for i in range(2):
		save("impact_%d" % (i + 1), impact(i))
	save("siren_short", siren_short())
	save("engine_loop", engine_loop())
	save("tank_loop", tank_loop())
	save("jet_loop", jet_loop())
	save("heli_loop", heli_loop())
	save("ship_loop", ship_loop())
	save("wind_loop", wind_loop())
	save("surf_loop", surf_loop())
	save("amb_nature", amb_nature())
	save("amb_city", amb_city())
	save("amb_battle", amb_battle())
	save("amb_war_room", amb_war_room())
	quit()

# ---------------------------------------------------------------- building blocks

func buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

func noise(seconds: float) -> PackedFloat32Array:
	var b := buffer(seconds)
	for i in range(b.size()):
		b[i] = rng.randf_range(-1.0, 1.0)
	return b

func lowpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	var out := PackedFloat32Array(b)
	for i in range(out.size()):
		y += a * (out[i] - y)
		out[i] = y
	return out

func highpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low := lowpass(b, cutoff)
	var out := PackedFloat32Array(b)
	for i in range(out.size()):
		out[i] -= low[i]
	return out

func bandpass(b: PackedFloat32Array, low_hz: float, high_hz: float) -> PackedFloat32Array:
	return highpass(lowpass(b, high_hz), low_hz)

func add_decaying(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, decay: float, delay := 0.0, attack := 0.0005) -> void:
	var start := int(delay * RATE)
	for i in range(src.size()):
		var j := start + i
		if j >= dst.size():
			break
		var t := float(i) / RATE
		dst[j] += src[i] * gain * exp(-t / decay) * minf(1.0, t / attack)

func sweep(seconds: float, f0: float, f1: float, glide: float) -> PackedFloat32Array:
	var b := buffer(seconds)
	var phase := 0.0
	for i in range(b.size()):
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t / glide)
		phase += TAU * f / RATE
		b[i] = sin(phase)
	return b

func normalise(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	for i in range(b.size()):
		b[i] = b[i] / m * peak
	return b

func make_loop(b: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var n := int(fade * RATE)
	var out := b.slice(0, b.size() - n)
	for i in range(n):
		var k := float(i) / n
		out[i] = out[i] * k + b[b.size() - n + i] * (1.0 - k)
	return out

func save(name: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if name.ends_with("_loop") or name.begins_with("amb_"):
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	wav.save_to_wav("res://audio/%s.wav" % name)
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	print("%s: %.2f s, peak %.2f" % [name, samples.size() / float(RATE), peak])

# ---------------------------------------------------------------- weapons & combat

func rifle(variant: int) -> PackedFloat32Array:
	rng.seed = 100 + variant
	var out := buffer(0.55)
	add_decaying(out, highpass(noise(0.08), 1800.0), 1.0, 0.005)
	add_decaying(out, lowpass(noise(0.28), 2100.0 + variant * 280.0), 0.9, 0.04)
	add_decaying(out, sweep(0.18, 210.0 - variant * 18.0, 82.0, 0.025), 0.6, 0.03)
	add_decaying(out, lowpass(noise(0.5), 620.0), 0.24, 0.16, 0.025, 0.01)
	return normalise(out, 0.9)

func mg_burst() -> PackedFloat32Array:
	rng.seed = 150
	var out := buffer(0.65)
	for shot in range(3):
		var at := shot * 0.095
		add_decaying(out, highpass(noise(0.05), 1700.0), 0.95, 0.005, at)
		add_decaying(out, lowpass(noise(0.14), 2200.0), 0.75, 0.028, at)
		add_decaying(out, sweep(0.09, 195.0, 85.0, 0.02), 0.5, 0.022, at)
	add_decaying(out, lowpass(noise(0.55), 550.0), 0.22, 0.18, 0.05, 0.02)
	return normalise(out, 0.88)

func cannon() -> PackedFloat32Array:
	rng.seed = 200
	var out := buffer(2.5)
	add_decaying(out, highpass(noise(0.18), 950.0), 1.0, 0.012)
	add_decaying(out, sweep(1.6, 78.0, 32.0, 0.24), 1.0, 0.38)
	add_decaying(out, sweep(1.0, 150.0, 62.0, 0.18), 0.4, 0.2)
	add_decaying(out, lowpass(noise(1.1), 460.0), 0.95, 0.24)
	add_decaying(out, lowpass(noise(2.4), 150.0), 0.48, 0.92, 0.05, 0.05)
	return normalise(out, 0.95)

func artillery_fire() -> PackedFloat32Array:
	rng.seed = 240
	var out := buffer(3.0)
	add_decaying(out, highpass(noise(0.22), 700.0), 0.9, 0.018)
	add_decaying(out, sweep(2.0, 60.0, 26.0, 0.35), 1.0, 0.52)
	add_decaying(out, lowpass(noise(1.5), 340.0), 0.95, 0.34)
	add_decaying(out, lowpass(noise(2.9), 120.0), 0.65, 1.15, 0.04, 0.06)
	return normalise(out, 0.95)

func missile_launch() -> PackedFloat32Array:
	rng.seed = 275
	var out := buffer(1.6)
	# Sharp ignition pop + sustained rocket thruster whoosh
	add_decaying(out, highpass(noise(0.12), 1400.0), 0.85, 0.018)
	add_decaying(out, sweep(0.35, 160.0, 65.0, 0.09), 0.65, 0.09)
	var hiss := bandpass(noise(1.6), 350.0, 3800.0)
	var roar := lowpass(noise(1.6), 420.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.04, t) * exp(-t * 2.1)
		out[i] += (hiss[i] * 0.9 + roar[i] * 0.65) * env
	return normalise(out, 0.92)

func explosion(variant: int) -> PackedFloat32Array:
	rng.seed = 300 + variant
	var out := buffer(3.6)
	add_decaying(out, highpass(noise(0.3), 700.0), 0.85, 0.022)
	add_decaying(out, sweep(2.4, 58.0 - variant * 6.0, 26.0, 0.4), 1.0, 0.6)
	add_decaying(out, lowpass(noise(2.0), 340.0), 1.0, 0.45)
	add_decaying(out, lowpass(noise(3.6), 95.0), 0.65, 1.4, 0.03, 0.08)
	var crackle := lowpass(noise(0.03), 3200.0)
	for i in range(42 + variant * 10):
		var at := rng.randf_range(0.08, 1.35)
		add_decaying(out, crackle, 0.35 * exp(-at / 0.6) * rng.randf_range(0.4, 1.0), 0.006, at)
	return normalise(out, 0.95)

func nuke_blast() -> PackedFloat32Array:
	rng.seed = 399
	var out := buffer(5.5)
	# Initial flash shockwave + massive sub-bass drop + long atmospheric thunder
	add_decaying(out, highpass(noise(0.35), 900.0), 1.0, 0.03)
	add_decaying(out, sweep(3.5, 48.0, 20.0, 0.7), 1.0, 1.1)
	add_decaying(out, sweep(2.2, 72.0, 28.0, 0.4), 0.7, 0.55, 0.14)
	add_decaying(out, lowpass(noise(3.5), 280.0), 0.95, 0.85)
	add_decaying(out, lowpass(noise(5.4), 85.0), 0.85, 2.2, 0.05, 0.12)
	return normalise(out, 0.98)

func impact(variant: int) -> PackedFloat32Array:
	rng.seed = 400 + variant
	var out := buffer(0.18)
	add_decaying(out, lowpass(noise(0.1), 2600.0 + variant * 900.0), 1.0, 0.012)
	add_decaying(out, sweep(0.1, 165.0, 88.0, 0.02), 0.6, 0.02)
	return normalise(out, 0.7)

func siren_short() -> PackedFloat32Array:
	# Brief, clean 2-chirp emergency response tone (never an endless loop)
	var out := buffer(0.85)
	for i in range(out.size()):
		var t := float(i) / RATE
		var phase_t := fmod(t, 0.42)
		var env := smoothstep(0.0, 0.03, phase_t) * (1.0 - smoothstep(0.30, 0.42, phase_t))
		var freq := 640.0 if t < 0.42 else 510.0
		out[i] = (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * env * 0.4
	return normalise(out, 0.55)

# ---------------------------------------------------------------- unit engine loops

func engine_loop() -> PackedFloat32Array:
	rng.seed = 500
	var seconds := 2.4
	var out := buffer(seconds)
	var grit := lowpass(noise(seconds), 240.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		var chug := 0.75 + 0.25 * sin(TAU * 10.0 * t)
		var tone := sin(TAU * 42.0 * t) + 0.5 * sin(TAU * 84.0 * t + 0.3) + 0.25 * sin(TAU * 126.0 * t)
		out[i] = (tone * 0.42 + grit[i] * 3.8) * chug
	return normalise(make_loop(out, 0.25), 0.72)

func tank_loop() -> PackedFloat32Array:
	rng.seed = 515
	var seconds := 2.4
	var out := buffer(seconds)
	var rumble := lowpass(noise(seconds), 190.0)
	var tread := bandpass(noise(seconds), 320.0, 950.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		var chug := 0.65 + 0.35 * sin(TAU * 12.0 * t)
		var clatter := pow(0.5 + 0.5 * sin(TAU * 16.0 * t), 4.0)
		var tone := sin(TAU * 34.0 * t) + 0.65 * sin(TAU * 68.0 * t + 0.4) + 0.3 * sin(TAU * 102.0 * t)
		out[i] = (tone * 0.48 + rumble[i] * 4.5) * chug + tread[i] * (0.4 + 1.2 * clatter)
	return normalise(make_loop(out, 0.25), 0.78)

func jet_loop() -> PackedFloat32Array:
	rng.seed = 530
	var seconds := 3.0
	var out := buffer(seconds)
	var roar := bandpass(noise(seconds), 180.0, 1400.0)
	var air := bandpass(noise(seconds), 1500.0, 4200.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		var shimmer := 0.88 + 0.12 * sin(TAU * 1.5 * t)
		var whine := sin(TAU * 780.0 * t) * 0.04 + sin(TAU * 1170.0 * t) * 0.025
		out[i] = (roar[i] * 2.2 + air[i] * 0.9 + whine) * shimmer
	return normalise(make_loop(out, 0.35), 0.68)

func heli_loop() -> PackedFloat32Array:
	rng.seed = 545
	var seconds := 2.5
	var out := buffer(seconds)
	var wash := lowpass(noise(seconds), 380.0)
	var blade_air := bandpass(noise(seconds), 450.0, 2200.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		# 13 Hz twin-blade rotor thump ("whop-whop-whop")
		var thump := pow(0.5 + 0.5 * sin(TAU * 13.0 * t), 3.0)
		var turbine := sin(TAU * 520.0 * t) * 0.035
		out[i] = wash[i] * (0.4 + 2.4 * thump) + blade_air[i] * (0.2 + 1.1 * thump) + turbine
	return normalise(make_loop(out, 0.25), 0.75)

func ship_loop() -> PackedFloat32Array:
	rng.seed = 560
	var seconds := 3.2
	var out := buffer(seconds)
	var hull := lowpass(noise(seconds), 140.0)
	var wake := bandpass(noise(seconds), 250.0, 1100.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		var pulse := 0.8 + 0.2 * sin(TAU * 4.0 * t)
		var diesel := sin(TAU * 28.0 * t) * 0.35 + sin(TAU * 56.0 * t) * 0.2
		out[i] = (hull[i] * 3.0 + diesel) * pulse + wake[i] * 0.75
	return normalise(make_loop(out, 0.35), 0.65)

# ---------------------------------------------------------------- organic ambience loops

func wind_loop() -> PackedFloat32Array:
	rng.seed = 600
	var seconds := 10.5
	var low_air := lowpass(lowpass(noise(seconds), 360.0), 320.0)
	var breeze := bandpass(noise(seconds), 380.0, 1200.0)
	var out := buffer(seconds)
	for i in range(out.size()):
		var t := float(i) / RATE
		var gust := 0.55 + 0.3 * sin(TAU * t / 4.8) + 0.15 * sin(TAU * t * 0.57)
		out[i] = (low_air[i] * 1.4 + breeze[i] * 0.32) * gust
	return normalise(make_loop(out, 0.8), 0.5)

func surf_loop() -> PackedFloat32Array:
	rng.seed = 700
	var seconds := 12.5
	var body := lowpass(noise(seconds), 620.0)
	var hiss := bandpass(noise(seconds), 1100.0, 3800.0)
	var out := buffer(seconds)
	for i in range(out.size()):
		var t := float(i) / RATE
		var swell := pow(0.5 + 0.5 * sin(TAU * t / 6.0 - 1.2), 3.0)
		var brk := pow(0.5 + 0.5 * sin(TAU * t / 6.0 - 0.3), 8.0)
		out[i] = body[i] * (0.25 + swell) * 2.4 + hiss[i] * brk * 1.3
	return normalise(make_loop(out, 0.8), 0.62)

func amb_nature() -> PackedFloat32Array:
	# Soft rustling leaves + sparse, gentle daytime birdsong chirps
	rng.seed = 750
	var seconds := 12.0
	var out := bandpass(noise(seconds), 280.0, 1600.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		out[i] *= 0.28 * (0.7 + 0.3 * sin(TAU * t / 3.8))
	# Add sparse distant bird chirps (short FM whistles)
	for b in range(10):
		var start := rng.randf_range(0.5, seconds - 1.2)
		var base_f := rng.randf_range(2100.0, 3400.0)
		var notes := rng.randi_range(2, 4)
		for n in range(notes):
			var at := int((start + n * 0.13) * RATE)
			var dur := int(0.08 * RATE)
			var f0 := base_f + rng.randf_range(-250.0, 350.0)
			for k in range(dur):
				var j := posmod(at + k, out.size())
				var tk := float(k) / RATE
				var env := smoothstep(0.0, 0.012, tk) * (1.0 - smoothstep(0.04, 0.08, tk))
				out[j] += sin(TAU * (f0 + 450.0 * sin(TAU * 12.0 * tk)) * tk) * env * 0.045
	return normalise(make_loop(out, 0.8), 0.42)

func amb_city() -> PackedFloat32Array:
	# Natural distant urban life: gentle traffic air wash + subtle warm crowd murmur (no sine drone!)
	rng.seed = 780
	var seconds := 10.5
	var traffic := bandpass(noise(seconds), 140.0, 520.0)
	var murmur := bandpass(noise(seconds), 550.0, 1450.0)
	var out := buffer(seconds)
	for i in range(out.size()):
		var t := float(i) / RATE
		var ebb := 0.75 + 0.25 * sin(TAU * t / 5.0)
		var chatter := 0.65 + 0.35 * sin(TAU * t * 1.7 + sin(TAU * t * 0.4))
		out[i] = traffic[i] * 1.4 * ebb + murmur[i] * 0.45 * chatter
	return normalise(make_loop(out, 0.8), 0.45)

func amb_battle() -> PackedFloat32Array:
	# Distant battlefield atmosphere: far-off muffled cannon/explosion rumbles + subtle fire crackle (no siren!)
	rng.seed = 810
	var seconds := 10.8
	var air := lowpass(noise(seconds), 220.0)
	var out := buffer(seconds)
	for i in range(out.size()):
		out[i] = air[i] * 0.7
	# Distant muffled artillery thuds
	for k in range(7):
		var at := rng.randf_range(0.4, seconds - 1.6)
		add_decaying(out, lowpass(noise(1.1), 160.0), rng.randf_range(0.25, 0.55), 0.35, at, 0.04)
	# Subtle fire crackle pops
	var pop := bandpass(noise(0.025), 900.0, 3200.0)
	for k in range(28):
		var at := rng.randf_range(0.2, seconds - 0.8)
		add_decaying(out, pop, rng.randf_range(0.06, 0.16), 0.008, at)
	return normalise(make_loop(out, 0.8), 0.48)

func amb_war_room() -> PackedFloat32Array:
	# Quiet, warm strategic command-room air tone (filtered pink-ish air, zero 880Hz beeps!)
	rng.seed = 840
	var seconds := 10.5
	var room_air := bandpass(noise(seconds), 90.0, 320.0)
	var out := buffer(seconds)
	for i in range(out.size()):
		var t := float(i) / RATE
		out[i] = room_air[i] * (0.85 + 0.15 * sin(TAU * t / 5.0))
	return normalise(make_loop(out, 0.8), 0.3)

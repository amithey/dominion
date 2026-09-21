extends SceneTree
## Synthesises the game's sound effects into res://audio/*.wav.
## No recordings are needed and there is nothing to license: every sound is
## built from filtered noise, swept sines and envelopes. Real recordings can
## replace any file later under the same name.
## Usage: godot --headless --path native/godot --script res://tools/make-sounds.gd

const RATE := 44100
var rng := RandomNumberGenerator.new()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://audio")
	for i in range(3):
		save("rifle_%d" % (i + 1), rifle(i))
	save("cannon", cannon())
	for i in range(2):
		save("explosion_%d" % (i + 1), explosion(i))
	for i in range(2):
		save("impact_%d" % (i + 1), impact(i))
	save("engine_loop", engine_loop())
	save("wind_loop", wind_loop())
	save("surf_loop", surf_loop())
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

# One-pole filters: cheap, smooth, and enough to shape noise into air and earth.
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

# Adds `src * gain * exp(-t / decay)` starting at `delay` seconds.
func add_decaying(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, decay: float, delay := 0.0, attack := 0.0005) -> void:
	var start := int(delay * RATE)
	for i in range(src.size()):
		var j := start + i
		if j >= dst.size():
			break
		var t := float(i) / RATE
		dst[j] += src[i] * gain * exp(-t / decay) * minf(1.0, t / attack)

# A sine whose pitch slides from f0 to f1, like the body of a blast.
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

# Seamless loop: the last `fade` seconds are cross-faded into the beginning.
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
	wav.save_to_wav("res://audio/%s.wav" % name)
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	print("%s: %.2f s, peak %.2f" % [name, samples.size() / float(RATE), peak])

# ---------------------------------------------------------------- sounds

func rifle(variant: int) -> PackedFloat32Array:
	rng.seed = 100 + variant
	var out := buffer(0.5)
	add_decaying(out, highpass(noise(0.1), 1600.0), 1.0, 0.006)                 # supersonic crack
	add_decaying(out, lowpass(noise(0.3), 1900.0 + variant * 250.0), 0.9, 0.045)  # muzzle blast
	add_decaying(out, sweep(0.2, 190.0 - variant * 15.0, 85.0, 0.03), 0.55, 0.035) # thump
	add_decaying(out, lowpass(noise(0.5), 650.0), 0.22, 0.16, 0.025, 0.01)          # echo off the land
	return normalise(out, 0.9)

func cannon() -> PackedFloat32Array:
	rng.seed = 200
	var out := buffer(2.4)
	add_decaying(out, highpass(noise(0.2), 900.0), 1.0, 0.012)
	add_decaying(out, sweep(1.6, 72.0, 34.0, 0.25), 1.0, 0.38)
	add_decaying(out, sweep(1.0, 140.0, 66.0, 0.2), 0.35, 0.2)
	add_decaying(out, lowpass(noise(1.0), 420.0), 0.9, 0.22)
	add_decaying(out, lowpass(noise(2.4), 150.0), 0.45, 0.9, 0.05, 0.05)
	return normalise(out, 0.95)

func explosion(variant: int) -> PackedFloat32Array:
	rng.seed = 300 + variant
	var out := buffer(3.6)
	add_decaying(out, highpass(noise(0.3), 700.0), 0.8, 0.022)
	add_decaying(out, sweep(2.4, 55.0 - variant * 6.0, 27.0, 0.4), 1.0, 0.6)
	add_decaying(out, lowpass(noise(2.0), 320.0), 1.0, 0.45)
	add_decaying(out, lowpass(noise(3.6), 95.0), 0.6, 1.4, 0.03, 0.08)
	# Debris: scattered clicks and pattering over the first second.
	var crackle := lowpass(noise(0.03), 3200.0)
	for i in range(40 + variant * 10):
		var at := rng.randf_range(0.08, 1.3)
		add_decaying(out, crackle, 0.35 * exp(-at / 0.6) * rng.randf_range(0.4, 1.0), 0.006, at)
	return normalise(out, 0.95)

func impact(variant: int) -> PackedFloat32Array:
	rng.seed = 400 + variant
	var out := buffer(0.16)
	add_decaying(out, lowpass(noise(0.1), 2600.0 + variant * 900.0), 1.0, 0.012)
	add_decaying(out, sweep(0.1, 160.0, 90.0, 0.02), 0.6, 0.02)
	return normalise(out, 0.7)

# Diesel rumble: harmonics of a 36 Hz firing rate, a 12 Hz chug and gritty
# low noise. Frequencies divide the 2 s loop exactly, so it repeats cleanly.
func engine_loop() -> PackedFloat32Array:
	rng.seed = 500
	var seconds := 2.2
	var out := buffer(seconds)
	var grit := lowpass(noise(seconds), 260.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		var chug := 0.65 + 0.35 * sin(TAU * 12.0 * t)
		var tone := sin(TAU * 36.0 * t) + 0.6 * sin(TAU * 72.0 * t + 0.4) + 0.35 * sin(TAU * 108.0 * t + 1.1) + 0.2 * sin(TAU * 162.0 * t)
		out[i] = (tone * 0.5 + grit[i] * 5.0) * chug
	return normalise(make_loop(out, 0.2), 0.8)

func wind_loop() -> PackedFloat32Array:
	rng.seed = 600
	var seconds := 6.5
	var out := lowpass(lowpass(noise(seconds), 380.0), 380.0)
	for i in range(out.size()):
		var t := float(i) / RATE
		out[i] *= 0.6 + 0.4 * sin(TAU * t / 3.0) + 0.15 * sin(TAU * t * 1.3)
	return normalise(make_loop(out, 0.5), 0.6)

# Waves: swells of filtered noise every six seconds, each breaking with a hiss.
func surf_loop() -> PackedFloat32Array:
	rng.seed = 700
	var seconds := 12.5
	var body := lowpass(noise(seconds), 700.0)
	var hiss := highpass(lowpass(noise(seconds), 4000.0), 1200.0)
	var out := buffer(seconds)
	for i in range(out.size()):
		var t := float(i) / RATE
		var swell := pow(0.5 + 0.5 * sin(TAU * t / 6.0 - 1.2), 3.0)
		var brk := pow(0.5 + 0.5 * sin(TAU * t / 6.0 - 0.3), 8.0)
		out[i] = body[i] * (0.25 + swell) * 2.5 + hiss[i] * brk * 1.5
	return normalise(make_loop(out, 0.5), 0.7)

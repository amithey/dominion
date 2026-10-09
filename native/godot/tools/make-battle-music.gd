extends SceneTree
## Original 48-second D-minor combat cue: low strings, restrained toms and
## a repeating pulse. Synthesised locally; no recordings or licensed samples.
const RATE := 22050
const LENGTH := 48
const NOTES := [[38, 50, 57, 62], [34, 46, 53, 58], [41, 53, 57, 60], [36, 48, 55, 60],
	[38, 50, 57, 62], [43, 55, 58, 62], [34, 46, 53, 58], [45, 57, 61, 64]]
func _initialize() -> void:
	call_deferred("generate")
func hz(note: int) -> float: return 440.0 * pow(2.0, (note - 69.0) / 12.0)
func generate() -> void:
	var samples := PackedFloat32Array()
	samples.resize(RATE * LENGTH)
	var frequencies: Array = []
	for chord in NOTES:
		var pitches: Array = []
		for note in chord: pitches.append(hz(note))
		frequencies.append(pitches)
	var peak := 0.0
	for i in range(samples.size()):
		var t := float(i) / RATE
		var chord := int(t / 6.0)
		var within := fmod(t, 6.0)
		var pad := 0.0
		# Overlapping chords wrap at the loop boundary.
		for offset in [0, -1]:
			var notes: Array = frequencies[posmod(chord + offset, NOTES.size())]
			var age: float = within - offset * 6.0
			var env := smoothstep(0.0, 1.0, age) * (1.0 - smoothstep(6.0, 7.0, age))
			for frequency in notes:
				var f: float = frequency
				pad += env * (sin(TAU * f * t) + 0.18 * sin(TAU * f * 2.0 * t)) * 0.035
		var beat := fmod(t, 0.5)
		var pulse := sin(TAU * float(frequencies[chord][0]) * 2.0 * beat) * exp(-beat * 11.0) * smoothstep(0.0, 0.012, beat) * 0.06
		var drum_time := fmod(t, 1.5)
		var drum := sin(TAU * (66.0 * drum_time + 13.0 * (1.0 - exp(-drum_time * 12.0)))) * exp(-drum_time * 9.0) * smoothstep(0.0, 0.006, drum_time) * 0.14
		samples[i] = pad + pulse + drum
		peak = maxf(peak, absf(samples[i]))
	# Ease both ends to zero over 50 ms: the final and first PCM samples meet
	# without a click, even though the sustained frequencies are not periodic.
	var seam := RATE / 20
	for i in range(seam):
		var blend := smoothstep(0.0, 1.0, float(i) / seam)
		samples[i] *= blend
		samples[samples.size() - 1 - i] *= blend
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()): data.encode_s16(i * 2, int(samples[i] / maxf(peak, 0.001) * 0.55 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.save_to_wav("res://audio/battle_loop.wav")
	print("BATTLE_MUSIC generated: 48 seconds, peak 0.55")
	quit()

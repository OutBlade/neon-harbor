extends Node
## Procedural audio: every sound in the game is synthesized at startup.
## No binary assets anywhere in the project.

const RATE := 22050

var streams: Dictionary = {}
var music_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	streams["engine"] = _make_engine()
	streams["siren"] = _make_siren()
	streams["crash"] = _make_crash()
	streams["pickup"] = _make_pickup()
	streams["jingle"] = _make_jingle()
	streams["fail"] = _make_fail()
	streams["click"] = _make_click()
	streams["horn"] = _make_horn()
	ui_player = AudioStreamPlayer.new()
	ui_player.volume_db = -6.0
	add_child(ui_player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -11.0
	add_child(music_player)
	# Music is the most expensive buffer; build it after the first frame.
	_build_music.call_deferred()

func _build_music() -> void:
	streams["music"] = _make_music()
	music_player.stream = streams["music"]
	music_player.play()

func play_ui(name_: String) -> void:
	if streams.has(name_):
		ui_player.stream = streams[name_]
		ui_player.play()

func stream(name_: String) -> AudioStreamWAV:
	return streams.get(name_)

# ------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s

func _saw(phase: float) -> float:
	return 2.0 * (phase - floorf(phase + 0.5))

func _square(phase: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0

func _make_engine() -> AudioStreamWAV:
	var n := RATE / 2
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.5 * _saw(t * 55.0) + 0.3 * _saw(t * 110.0) + 0.15 * _saw(t * 167.0)
		s += (randf() * 2.0 - 1.0) * 0.06
		lp += 0.22 * (s - lp)
		out[i] = lp * 0.55
	return _wav(out, true)

func _make_siren() -> AudioStreamWAV:
	var n := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := 620.0 + 540.0 * (0.5 - 0.5 * cos(t * TAU))
		phase += f / RATE
		out[i] = sin(phase * TAU) * 0.4
	return _wav(out, true)

func _make_crash() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := (randf() * 2.0 - 1.0) * exp(-9.0 * t)
		lp += 0.4 * (s - lp)
		out[i] = lp * 0.9
	return _wav(out, false)

func _tone_seq(freqs: Array, dur: float, kind: String) -> AudioStreamWAV:
	var n := int(RATE * dur * freqs.size())
	var out := PackedFloat32Array()
	out.resize(n)
	var per := int(RATE * dur)
	for i in n:
		var idx := mini(i / per, freqs.size() - 1)
		var local := float(i % per) / RATE
		var env := exp(-5.0 * local)
		var ph: float = local * float(freqs[idx])
		var s := _square(ph) * 0.18 if kind == "square" else sin(ph * TAU) * 0.32
		out[i] = s * env
	return _wav(out, false)

func _make_pickup() -> AudioStreamWAV:
	return _tone_seq([880.0, 1318.5], 0.11, "sine")

func _make_jingle() -> AudioStreamWAV:
	return _tone_seq([523.25, 659.25, 784.0, 1046.5], 0.16, "square")

func _make_fail() -> AudioStreamWAV:
	return _tone_seq([392.0, 311.1, 233.1], 0.22, "square")

func _make_click() -> AudioStreamWAV:
	return _tone_seq([1250.0], 0.05, "sine")

func _make_horn() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t * 40.0, 1.0) * exp(-3.0 * maxf(t - 0.25, 0.0) * 8.0)
		out[i] = (_square(t * 400.0) * 0.5 + _square(t * 505.0) * 0.5) * 0.22 * env
	return _wav(out, false)

func _make_music() -> AudioStreamWAV:
	# Eight-bar synthwave loop at 100 BPM: pad chords, sub bass, kick, hats.
	var bpm := 100.0
	var bar := 60.0 / bpm * 4.0
	var bars := 8
	var n := int(RATE * bar * bars)
	var out := PackedFloat32Array()
	out.resize(n)
	# C minor, A flat major, E flat major, B flat major (roots and triads in Hz).
	var chords := [
		[130.81, 155.56, 196.00],
		[103.83, 130.81, 155.56],
		[155.56, 196.00, 233.08],
		[116.54, 146.83, 174.61],
	]
	var lp := 0.0
	var beat := bar / 4.0
	for i in n:
		var t := float(i) / RATE
		var bar_i := int(t / bar) % 4
		var chord: Array = chords[bar_i]
		var s := 0.0
		for f0 in chord:
			var f: float = f0
			s += _saw(t * f * 0.999) * 0.05
			s += _saw(t * f * 1.002) * 0.05
		lp += 0.07 * (s - lp)
		var mix := lp * 1.6
		# Sub bass on each beat, root note one octave down.
		var bt := fposmod(t, beat)
		var root: float = chord[0]
		mix += sin(TAU * (root * 0.5) * t) * 0.22 * exp(-3.5 * bt)
		# Kick.
		mix += sin(TAU * (52.0 + 80.0 * exp(-25.0 * bt)) * bt) * 0.5 * exp(-9.0 * bt)
		# Hats on sixteenths.
		var st := fposmod(t, beat / 4.0)
		mix += (randf() * 2.0 - 1.0) * 0.035 * exp(-60.0 * st)
		out[i] = clampf(mix, -1.0, 1.0)
	return _wav(out, true)

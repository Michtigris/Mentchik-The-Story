extends RefCounted
class_name AudioSynth

static func _wav(data: PackedByteArray, rate: int = 44100, loop: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	if loop:
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream

static func _s16(data: PackedByteArray, idx: int, val: float) -> void:
	var s := clampi(int(val * 32767.0), -32768, 32767)
	data[idx] = s & 0xFF
	data[idx + 1] = (s >> 8) & 0xFF

# --- BGM Menu: longue nappe d'orgue cathédrale, chorale, cloches lointaines ---
static func make_menu_music() -> AudioStream:
	var rate := 22050
	var dur := 24.0
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := minf(1.0, t * 0.5) * minf(1.0, (dur - t) * 0.5)
		var phase := t / dur
		var organ := sin(TAU * 65.4 * t) * 0.18
		organ += sin(TAU * 98.0 * t) * 0.14
		organ += sin(TAU * 130.8 * t) * 0.10
		organ += sin(TAU * 196.0 * t) * 0.06
		var swell := 0.7 + 0.3 * sin(TAU * phase * 2.0)
		organ *= swell
		var choir := sin(TAU * 261.6 * t + sin(TAU * 4.8 * t) * 0.7) * 0.05
		choir += sin(TAU * 329.6 * t + sin(TAU * 5.2 * t) * 0.5) * 0.04
		choir += sin(TAU * 392.0 * t + sin(TAU * 3.5 * t) * 0.6) * 0.03
		var choir_swell := 0.5 + 0.5 * sin(TAU * phase * 1.5 + 0.8)
		choir *= choir_swell
		var bell := 0.0
		var bell_period := 3.2
		var bell_t := fmod(t, bell_period)
		if bell_t < 0.8:
			var bell_env := maxf(0.0, 1.0 - bell_t / 0.8) * minf(1.0, bell_t * 30.0)
			bell = sin(TAU * 523.2 * t) * 0.04 * bell_env
			bell += sin(TAU * 1046.5 * t) * 0.02 * bell_env
		var wind := sin(TAU * 42.0 * t + sin(TAU * 0.08 * t) * 4.0) * 0.03
		var sample := (organ + choir + bell + wind) * env * 0.5
		_s16(data, i * 2, sample)
	return _wav(data, rate, true)

# --- BGM Level: tension, percussions, basses sombres ---
static func make_level_music() -> AudioStream:
	var rate := 22050
	var dur := 16.0
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := minf(1.0, t * 1.0) * minf(1.0, (dur - t) * 1.0)
		var beat_4 := fmod(t, 0.5)
		var beat_8 := fmod(t, 0.25)
		var bass := sin(TAU * 55.0 * t) * 0.2
		bass += sin(TAU * 82.4 * t) * 0.12 * absf(sin(TAU * 0.5 * t))
		var bass_pulse := 0.6 + 0.4 * absf(sin(TAU * 2.0 * t))
		bass *= bass_pulse
		var tension := sin(TAU * 146.8 * t + sin(TAU * 3.0 * t) * 1.5) * 0.08
		tension += sin(TAU * 220.0 * t + sin(TAU * 2.2 * t) * 0.8) * 0.05
		tension += sin(TAU * 174.6 * t) * 0.04 * absf(sin(TAU * 1.0 * t))
		var perc := 0.0
		if beat_4 < 0.015:
			perc = (0.015 - beat_4) * 66.0 * sin(TAU * 90.0 * t) * 0.18
		if beat_8 < 0.008:
			perc += (0.008 - beat_8) * 125.0 * sin(TAU * 4500.0 * t) * 0.04
		var string_pad := sin(TAU * 110.0 * t + sin(TAU * 5.0 * t) * 0.4) * 0.04
		string_pad += sin(TAU * 164.8 * t + sin(TAU * 4.0 * t) * 0.3) * 0.03
		var intensity := 0.7 + 0.3 * sin(TAU * t / dur * 3.0)
		var sample := (bass + tension + perc + string_pad) * env * intensity * 0.55
		_s16(data, i * 2, sample)
	return _wav(data, rate, true)

# --- UI: son cristallin d'ouverture (vitrail) ---
static func make_ui_open() -> AudioStream:
	var rate := 44100
	var dur := 0.18
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := (1.0 - t / dur) * minf(1.0, t * 120.0)
		var freq := 880.0 + t * 1200.0
		var sample := sin(TAU * freq * t) * 0.25 * env
		sample += sin(TAU * freq * 1.5 * t) * 0.12 * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- UI: son de fermeture (descendant) ---
static func make_ui_close() -> AudioStream:
	var rate := 44100
	var dur := 0.15
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := (1.0 - t / dur) * minf(1.0, t * 120.0)
		var freq := 660.0 - t * 800.0
		var sample := sin(TAU * maxf(80.0, freq) * t) * 0.22 * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Attaque: tranchant métallique rapide ---
static func make_attack_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.13
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 200.0)
		var metal := sin(TAU * 1200.0 * t) * 0.15
		metal += sin(TAU * 2400.0 * t) * 0.1 * maxf(0.0, 1.0 - t * 15.0)
		var noise := (sin(TAU * 7919.0 * t + sin(TAU * 3571.0 * t) * 6.0)) * 0.12 * maxf(0.0, 1.0 - t * 12.0)
		var swoosh := sin(TAU * (400.0 + t * 2000.0) * t) * 0.08 * maxf(0.0, 1.0 - t * 10.0)
		var sample := (metal + noise + swoosh) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Dash: souffle rapide ---
static func make_dash_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.16
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 100.0)
		var whoosh := sin(TAU * (200.0 + t * 3000.0) * t) * 0.18
		whoosh += sin(TAU * 5003.0 * t + sin(TAU * 1997.0 * t) * 4.0) * 0.08 * maxf(0.0, 1.0 - t * 8.0)
		var sample := whoosh * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Saut: rebond aérien ---
static func make_jump_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.12
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 150.0)
		var freq := 280.0 + t * 1800.0
		var sample := sin(TAU * freq * t) * 0.2 * env
		sample += sin(TAU * freq * 2.0 * t) * 0.06 * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Dégâts joueur: impact sourd + gémissement ---
static func make_hurt_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.28
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var impact := sin(TAU * 80.0 * t) * 0.3 * maxf(0.0, 1.0 - t * 12.0)
		var crunch := sin(TAU * 4001.0 * t + sin(TAU * 2003.0 * t) * 5.0) * 0.1 * maxf(0.0, 1.0 - t * 8.0)
		var moan := sin(TAU * (180.0 - t * 120.0) * t + sin(TAU * 6.0 * t) * 1.5) * 0.12 * minf(1.0, t * 8.0)
		var sample := (impact + crunch + moan) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Lancer d'épée: sifflement rotatif ---
static func make_sword_throw_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.2
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 80.0)
		var spin := sin(TAU * 1600.0 * t + sin(TAU * 18.0 * t) * 3.0) * 0.16
		var whoosh := sin(TAU * (600.0 + t * 1400.0) * t) * 0.12
		var sample := (spin + whoosh) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Grenade: thunk sourd de lancer ---
static func make_grenade_throw_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.14
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 120.0)
		var thunk := sin(TAU * 120.0 * t) * 0.28 * maxf(0.0, 1.0 - t * 14.0)
		var click := sin(TAU * 2200.0 * t) * 0.08 * maxf(0.0, 1.0 - t * 25.0)
		var sample := (thunk + click) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Explosion: boom + crépitement ---
static func make_explosion_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.45
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var boom := sin(TAU * (60.0 - t * 40.0) * t) * 0.35 * maxf(0.0, 1.0 - t * 5.0)
		var crack := sin(TAU * 5501.0 * t + sin(TAU * 3001.0 * t) * 8.0) * 0.15 * maxf(0.0, 1.0 - t * 4.0)
		var rumble := sin(TAU * 35.0 * t + sin(TAU * 1.8 * t) * 2.0) * 0.12 * env
		var sample := (boom + crack + rumble) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Mort ennemi: dissolution ---
static func make_enemy_death_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.3
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var dissolve := sin(TAU * (600.0 - t * 1200.0) * t) * 0.18
		var fizz := sin(TAU * 4507.0 * t + sin(TAU * 2503.0 * t) * 4.0) * 0.1 * maxf(0.0, 1.0 - t * 6.0)
		var poof := sin(TAU * 160.0 * t) * 0.15 * maxf(0.0, 1.0 - t * 8.0)
		var sample := (dissolve + fizz + poof) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Éclair (vitrail jaune): zap électrique ---
static func make_lightning_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.25
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 200.0)
		var zap := sin(TAU * 1800.0 * t + sin(TAU * 40.0 * t) * 8.0) * 0.2
		var crackle := sin(TAU * 6007.0 * t + sin(TAU * 4001.0 * t) * 6.0) * 0.12 * maxf(0.0, 1.0 - t * 6.0)
		var bass := sin(TAU * 100.0 * t) * 0.15 * maxf(0.0, 1.0 - t * 5.0)
		var sample := (zap + crackle + bass) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Vitrail obtenu: carillon magique ---
static func make_vitrail_reward_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.8
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur) * minf(1.0, t * 20.0)
		var chime1 := sin(TAU * 523.2 * t) * 0.12 * maxf(0.0, 1.0 - t * 2.5)
		var chime2 := sin(TAU * 659.2 * t) * 0.12 * maxf(0.0, minf(1.0, (t - 0.15) * 10.0)) * maxf(0.0, 1.0 - (t - 0.15) * 2.5)
		var chime3 := sin(TAU * 783.9 * t) * 0.12 * maxf(0.0, minf(1.0, (t - 0.3) * 10.0)) * maxf(0.0, 1.0 - (t - 0.3) * 2.5)
		var shimmer := sin(TAU * 1046.5 * t + sin(TAU * 5.0 * t) * 0.8) * 0.06 * maxf(0.0, minf(1.0, (t - 0.4) * 5.0))
		var sample := (chime1 + chime2 + chime3 + shimmer) * env
		_s16(data, i * 2, sample)
	return _wav(data, rate)

# --- Atterrissage: impact au sol ---
static func make_land_sfx() -> AudioStream:
	var rate := 44100
	var dur := 0.08
	var frames := int(dur * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := maxf(0.0, 1.0 - t / dur)
		var thud := sin(TAU * 95.0 * t) * 0.25 * env
		var dust := sin(TAU * 3001.0 * t + sin(TAU * 1501.0 * t) * 3.0) * 0.06 * env
		var sample := thud + dust
		_s16(data, i * 2, sample)
	return _wav(data, rate)

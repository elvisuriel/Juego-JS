class_name Sfx
extends RefCounted
## Efectos de sonido sintetizados por código (no hacen falta archivos).

const RATE := 22050

static var _cache := {}


## Una secuencia de notas: [[frecuencia, duración], ...]
static func _tones(key: String, notes: Array, wave := "sine", volume := 0.5) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var data := PackedByteArray()
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var count := int(dur * RATE)
		for i in count:
			var t := float(i) / RATE
			var env := minf(1.0, i / 200.0) * minf(1.0, (count - i) / 600.0)
			var ph := TAU * freq * t
			var s := sin(ph)
			if wave == "square":
				s = signf(s) * 0.6
			elif wave == "saw":
				s = 2.0 * fmod(freq * t, 1.0) - 1.0
			var v := int(clampf(s * env * volume, -1.0, 1.0) * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav


static func alert() -> AudioStreamWAV:
	return _tones("alert", [[880, 0.09], [0, 0.04], [660, 0.12]], "square", 0.35)


static func powerup() -> AudioStreamWAV:
	return _tones("powerup", [[523, 0.07], [659, 0.07], [784, 0.07], [1046, 0.14]], "sine", 0.55)


static func ink() -> AudioStreamWAV:
	return _tones("ink", [[180, 0.08], [140, 0.1], [110, 0.18]], "saw", 0.35)


static func level_up() -> AudioStreamWAV:
	return _tones("level", [[392, 0.1], [523, 0.1], [659, 0.1], [784, 0.25]], "square", 0.3)


static func shoot() -> AudioStreamWAV:
	return _tones("shoot", [[380, 0.03], [620, 0.04], [900, 0.05]], "sine", 0.45)


static func trap() -> AudioStreamWAV:
	return _tones("trap", [[660, 0.06], [880, 0.06], [1320, 0.14]], "sine", 0.5)


static func wave() -> AudioStreamWAV:
	return _tones("wave", [[220, 0.06], [330, 0.06], [440, 0.06], [660, 0.2]], "saw", 0.3)


static func click() -> AudioStreamWAV:
	return _tones("click", [[700, 0.04]], "sine", 0.4)

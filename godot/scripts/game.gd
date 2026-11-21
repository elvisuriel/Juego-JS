class_name Game
extends RefCounted
## Estado que sobrevive entre escenas y partidas: récords, diamantes
## acumulados (moneda de la tienda), skins, ajustes y la partida en curso.

const SAVE_PATH := "user://atlantis.cfg"
const MAX_RECORDS := 5
const START_LIVES := 3
const MAX_LIVES := 5

## Skins del caballito (el rosa original está en 336°): giro de tono (0-1), saturación, brillo y precio.
const SKINS := [
	{"id": "rosa", "name": "Rosa", "hue": 0.0, "sat": 1.0, "val": 1.0, "price": 0},
	{"id": "dorado", "name": "Dorado", "hue": 0.2, "sat": 1.0, "val": 1.15, "price": 30},
	{"id": "azul", "name": "Azul", "hue": 0.65, "sat": 1.0, "val": 1.0, "price": 60},
	{"id": "verde", "name": "Verde", "hue": 0.44, "sat": 0.9, "val": 0.95, "price": 100},
	{"id": "morado", "name": "Morado", "hue": 0.845, "sat": 1.0, "val": 0.95, "price": 150},
	{"id": "arcoiris", "name": "Arcoíris", "hue": 0.0, "sat": 1.2, "val": 1.1, "price": 300, "rainbow": true},
]

# --- Guardado ---
static var records: Array = []          # [{name, score, level}]
static var bank := 0                    # diamantes para la tienda
static var owned: Array = ["rosa"]
static var skin := "rosa"
static var music_on := true
static var sound_on := true
static var vibration_on := true
static var joystick := false            # false = mantener el dedo
static var last_name := "JUGADOR"

# --- Partida en curso (no se guarda) ---
static var level := 1
static var run_score := 0
static var run_lives := START_LIVES

static var _loaded := false
static var _skin_shader: Shader


static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	records = cfg.get_value("game", "records", [])
	# Versiones anteriores solo guardaban un número
	var old_high: int = cfg.get_value("game", "high_score", 0)
	if records.is_empty() and old_high > 0:
		records = [{"name": "RÉCORD", "score": old_high, "level": 1}]
	bank = cfg.get_value("game", "bank", 0)
	owned = cfg.get_value("game", "owned", ["rosa"])
	skin = cfg.get_value("game", "skin", "rosa")
	music_on = cfg.get_value("settings", "music", true)
	sound_on = cfg.get_value("settings", "sound", true)
	vibration_on = cfg.get_value("settings", "vibration", true)
	joystick = cfg.get_value("settings", "joystick", false)
	last_name = cfg.get_value("game", "last_name", "JUGADOR")


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "records", records)
	cfg.set_value("game", "bank", bank)
	cfg.set_value("game", "owned", owned)
	cfg.set_value("game", "skin", skin)
	cfg.set_value("game", "last_name", last_name)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sound", sound_on)
	cfg.set_value("settings", "vibration", vibration_on)
	cfg.set_value("settings", "joystick", joystick)
	cfg.save(SAVE_PATH)


static func high_score() -> int:
	return records[0].score if not records.is_empty() else 0


static func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	return records.size() < MAX_RECORDS or score > records[-1].score


static func add_record(player: String, score: int, lvl: int) -> void:
	records.append({"name": player, "score": score, "level": lvl})
	records.sort_custom(func(a, b): return a.score > b.score)
	records = records.slice(0, MAX_RECORDS)
	last_name = player
	save()


static func new_run() -> void:
	level = 1
	run_score = 0
	run_lives = START_LIVES


## Dificultad de cada nivel.
static func level_config(lvl: int) -> Dictionary:
	var n := lvl - 1
	return {
		"world": Vector2(3400 + 500 * n, 2000 + 300 * n),
		"diamonds": 25 + 5 * mini(n, 5),
		"time": 75 + 10 * mini(n, 4),
		"sharks": mini(3 + n, 9),
		"chase_speed": minf(4.4 + 0.45 * n, 7.2),
		"big_sharks": 1 if lvl >= 2 else 0,
		"fast_sharks": mini(maxi(n - 1, 0), 3),
		"octopus": mini(maxi(n, 0), 3) if lvl >= 2 else 0,
		"powerups": 5,
		"hideouts": 6 + n,
	}


static func skin_data(id: String) -> Dictionary:
	for s in SKINS:
		if s.id == id:
			return s
	return SKINS[0]


## Material que recolorea el caballito según la skin.
static func skin_material(id: String) -> ShaderMaterial:
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = """
shader_type canvas_item;
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;
uniform bool rainbow = false;
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	float h = hue;
	if (rainbow) {
		h += TIME * 0.25 + UV.y * 0.8;
	}
	hsv.x = fract(hsv.x + h);
	hsv.y = clamp(hsv.y * sat, 0.0, 1.0);
	hsv.z = clamp(hsv.z * val, 0.0, 1.0);
	COLOR = vec4(hsv2rgb(hsv), tex.a) * v_modulate;
}
"""
	var d := skin_data(id)
	var m := ShaderMaterial.new()
	m.shader = _skin_shader
	m.set_shader_parameter("hue", d.hue)
	m.set_shader_parameter("sat", d.sat)
	m.set_shader_parameter("val", d.val)
	m.set_shader_parameter("rainbow", d.get("rainbow", false))
	return m


static func vibrate(ms: int) -> void:
	if vibration_on:
		Input.vibrate_handheld(ms)

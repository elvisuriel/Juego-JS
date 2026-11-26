extends Area2D
## El caballito de mar: nada hacia donde apuntes y atrapa diamantes.
## En PC sigue el mouse; en celular nada mientras mantienes el dedo
## (o con el joystick, si está activado en Ajustes).

signal diamond_caught(diamond: Area2D)
signal powerup_caught(powerup: Area2D)

const FOLLOW := 0.04          # qué tan rápido acelera hacia el puntero
const MAX_SPEED := 9.0        # píxeles por frame (a 60 FPS)
const TURBO_FACTOR := 1.7
const SMILE_TIME := 0.8       # segundos que dura la sonrisa
const MARGIN := 60.0          # distancia mínima al borde del mapa
const HURT_TIME := 2.0        # segundos de invulnerabilidad tras un mordisco
const KNOCKBACK := 22.0       # empujón al ser mordido (px por frame)

var active := false
var bounds := Rect2(0, 0, 3400, 2000)
var in_hideout := false       # dentro de un bosque de algas
var turbo_left := 0.0
var shield := false
var joystick: Control         # si existe, manda sobre el dedo/mouse
var world: SeaWorld           # mundo 3D: convierte el dedo y el joystick
var facing := Vector2.RIGHT   # hacia dónde dispara
var triple_left := 0.0        # poder de triple disparo
## Si devuelve true para un punto, ese toque es de un botón y no mueve al caballito.
var ui_block: Callable

var _smile_left := 0.0
var _pressing := false
var _touch_mode := false
var _hurt_left := 0.0
var _knock := Vector2.ZERO
var _t := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_touch_mode = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	sprite.material = Game.skin_material(Game.skin)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and ui_block.is_valid() and ui_block.call(event.position):
			return
		_pressing = event.pressed


func _process(delta: float) -> void:
	_t += delta
	if _smile_left > 0.0:
		_smile_left -= delta
		if _smile_left <= 0.0:
			sprite.frame = 0

	turbo_left = maxf(turbo_left - delta, 0.0)
	triple_left = maxf(triple_left - delta, 0.0)

	var mod := Color.WHITE
	if _hurt_left > 0.0:
		_hurt_left -= delta
		# Parpadea mientras es invulnerable
		mod = Color(1, 0.45, 0.45, 0.35 if fmod(_hurt_left, 0.2) < 0.1 else 0.9)
	elif in_hideout:
		mod = Color(0.75, 1, 0.8, 0.75)
	sprite.modulate = mod
	queue_redraw()

	if not active:
		return

	var f := delta * 60.0
	var top := MAX_SPEED * (TURBO_FACTOR if turbo_left > 0.0 else 1.0)
	var step := Vector2.ZERO
	if joystick:
		var v: Vector2 = joystick.vector
		if absf(v.x) > 0.1:
			sprite.flip_h = v.x < 0.0
		# La cámara está en diagonal: "arriba" en pantalla no es "arriba" en el mapa
		if world:
			v = world.screen_dir_to_world(v)
		if v.length() > 0.2:
			facing = v.normalized()
		step = v * top * f
	elif not (_touch_mode and not _pressing):
		var pointer := world.pointer_world() if world else get_global_mouse_position()
		var dist := pointer - global_position
		if dist.length() > 40.0:
			facing = dist.normalized()
		var sx := world.screen_x(dist) if world else dist.x
		if absf(sx) > 4.0:
			sprite.flip_h = sx < 0.0
		var follow := FOLLOW * (1.6 if turbo_left > 0.0 else 1.0)
		step = dist * (1.0 - pow(1.0 - follow, f))
		step = step.limit_length(top * f)

	step += _knock * f
	_knock = _knock.lerp(Vector2.ZERO, 1.0 - pow(0.85, f))

	var min_p := bounds.position + Vector2(MARGIN, MARGIN)
	var max_p := bounds.end - Vector2(MARGIN, MARGIN)
	global_position = (global_position + step).clamp(min_p, max_p)


func _draw() -> void:
	if shield:
		var r := 92.0 + sin(_t * 5.0) * 4.0
		draw_circle(Vector2.ZERO, r, Color(0.37, 0.88, 1.0, 0.16))
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.6, 0.95, 1.0, 0.85), 4.0, true)
	if turbo_left > 0.0:
		for i in 3:
			var y := -40.0 + i * 40.0
			var x := 50.0 if sprite.flip_h else -50.0
			var len := 30.0 + sin(_t * 20.0 + i) * 12.0
			draw_line(Vector2(x, y), Vector2(x + (len if sprite.flip_h else -len), y), Color(1, 0.75, 0.2, 0.8), 5.0, true)


func is_invulnerable() -> bool:
	return _hurt_left > 0.0


## Mordisco: si tiene escudo, lo gasta; si no, empujón y rato invulnerable.
## Devuelve true si el mordisco quitó vida.
func hurt(from: Vector2) -> bool:
	var away := global_position - from
	_knock = (away.normalized() if away.length() > 1.0 else Vector2.UP) * KNOCKBACK
	_hurt_left = HURT_TIME
	if shield:
		shield = false
		return false
	return true


func smile() -> void:
	sprite.frame = 1
	_smile_left = SMILE_TIME


func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	if area.is_in_group("diamonds"):
		diamond_caught.emit(area)
	elif area.is_in_group("powerups"):
		powerup_caught.emit(area)

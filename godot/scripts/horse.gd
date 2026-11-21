extends Area2D
## El caballito de mar: nada hacia donde apuntes y atrapa diamantes.
## En PC sigue el mouse; en celular nada mientras mantienes el dedo.

signal diamond_caught(diamond: Area2D)

const FOLLOW := 0.04          # qué tan rápido acelera hacia el puntero
const MAX_SPEED := 9.0        # píxeles por frame (a 60 FPS)
const SMILE_TIME := 0.8       # segundos que dura la sonrisa
const MARGIN := 60.0          # distancia mínima al borde del mapa
const HURT_TIME := 2.0        # segundos de invulnerabilidad tras un mordisco
const KNOCKBACK := 22.0       # empujón al ser mordido (px por frame)

var active := false
var bounds := Rect2(0, 0, 3400, 2000)
var _smile_left := 0.0
var _pressing := false
var _touch_mode := false
var _hurt_left := 0.0
var _knock := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_touch_mode = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressing = event.pressed


func _process(delta: float) -> void:
	if _smile_left > 0.0:
		_smile_left -= delta
		if _smile_left <= 0.0:
			sprite.frame = 0

	if _hurt_left > 0.0:
		_hurt_left -= delta
		# Parpadea mientras es invulnerable
		sprite.modulate = Color(1, 0.45, 0.45, 0.35 if fmod(_hurt_left, 0.2) < 0.1 else 0.9)
		if _hurt_left <= 0.0:
			sprite.modulate = Color.WHITE

	if not active:
		return

	var f := delta * 60.0
	var step := Vector2.ZERO
	if not (_touch_mode and not _pressing):
		var dist := get_global_mouse_position() - global_position
		if absf(dist.x) > 4.0:
			sprite.flip_h = dist.x < 0.0
		step = dist * (1.0 - pow(1.0 - FOLLOW, f))
		step = step.limit_length(MAX_SPEED * f)

	step += _knock * f
	_knock = _knock.lerp(Vector2.ZERO, 1.0 - pow(0.85, f))

	var min_p := bounds.position + Vector2(MARGIN, MARGIN)
	var max_p := bounds.end - Vector2(MARGIN, MARGIN)
	global_position = (global_position + step).clamp(min_p, max_p)


func is_invulnerable() -> bool:
	return _hurt_left > 0.0


## Mordisco de tiburón: empujón lejos de él y un rato invulnerable.
func hurt(from: Vector2) -> void:
	_hurt_left = HURT_TIME
	var away := global_position - from
	_knock = (away.normalized() if away.length() > 1.0 else Vector2.UP) * KNOCKBACK


func smile() -> void:
	sprite.frame = 1
	_smile_left = SMILE_TIME


func _on_area_entered(area: Area2D) -> void:
	if active and area.is_in_group("diamonds"):
		diamond_caught.emit(area)

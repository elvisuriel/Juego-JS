extends Area2D
## El caballito de mar: nada hacia donde apuntes y atrapa diamantes.
## En PC sigue el mouse; en celular nada mientras mantienes el dedo.

signal diamond_caught(diamond: Area2D)

const FOLLOW := 0.04          # qué tan rápido acelera hacia el puntero
const MAX_SPEED := 9.0        # píxeles por frame (a 60 FPS)
const SMILE_TIME := 0.8       # segundos que dura la sonrisa
const MARGIN := 60.0          # distancia mínima al borde del mapa

var active := false
var bounds := Rect2(0, 0, 3400, 2000)
var _smile_left := 0.0
var _pressing := false
var _touch_mode := false

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

	if not active or (_touch_mode and not _pressing):
		return

	var f := delta * 60.0
	var dist := get_global_mouse_position() - global_position
	if absf(dist.x) > 4.0:
		sprite.flip_h = dist.x < 0.0

	var step := dist * (1.0 - pow(1.0 - FOLLOW, f))
	step = step.limit_length(MAX_SPEED * f)

	var min_p := bounds.position + Vector2(MARGIN, MARGIN)
	var max_p := bounds.end - Vector2(MARGIN, MARGIN)
	global_position = (global_position + step).clamp(min_p, max_p)


func smile() -> void:
	sprite.frame = 1
	_smile_left = SMILE_TIME


func _on_area_entered(area: Area2D) -> void:
	if active and area.is_in_group("diamonds"):
		diamond_caught.emit(area)

extends Area2D
## El caballito de mar: sigue el dedo/mouse y atrapa diamantes.

signal diamond_caught(diamond: Area2D)

const FOLLOW := 0.02          # suavidad del seguimiento (a 60 FPS)
const SMILE_TIME := 0.8       # segundos que dura la sonrisa

var active := false
var _smile_left := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _smile_left > 0.0:
		_smile_left -= delta
		if _smile_left <= 0.0:
			sprite.frame = 0

	if not active:
		return

	var dist := get_global_mouse_position() - global_position
	if absf(dist.x) > 1.0:
		sprite.flip_h = dist.x < 0.0

	# Lerp independiente de los FPS
	var follow := 1.0 - pow(1.0 - FOLLOW, delta * 60.0)
	global_position += dist * follow


func smile() -> void:
	sprite.frame = 1
	_smile_left = SMILE_TIME


func _on_area_entered(area: Area2D) -> void:
	if active and area.is_in_group("diamonds"):
		diamond_caught.emit(area)

extends Control
## Vidas del caballito, dibujadas como corazones (sin depender de emojis
## en la fuente, que en Android pueden no aparecer).

const FULL := Color("#ff4f6d")
const EMPTY := Color(0, 0, 0, 0.35)
const OUTLINE := Color(0, 0, 0, 0.6)
const HEART_SIZE := 30.0
const GAP := 8.0

var max_lives := 3
var lives := 3:
	set(v):
		lives = v
		queue_redraw()

var _heart: PackedVector2Array


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		_heart.append(Vector2(x, y) / 34.0 * HEART_SIZE)


func _draw() -> void:
	for i in max_lives:
		var c := Vector2(HEART_SIZE / 2.0 + i * (HEART_SIZE + GAP), HEART_SIZE / 2.0)
		var pts := PackedVector2Array()
		for p in _heart:
			pts.append(p + c)
		draw_colored_polygon(pts, FULL if i < lives else EMPTY)
		pts.append(pts[0])
		draw_polyline(pts, OUTLINE, 2.0, true)

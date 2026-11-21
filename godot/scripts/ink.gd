extends Control
## Manchas de tinta del pulpo sobre la pantalla; se desvanecen solas.

const DURATION := 3.5

var _blots: Array = []      # [centro, radio, forma]
var _left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func splash() -> void:
	_left = DURATION
	_blots.clear()
	var view := get_viewport_rect().size
	for i in 5:
		var c := Vector2(randf_range(0.15, 0.85) * view.x, randf_range(0.15, 0.85) * view.y)
		var shape := PackedFloat32Array()
		for k in 18:
			shape.append(randf_range(0.7, 1.2))
		_blots.append([c, randf_range(70, 130), shape])
	queue_redraw()


func clear() -> void:
	_left = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		queue_redraw()


func _draw() -> void:
	if _left <= 0.0:
		return
	var a := clampf(_left / 1.2, 0.0, 1.0) * 0.85
	for b in _blots:
		var c: Vector2 = b[0]
		var r: float = b[1]
		var shape: PackedFloat32Array = b[2]
		var pts := PackedVector2Array()
		for k in shape.size():
			pts.append(c + Vector2.from_angle(TAU * k / shape.size()) * r * shape[k])
		draw_colored_polygon(pts, Color(0.08, 0.02, 0.12, a))
		draw_circle(c + Vector2(r * 0.9, r * 0.5), r * 0.18, Color(0.08, 0.02, 0.12, a))

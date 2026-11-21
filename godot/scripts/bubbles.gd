extends Node2D
## Burbujas planas que suben por todo el mapa.

const AMOUNT := 140
const FILL := Color(1, 1, 1, 0.12)
const OUTLINE := Color(1, 1, 1, 0.35)

var world_size := Vector2(3400, 2000)
var _pos: PackedVector2Array = []
var _vel: PackedFloat32Array = []
var _radius: PackedFloat32Array = []


func setup(size: Vector2) -> void:
	world_size = size
	_pos.clear(); _vel.clear(); _radius.clear()
	for i in AMOUNT:
		_pos.append(Vector2(randf() * size.x, randf() * size.y))
		_vel.append(0.3 + randf() * 1.6)
		_radius.append(3.0 + randf() * 11.0)


func _process(delta: float) -> void:
	var f := delta * 60.0
	for i in _pos.size():
		var p := _pos[i]
		p.y -= _vel[i] * f
		p.x += sin((p.y + i * 37.0) * 0.02) * 0.3 * f
		if p.y < -20.0:
			p = Vector2(randf() * world_size.x, world_size.y + 20.0)
		_pos[i] = p
	queue_redraw()


func _draw() -> void:
	for i in _pos.size():
		draw_circle(_pos[i], _radius[i], FILL)
		draw_arc(_pos[i], _radius[i], 0.0, TAU, 16, OUTLINE, 1.5)

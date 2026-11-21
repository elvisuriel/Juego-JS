class_name Hideout
extends Node2D
## Bosque de algas: si el caballito se mete aquí, los tiburones no lo ven.

const RADIUS := 130.0
const STEM := Color("#2f9a63")
const LEAF := Color("#49c27f")
const BASE := Color(0.1, 0.35, 0.25, 0.35)

var _stalks: Array = []     # [offset, alto, fase]
var _t := 0.0
var occupied := false


func _ready() -> void:
	z_index = 2              # por encima del caballito: lo tapa
	for i in 16:
		var a := randf() * TAU
		var r := sqrt(randf()) * RADIUS * 0.85
		_stalks.append([Vector2.from_angle(a) * r, randf_range(70, 130), randf() * TAU])
	_stalks.sort_custom(func(x, y): return x[0].y < y[0].y)


func contains(p: Vector2) -> bool:
	return global_position.distance_to(p) < RADIUS * 0.8


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, BASE)
	var alpha := 0.55 if occupied else 1.0
	for s in _stalks:
		var base: Vector2 = s[0] + Vector2(0, 40)
		var h: float = s[1]
		var ph: float = s[2]
		var pts := PackedVector2Array()
		for k in 7:
			var y := -h * k / 6.0
			pts.append(base + Vector2(sin(_t * 1.6 + ph + k * 0.6) * k * 2.2, y))
		draw_polyline(pts, Color(STEM, alpha), 7.0, true)
		for k in range(2, 7, 2):
			var side := 1.0 if k % 4 == 0 else -1.0
			draw_circle(pts[k] + Vector2(side * 8, 0), 7.0, Color(LEAF, alpha))

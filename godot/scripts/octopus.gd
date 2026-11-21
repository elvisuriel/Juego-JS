class_name Octopus
extends Node2D
## Pulpo: nada despacio y, si el caballito se acerca, le lanza tinta
## que tapa la pantalla unos segundos.

signal inked(octopus: Octopus)

const RANGE := 300.0
const COOLDOWN := 6.0
const SPEED := 1.1
const COLOR := Color("#b35bd6")
const DARK := Color("#7a3596")

var horse: Node2D
var bounds := Rect2(0, 0, 3400, 2000)
var hunting := false

var _t := 0.0
var _cool := 0.0
var _target := Vector2.ZERO
var _squish := 0.0


func _ready() -> void:
	_t = randf() * TAU
	_pick_target()


func _process(delta: float) -> void:
	var f := delta * 60.0
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_squish = maxf(_squish - delta * 2.0, 0.0)

	var to_target := _target - global_position
	if to_target.length() < 40.0:
		_pick_target()
	# Nada a impulsos, como un pulpo de verdad
	var pulse := maxf(sin(_t * 2.5), 0.0)
	global_position += to_target.normalized() * SPEED * (0.3 + pulse * 1.6) * f

	if hunting and horse and _cool <= 0.0 and global_position.distance_to(horse.global_position) < RANGE:
		_cool = COOLDOWN
		_squish = 1.0
		inked.emit(self)
	queue_redraw()


func _pick_target() -> void:
	var r := bounds.grow(-200)
	_target = Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


func _draw() -> void:
	var pulse := sin(_t * 2.5)
	var sq := 1.0 + _squish * 0.35
	# Sombra
	draw_set_transform(Vector2(8, 30), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 50, Color(0, 0.08, 0.15, 0.18))
	draw_set_transform(Vector2.ZERO)
	# Tentáculos
	for i in 8:
		var a := PI * 0.15 + PI * 0.7 * i / 7.0
		var pts := PackedVector2Array()
		for k in 8:
			var r := 18.0 + k * 9.0
			var wave := sin(_t * 3.0 + k * 0.7 + i) * k * 1.6
			pts.append(Vector2.from_angle(a) * r * Vector2(1.0, 1.0 + pulse * 0.08) + Vector2(wave, 0))
		draw_polyline(pts, DARK, 11.0 - 0.0, true)
		draw_polyline(pts, COLOR, 7.0, true)
	# Cabeza
	draw_set_transform(Vector2(0, -12), 0, Vector2(1.0 / sq, sq))
	draw_circle(Vector2.ZERO, 36, DARK)
	draw_circle(Vector2.ZERO, 32, COLOR)
	draw_circle(Vector2(-10, -12), 8, Color(1, 1, 1, 0.25))
	draw_set_transform(Vector2.ZERO)
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(12 * side, -4), 8, Color.WHITE)
		draw_circle(Vector2(12 * side + 2, -3), 4, Color.BLACK)

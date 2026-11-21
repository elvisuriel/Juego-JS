class_name WorldMap
extends Node2D
## Mapa del fondo marino en colores planos, generado al azar en cada partida.

const WATER := Color("#2b86c5")
const WATER_DEEP := Color("#2373ad")
const SAND := Color("#f3d79e")
const SAND_EDGE := Color("#e2bb74")
const REEF := Color("#ff8a6b")
const KELP := Color("#3fae74")
const ROCK := Color("#5d6f82")
const GRID := Color(1, 1, 1, 0.07)
const BORDER := Color("#174e78")
const GRID_STEP := 200.0

var size := Vector2(3400, 2000)
## Cada forma: { "poly": PackedVector2Array, "color": Color }
var shapes: Array[Dictionary] = []


func generate(world_size: Vector2, rng: RandomNumberGenerator) -> void:
	size = world_size
	shapes.clear()

	# Zonas profundas (manchas grandes y oscuras)
	for i in 9:
		_add_blob(_rand_point(rng, 0), rng.randf_range(260, 460), [WATER_DEEP], rng)

	# Bancos de arena con borde
	for i in 11:
		_add_blob(_rand_point(rng, 150), rng.randf_range(90, 220), [SAND_EDGE, SAND], rng)

	# Arrecifes y algas
	for i in 28:
		var color := REEF if rng.randf() < 0.5 else KELP
		_add_blob(_rand_point(rng, 60), rng.randf_range(22, 55), [color], rng)

	# Rocas
	for i in 16:
		_add_blob(_rand_point(rng, 60), rng.randf_range(18, 42), [ROCK], rng)

	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)

	for s in shapes:
		draw_colored_polygon(s.poly, s.color)

	var x := GRID_STEP
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 2.0)
		x += GRID_STEP
	var y := GRID_STEP
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 2.0)
		y += GRID_STEP

	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 16.0)


func _rand_point(rng: RandomNumberGenerator, margin: float) -> Vector2:
	return Vector2(rng.randf_range(margin, size.x - margin), rng.randf_range(margin, size.y - margin))


## Agrega una mancha irregular. Si se pasan varios colores, se dibujan
## concéntricos (el primero más grande), útil para bordes.
func _add_blob(center: Vector2, radius: float, colors: Array, rng: RandomNumberGenerator) -> void:
	var points := 16
	var offsets: Array[float] = []
	for k in points:
		offsets.append(rng.randf_range(0.72, 1.15))

	for c in colors.size():
		var scale_factor := 1.0 - 0.14 * c
		var poly := PackedVector2Array()
		for k in points:
			var angle := TAU * k / points
			poly.append(center + Vector2.from_angle(angle) * radius * offsets[k] * scale_factor)
		shapes.append({"poly": poly, "color": colors[c]})

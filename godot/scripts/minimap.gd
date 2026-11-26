extends Control
## Minimapa en rombo (girado igual que la cámara): las regiones del mar,
## dónde estás y un radar con los diamantes y enemigos cercanos
## (los lejanos hay que encontrarlos explorando).

const RADAR_RANGE := 900.0
const HORSE := Color("#ff4f9a")
const DIAMOND := Color("#ffe066")
const RADAR := Color(1, 1, 1, 0.3)
const SHARK := Color("#ff3b3b")

var world: SeaWorld
var horse: Node2D
var diamonds_root: Node2D
var sharks: Array = []
var hideouts: Array = []
var octopi: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or horse == null:
		return
	var units := world.size
	var k := size.x / (units.x * 1.42)
	var center := size / 2.0
	# mapa (px del juego) → minimapa
	var xf := Transform2D(0.0, center) * world.minimap_basis() * Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO) * Transform2D(0.0, -units / 2.0)
	var px := Transform2D(0.0, Vector2(SeaWorld.S, SeaWorld.S), 0.0, Vector2.ZERO)

	draw_set_transform_matrix(xf)
	draw_texture_rect(world.region_texture(), Rect2(Vector2.ZERO, units), false)
	draw_rect(Rect2(Vector2.ZERO, units), Color("#0d3a5c"), false, 0.8)

	draw_set_transform_matrix(xf * px)
	var inv := 1.0 / (k * SeaWorld.S)
	for h in hideouts:
		draw_circle(h.global_position, Hideout.RADIUS, Color(0.2, 0.75, 0.45, 0.7))

	var hp := horse.global_position
	draw_arc(hp, RADAR_RANGE, 0.0, TAU, 40, RADAR, 1.2 * inv)
	if diamonds_root:
		for d in diamonds_root.get_children():
			if not d.is_queued_for_deletion() and d.global_position.distance_to(hp) <= RADAR_RANGE:
				draw_circle(d.global_position, 2.6 * inv, DIAMOND)
	for sh in sharks:
		if is_instance_valid(sh) and sh.global_position.distance_to(hp) <= RADAR_RANGE:
			draw_circle(sh.global_position, 3.0 * inv, SHARK)
	for o in octopi:
		if is_instance_valid(o) and o.global_position.distance_to(hp) <= RADAR_RANGE:
			draw_circle(o.global_position, 3.0 * inv, Octopus.COLOR)
	draw_circle(hp, 4.2 * inv, Color.WHITE)
	draw_circle(hp, 3.2 * inv, HORSE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

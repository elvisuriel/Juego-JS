extends Control
## Minimapa: muestra el mapa, dónde estás y un radar con los
## diamantes cercanos (los lejanos hay que encontrarlos explorando).

const RADAR_RANGE := 650.0
const VIEW := Color(1, 1, 1, 0.8)
const HORSE := Color("#ff4f9a")
const DIAMOND := Color("#ffe066")
const RADAR := Color(1, 1, 1, 0.25)
const SHARK := Color("#ff3b3b")

var world_map: WorldMap
var horse: Node2D
var diamonds_root: Node2D
var camera: Camera2D
var sharks: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world_map == null or horse == null:
		return

	var k := size.x / world_map.size.x
	
	var xf := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, world_map.size * k), WorldMap.WATER)
	for s in world_map.shapes:
		draw_colored_polygon(xf * s.poly, s.color)
	draw_rect(Rect2(Vector2.ZERO, size), WorldMap.BORDER, false, 3.0)

	# Lo que se ve en pantalla
	if camera:
		var view_size := get_viewport_rect().size / camera.zoom
		var view_pos := camera.get_screen_center_position() - view_size / 2.0
		draw_rect(Rect2(view_pos * k, view_size * k), VIEW, false, 1.5)

	# Radar
	var hp := horse.global_position
	draw_arc(hp * k, RADAR_RANGE * k, 0.0, TAU, 32, RADAR, 1.0)
	if diamonds_root:
		for d in diamonds_root.get_children():
			if d.is_queued_for_deletion():
				continue
			if d.global_position.distance_to(hp) <= RADAR_RANGE:
				draw_circle(d.global_position * k, 3.0, DIAMOND)

	# Tiburones cercanos en rojo, para poder esquivarlos
	for sh in sharks:
		if is_instance_valid(sh) and sh.global_position.distance_to(hp) <= RADAR_RANGE:
			draw_circle(sh.global_position * k, 3.5, SHARK)

	draw_circle(hp * k, 4.0, HORSE)

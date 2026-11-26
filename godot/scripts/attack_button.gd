extends Control
## Botón de disparo de burbujas. En el celular funciona con cualquier dedo
## (se puede mover al caballito con uno y disparar con otro).
## Muestra la energía: un puntito por cada disparo disponible.

signal fired

const RADIUS := 60.0
const COLOR := Color("#5ee0ff")

var energy := 5.0
var max_energy := 5
var triple := false
var _pressed_t := 0.0
var _touch := false


func _ready() -> void:
	size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch = DisplayServer.is_touchscreen_available()


func has_screen_point(p: Vector2) -> bool:
	return (p - global_position - size / 2.0).length() <= RADIUS + 10.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif not _touch and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos != Vector2.INF and has_screen_point(pos):
		_pressed_t = 0.12
		fired.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_pressed_t = maxf(_pressed_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var ready := energy >= 1.0
	var col: Color = PowerUp.COLORS[PowerUp.Kind.TRIPLE] if triple else COLOR
	var r := RADIUS * (0.92 if _pressed_t > 0.0 else 1.0)
	draw_circle(c, r, Color(0, 0.1, 0.2, 0.35))
	draw_circle(c, r - 6.0, Color(col, 0.35 if ready else 0.12))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.8 if ready else 0.3), 4.0, true)
	# Burbujas dibujadas
	var bubbles := [[Vector2(-10, 6), 16.0], [Vector2(14, -10), 10.0], [Vector2(12, 14), 7.0]]
	if triple:
		bubbles = [[Vector2(-16, 8), 11.0], [Vector2(0, -10), 11.0], [Vector2(16, 8), 11.0]]
	for b in bubbles:
		var p: Vector2 = c + b[0]
		draw_circle(p, b[1], Color(1, 1, 1, 0.25 if ready else 0.1))
		draw_arc(p, b[1], 0, TAU, 24, Color(1, 1, 1, 0.9 if ready else 0.35), 2.5, true)
		draw_circle(p + Vector2(-b[1] * 0.35, -b[1] * 0.35), b[1] * 0.22, Color(1, 1, 1, 0.8))
	# Energía
	for i in max_energy:
		var a := PI * 0.75 + i * (PI * 0.5 / (max_energy - 1)) + PI * 0.25
		var p := c + Vector2.from_angle(a) * (r + 14.0)
		var full := energy >= i + 1
		var part := clampf(energy - i, 0.0, 1.0)
		draw_circle(p, 6.0, Color(0, 0, 0, 0.35))
		draw_circle(p, 5.0 * (1.0 if full else part), col if full else Color(col, 0.5))

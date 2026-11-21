extends Control
## Joystick en pantalla (opcional, se activa en Ajustes).
## vector: dirección y fuerza (0–1).

const RADIUS := 90.0
const KNOB := 42.0

var vector := Vector2.ZERO
var _active := false
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	size = custom_minimum_size


func _gui_input(event: InputEvent) -> void:
	# En el celular el dedo llega como mouse emulado
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_active = event.pressed
		if _active:
			_move(event.position)
		else:
			vector = Vector2.ZERO
			_knob = Vector2.ZERO
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _active:
		_move(event.position)
		accept_event()


func _move(p: Vector2) -> void:
	var d := (p - size / 2.0).limit_length(RADIUS)
	_knob = d
	vector = d / RADIUS
	if vector.length() < 0.15:
		vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	draw_circle(c + _knob, KNOB, Color(1, 1, 1, 0.55 if _active else 0.35))

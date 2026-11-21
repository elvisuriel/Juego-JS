class_name PowerUp
extends Area2D
## Burbuja con un poder: turbo, escudo, corazón o reloj.

enum Kind { TURBO, SHIELD, HEART, CLOCK }

const COLORS := {
	Kind.TURBO: Color("#ffb020"),
	Kind.SHIELD: Color("#5ee0ff"),
	Kind.HEART: Color("#ff4f6d"),
	Kind.CLOCK: Color("#b48cff"),
}
const NAMES := {
	Kind.TURBO: "¡TURBO!",
	Kind.SHIELD: "¡ESCUDO!",
	Kind.HEART: "¡+1 VIDA!",
	Kind.CLOCK: "¡+10 SEGUNDOS!",
}
const RADIUS := 34.0

var kind := Kind.TURBO
var _t := 0.0


func _ready() -> void:
	add_to_group("powerups")
	monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, sin(_t * 2.0) * 5.0)
	var c: Color = COLORS[kind]
	draw_circle(bob, RADIUS + 6.0 + sin(_t * 4.0) * 3.0, Color(c, 0.18))
	draw_circle(bob, RADIUS, Color(1, 1, 1, 0.2))
	draw_arc(bob, RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.8), 3.0, true)
	draw_circle(bob + Vector2(-12, -14), 6.0, Color(1, 1, 1, 0.6))
	draw_icon(self, kind, bob, 1.0, c)


## Dibuja el ícono del poder (también lo usa el HUD).
static func draw_icon(ci: CanvasItem, k: int, at: Vector2, s: float, c: Color) -> void:
	match k:
		Kind.TURBO:
			var bolt := PackedVector2Array([Vector2(4, -20), Vector2(-12, 3), Vector2(-1, 3), Vector2(-5, 20), Vector2(12, -4), Vector2(1, -4)])
			for i in bolt.size():
				bolt[i] = at + bolt[i] * s
			ci.draw_colored_polygon(bolt, c)
		Kind.SHIELD:
			var sh := PackedVector2Array([Vector2(0, -18), Vector2(15, -11), Vector2(13, 6), Vector2(0, 19), Vector2(-13, 6), Vector2(-15, -11)])
			for i in sh.size():
				sh[i] = at + sh[i] * s
			ci.draw_colored_polygon(sh, c)
		Kind.HEART:
			var pts := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				pts.append(at + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 1.1 * s)
			ci.draw_colored_polygon(pts, c)
		Kind.CLOCK:
			ci.draw_circle(at, 17.0 * s, c)
			ci.draw_arc(at, 17.0 * s, 0, TAU, 24, Color.WHITE, 2.5 * s, true)
			ci.draw_line(at, at + Vector2(0, -11) * s, Color.WHITE, 3.0 * s)
			ci.draw_line(at, at + Vector2(8, 0) * s, Color.WHITE, 3.0 * s)

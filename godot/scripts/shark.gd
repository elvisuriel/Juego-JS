class_name Shark
extends Node2D
## Tiburón en 3D: el modelo se genera por código y se dibuja en un
## SubViewport visto desde arriba en diagonal, así encaja en el mapa 2D.
## Patrulla el mapa y, si el caballito se acerca, lo persigue.

signal bitten(shark: Shark)

const VIEW_PX := 384              # resolución del render 3D
const SCREEN_SIZE := 350.0        # tamaño en pantalla (px)
const PATROL_SPEED := 2.0         # px por frame (60 FPS)
const CHASE_SPEED := 4.8          # el caballito llega a 9: se puede escapar
const DETECT_RANGE := 430.0
const GIVE_UP_TIME := 4.5         # segundos persiguiendo antes de rendirse
const REST_TIME := 2.5            # segundos sin perseguir tras morder o rendirse
const TURN := 0.05                # qué tan rápido gira
const MOUTH_OFFSET := 115.0       # distancia del centro a la boca (px)
const BITE_RADIUS := 55.0
const MARGIN := 120.0

enum Mode { PATROL, CHASE, REST }

var horse: Node2D
var bounds := Rect2(0, 0, 3400, 2000)
var hunting := false              # solo persigue mientras se juega

var _mode := Mode.PATROL
var _mode_time := 0.0
var _vel := Vector2.LEFT * PATROL_SPEED
var _target := Vector2.ZERO
var _roll := 0.0
var _yaw := PI

var _pivot: Node3D
var _material: ShaderMaterial


func _ready() -> void:
	_build_view()
	_pick_target()


func _process(delta: float) -> void:
	var f := delta * 60.0
	_mode_time += delta

	var to_horse := Vector2.INF
	if horse:
		to_horse = horse.global_position - global_position

	match _mode:
		Mode.PATROL:
			if hunting and to_horse.length() < DETECT_RANGE:
				_set_mode(Mode.CHASE)
			elif global_position.distance_to(_target) < 80.0:
				_pick_target()
		Mode.CHASE:
			if not hunting or to_horse.length() > DETECT_RANGE * 1.6 or _mode_time > GIVE_UP_TIME:
				_set_mode(Mode.REST)
		Mode.REST:
			if _mode_time > REST_TIME:
				_set_mode(Mode.PATROL)

	var desired: Vector2
	match _mode:
		Mode.CHASE:
			desired = to_horse.normalized() * CHASE_SPEED
		Mode.REST:
			# Se aleja del caballito para no morderlo de nuevo enseguida
			var away := -to_horse.normalized() if to_horse.length() < DETECT_RANGE else _vel.normalized()
			desired = away * PATROL_SPEED * 1.4
		_:
			desired = (_target - global_position).normalized() * PATROL_SPEED

	var prev_dir := _vel.angle()
	_vel = _vel.lerp(desired, 1.0 - pow(1.0 - TURN, f))
	global_position += _vel * f
	global_position = global_position.clamp(bounds.position + Vector2(MARGIN, MARGIN), bounds.end - Vector2(MARGIN, MARGIN))

	# Orientación del modelo 3D según hacia dónde nada
	if _vel.length() > 0.1:
		_yaw = atan2(-_vel.y, _vel.x)
	var turn_rate := wrapf(_vel.angle() - prev_dir, -PI, PI) / maxf(f, 0.001)
	_roll = lerpf(_roll, clampf(-turn_rate * 18.0, -0.6, 0.6), 0.1)
	_pivot.rotation = Vector3(_roll, _yaw, 0.0)
	_material.set_shader_parameter("swim_speed", 2.5 + _vel.length() * 1.3)
	queue_redraw()

	if hunting and _mode == Mode.CHASE and horse:
		if mouth_position().distance_to(horse.global_position) < BITE_RADIUS:
			bitten.emit(self)


func mouth_position() -> Vector2:
	return global_position + _vel.normalized() * MOUTH_OFFSET


## Lo llama el juego cuando el mordisco cuenta: el tiburón se retira.
func retreat() -> void:
	_set_mode(Mode.REST)
	_vel = -_vel


func _set_mode(m: Mode) -> void:
	_mode = m
	_mode_time = 0.0
	if m == Mode.PATROL:
		_pick_target()


func _pick_target() -> void:
	var r := bounds.grow(-MARGIN * 1.5)
	_target = Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


func _draw() -> void:
	# Sombra en el fondo para que se sienta la profundidad
	draw_set_transform(Vector2(14, 40), _vel.angle(), Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 120.0, Color(0, 0.08, 0.15, 0.18))
	draw_set_transform(Vector2.ZERO)


# --- Render 3D --------------------------------------------------------------

func _build_view() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(VIEW_PX, VIEW_PX)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.6
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.2, 3.0), Vector3.ZERO, Vector3.UP)

	_pivot = Node3D.new()
	vp.add_child(_pivot)

	_material = ShaderMaterial.new()
	_material.shader = SharkMesh.shader()
	_material.set_shader_parameter("phase", randf() * TAU)

	var mi := MeshInstance3D.new()
	mi.mesh = SharkMesh.build()
	mi.material_override = _material
	_pivot.add_child(mi)

	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.scale = Vector2.ONE * (SCREEN_SIZE / VIEW_PX)
	add_child(spr)

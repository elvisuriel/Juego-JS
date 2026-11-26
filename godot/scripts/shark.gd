class_name Shark
extends Node2D
## Tiburón en 3D: el modelo se genera por código y se dibuja en un
## SubViewport visto desde arriba en diagonal, así encaja en el mapa 2D.
## Patrulla el mapa y, si el caballito se acerca, lo persigue.
## Tipos: NORMAL, BIG (grande y lento, muerde de lejos) y FAST (se prepara
## y embiste en línea recta).

signal bitten(shark: Shark)
signal chase_started(shark: Shark)
signal trapped(shark: Shark)

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

const TRAP_TIME := 6.0            # segundos atrapado en la burbuja
const HIT_RADIUS := 95.0          # qué tan fácil es darle con una burbuja (px)
const HP := {Kind.NORMAL: 2, Kind.BIG: 4, Kind.FAST: 1}

const DASH_SPEED := 12.0
const WINDUP_TIME := 0.7
const DASH_TIME := 0.75

enum Mode { PATROL, CHASE, REST, WINDUP, DASH }
enum Kind { NORMAL, BIG, FAST }

var kind := Kind.NORMAL
var chase_speed := CHASE_SPEED

var horse: Node2D
var bounds := Rect2(0, 0, 3400, 2000)
var hunting := false              # solo persigue mientras se juega
## Si se da, el tiburón nada directo en el mundo 3D (juego); si no, se
## dibuja en 2D con su propio SubViewport (menú).
var world: SeaWorld
var hp := 2
var trapped_left := 0.0           # > 0: atrapado, no muerde
var _flash := 0.0
var _bubble: MeshInstance3D

var _mode := Mode.PATROL
var _mode_time := 0.0
var _vel := Vector2.LEFT * PATROL_SPEED
var _target := Vector2.ZERO
var _roll := 0.0
var _yaw := PI

var _pivot: Node3D
var _material: ShaderMaterial
var _size := 1.0
var _dash_dir := Vector2.ZERO
var _sprite: Sprite2D


func _ready() -> void:
	match kind:
		Kind.BIG:
			_size = 1.45
			chase_speed *= 0.72
		Kind.FAST:
			_size = 0.85
	hp = HP[kind]
	if world:
		_build_3d()
	else:
		_build_view()
	_pick_target()


func _process(delta: float) -> void:
	var f := delta * 60.0
	_mode_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_material.set_shader_parameter("flash", _flash * 4.0)
	if trapped_left > 0.0:
		_process_trapped(delta, f)
		return

	var to_horse := Vector2.INF
	if horse:
		to_horse = horse.global_position - global_position
	# Escondido en las algas no lo ven
	var visible_horse: bool = hunting and horse and not horse.get("in_hideout")

	match _mode:
		Mode.PATROL:
			if visible_horse and to_horse.length() < DETECT_RANGE * _size:
				if kind == Kind.FAST:
					_set_mode(Mode.WINDUP)
				else:
					_set_mode(Mode.CHASE)
				chase_started.emit(self)
			elif global_position.distance_to(_target) < 80.0:
				_pick_target()
		Mode.CHASE:
			if not visible_horse or to_horse.length() > DETECT_RANGE * 1.6 or _mode_time > GIVE_UP_TIME:
				_set_mode(Mode.REST)
		Mode.WINDUP:
			if not visible_horse:
				_set_mode(Mode.REST)
			elif _mode_time > WINDUP_TIME:
				_dash_dir = to_horse.normalized()
				_set_mode(Mode.DASH)
		Mode.DASH:
			if _mode_time > DASH_TIME:
				_set_mode(Mode.REST)
		Mode.REST:
			if _mode_time > REST_TIME:
				_set_mode(Mode.PATROL)

	var desired: Vector2
	var turn := TURN
	match _mode:
		Mode.CHASE:
			desired = to_horse.normalized() * chase_speed
		Mode.WINDUP:
			# Se frena y apunta al caballito, temblando
			desired = to_horse.normalized() * 0.4
			turn = 0.2
		Mode.DASH:
			desired = _dash_dir * DASH_SPEED
			turn = 0.5
		Mode.REST:
			# Se aleja del caballito para no morderlo de nuevo enseguida
			var away := -to_horse.normalized() if to_horse.length() < DETECT_RANGE else _vel.normalized()
			desired = away * PATROL_SPEED * 1.4
		_:
			desired = (_target - global_position).normalized() * PATROL_SPEED

	var prev_dir := _vel.angle()
	_vel = _vel.lerp(desired, 1.0 - pow(1.0 - turn, f))
	global_position += _vel * f
	global_position = global_position.clamp(bounds.position + Vector2(MARGIN, MARGIN), bounds.end - Vector2(MARGIN, MARGIN))

	# Orientación del modelo 3D según hacia dónde nada
	if _vel.length() > 0.1:
		_yaw = atan2(-_vel.y, _vel.x)
	var turn_rate := wrapf(_vel.angle() - prev_dir, -PI, PI) / maxf(f, 0.001)
	_roll = lerpf(_roll, clampf(-turn_rate * 18.0, -0.6, 0.6), 0.1)
	_pivot.rotation = Vector3(_roll, _yaw, 0.0)
	_material.set_shader_parameter("swim_speed", 9.0 if _mode == Mode.WINDUP else 2.5 + _vel.length() * 1.3)
	var shake := Vector2(randf_range(-3, 3), randf_range(-3, 3)) if _mode == Mode.WINDUP else Vector2.ZERO
	if world:
		_pivot.position = Vector3((global_position.x + shake.x) * 0.01, SeaWorld.SWIM_Y + sin(_mode_time * 1.7) * 0.06, (global_position.y + shake.y) * 0.01)
	else:
		_sprite.position = shake
		queue_redraw()

	if hunting and (_mode == Mode.CHASE or _mode == Mode.DASH) and horse:
		if mouth_position().distance_to(horse.global_position) < BITE_RADIUS * _size:
			bitten.emit(self)


## Atrapado: flota despacio dentro de la burbuja, dando vueltas.
func _process_trapped(delta: float, f: float) -> void:
	trapped_left -= delta
	_vel = _vel.lerp(Vector2.ZERO, 1.0 - pow(0.95, f))
	global_position += _vel * f
	global_position = global_position.clamp(bounds.position + Vector2(MARGIN, MARGIN), bounds.end - Vector2(MARGIN, MARGIN))
	_yaw += delta * 1.2
	_roll = sin(_mode_time * 3.0) * 0.4
	_pivot.rotation = Vector3(_roll, _yaw, 0.0)
	_material.set_shader_parameter("swim_speed", 12.0)
	var wobble := 1.0 + sin(_mode_time * 6.0) * 0.04
	if world:
		_pivot.position = Vector3(global_position.x * 0.01, SeaWorld.SWIM_Y + 0.3 + sin(_mode_time * 2.0) * 0.12, global_position.y * 0.01)
		if _bubble:
			_bubble.visible = true
			_bubble.scale = Vector3.ONE * wobble * 1.6 * _size
	if trapped_left <= 0.0:
		# Se escapa: rompe la burbuja y se aleja un rato
		hp = HP[kind]
		if _bubble:
			_bubble.visible = false
		_set_mode(Mode.REST)
		_mode_time = -2.0


func is_trapped() -> bool:
	return trapped_left > 0.0


## Le pega una burbuja. Devuelve true si con eso quedó atrapado.
func hit(dir: Vector2, damage := 1) -> bool:
	if trapped_left > 0.0:
		return false
	hp -= damage
	_flash = 0.25
	_vel += dir.normalized() * 7.0
	if hp <= 0:
		trap(TRAP_TIME)
		return true
	# Se enoja: va por el caballito
	if not is_chasing() and hunting:
		_set_mode(Mode.CHASE)
	return false


func trap(t: float) -> void:
	var was := trapped_left > 0.0
	trapped_left = maxf(trapped_left, t)
	_mode_time = 0.0
	if not was:
		trapped.emit(self)


func is_chasing() -> bool:
	return _mode == Mode.CHASE or _mode == Mode.WINDUP or _mode == Mode.DASH


func mouth_position() -> Vector2:
	return global_position + _vel.normalized() * MOUTH_OFFSET * _size


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


func _exit_tree() -> void:
	if world and is_instance_valid(_pivot):
		_pivot.queue_free()


func _draw() -> void:
	if world:
		return
	# Sombra en el fondo para que se sienta la profundidad
	draw_set_transform(Vector2(14, 40) * _size, _vel.angle(), Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 120.0 * _size, Color(0, 0.08, 0.15, 0.18))
	draw_set_transform(Vector2.ZERO)


# --- Render 3D --------------------------------------------------------------

func _make_material() -> void:
	_material = SharkMesh.make_material()
	_material.set_shader_parameter("phase", randf() * TAU)
	match kind:
		Kind.BIG:
			_material.set_shader_parameter("tint", Vector3(0.72, 0.78, 0.82))
		Kind.FAST:
			_material.set_shader_parameter("tint", Vector3(0.8, 1.0, 1.25))


## En el juego: el modelo va directo en el mar 3D (sin SubViewport).
func _build_3d() -> void:
	_pivot = Node3D.new()
	world.add_child(_pivot)
	_make_material()
	var mi := MeshInstance3D.new()
	mi.mesh = SharkMesh.model()
	mi.material_override = _material
	mi.scale = Vector3.ONE * _size
	_pivot.add_child(mi)
	world.add_shark_shadow(self, _size)
	# Burbuja que lo atrapa (oculta hasta que lo atrapan)
	_bubble = MeshInstance3D.new()
	_bubble.mesh = SeaMeshes.sphere(1.0, 24)
	_bubble.material_override = world.bubble_material(Color(0.7, 0.95, 1.0, 1.0), 0.12, 0.9)
	_bubble.scale = Vector3.ONE
	_bubble.visible = false
	var holder := Node3D.new()
	_pivot.add_child(holder)
	holder.add_child(_bubble)
	_bubble.scale = Vector3.ONE * 1.6 * _size

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

	_make_material()

	var mi := MeshInstance3D.new()
	mi.mesh = SharkMesh.model()
	mi.material_override = _material
	_pivot.add_child(mi)

	_sprite = Sprite2D.new()
	_sprite.texture = vp.get_texture()
	_sprite.scale = Vector2.ONE * (SCREEN_SIZE * _size / VIEW_PX)
	add_child(_sprite)

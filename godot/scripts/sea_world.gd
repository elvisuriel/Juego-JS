class_name SeaWorld
extends Node3D
## El mar de Atlantis en 3D, visto en diagonal como Dofus.
##
## La lógica del juego sigue en 2D (posiciones en píxeles, colisiones,
## IA de tiburones); este nodo dibuja todo en 3D. 1 unidad 3D = 100 px:
## un punto (x, y) del juego está en (x/100, altura, y/100).
##
## El mundo es abierto y siempre el mismo (semilla fija): un mar grande
## dividido en regiones con su propio estilo. La semilla fija también
## sirve para el multijugador futuro: todos verán el mismo mar.

signal region_changed(index: int)

const S := 0.01                   # px → unidades 3D
const SWIM_Y := 2.0               # altura a la que nadan caballito y enemigos
const CHUNK := 8.0                # tamaño de cada pedazo del mundo
const OUTSIDE := 12.0             # suelo que se ve más allá del borde
const GRID := 1.0                 # resolución del suelo
const CAM_DIST := 30.0
const CAM_SIZE := 8.0             # alto visible (unidades)
const CAM_PITCH := -42.0
const CAM_YAW := 45.0
const WORLD_SEED := 20261125
const HORSE_SIZE := 1.5           # tamaño del caballito 3D en el juego

const WorldShader := preload("res://shaders/world.gdshader")
const BillboardShader := preload("res://shaders/billboard.gdshader")
const GemShader := preload("res://shaders/gem.gdshader")
const GlowShader := preload("res://shaders/glow.gdshader")
const BubbleShader := preload("res://shaders/bubble.gdshader")
const ShadowShader := preload("res://shaders/shadow.gdshader")

## Regiones del mar. center en unidades (el mundo mide 64 x 64).
const REGIONS := [
	{"name": "LLANURA DE ARENA", "center": Vector2(32, 33), "sand": Color("#f0d49a"), "sand2": Color("#e0b874"), "water": Color("#2b86c5"), "amp": 0.55},
	{"name": "BOSQUE DE ALGAS", "center": Vector2(11, 13), "sand": Color("#b9bd80"), "sand2": Color("#8e9b5c"), "water": Color("#1f8086"), "amp": 0.4},
	{"name": "RUINAS DE ATLANTIS", "center": Vector2(33, 9), "sand": Color("#dcd5c2"), "sand2": Color("#bfb8a5"), "water": Color("#2a62b0"), "amp": 0.22},
	{"name": "ARRECIFE DE CORAL", "center": Vector2(54, 13), "sand": Color("#f8e8c0"), "sand2": Color("#f1c8a8"), "water": Color("#22a8c8"), "amp": 0.35},
	{"name": "BARCO HUNDIDO", "center": Vector2(52, 52), "sand": Color("#a99a7c"), "sand2": Color("#857860"), "water": Color("#1c5f8c"), "amp": 0.45},
	{"name": "CUEVAS DE ROCA", "center": Vector2(12, 52), "sand": Color("#7f8a96"), "sand2": Color("#5f6b78"), "water": Color("#24527c"), "amp": 0.95},
]
const GEM_COLORS := [Color("#ff5a7a"), Color("#57cfff"), Color("#6dff9a"), Color("#ffd34d")]
const CORAL_COLORS := [Color("#ff7a6b"), Color("#ff9f45"), Color("#c46bff"), Color("#ff5fa8"), Color("#ffd65a")]

var size := Vector2(64, 64)       # unidades
var camera: Camera3D
var region := -1
var horse: Node2D

var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _noise3 := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _env: Environment
var _world_mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _water_mats: Array[ShaderMaterial] = []
var _buckets := {}                # "mesh_chunk" -> {mesh, xforms}
var _proxies: Array[Dictionary] = []
var _horse_view: Node3D
var _horse_model: Node3D
var _horse_mat: ShaderMaterial
var _horse_last := Vector2.ZERO
var _horse_yaw := 0.0
var _horse_lean := 0.0
var _spin := 0.0                  # vuelta de alegría al atrapar algo
var _last_frame := 0
var _shield: MeshInstance3D
var _trail: CPUParticles3D
var _bubbles: CPUParticles3D
var _target := Vector3.ZERO
var _water := Color("#2b86c5")
var _schools: Array[Dictionary] = []
var _turtles: Array[Dictionary] = []
var _icons := {}
var _t := 0.0
var _region_tex: ImageTexture


func build(world_px: Vector2) -> void:
	size = world_px * S
	_rng.seed = WORLD_SEED
	_noise.seed = WORLD_SEED
	_noise.frequency = 0.07
	_noise2.seed = WORLD_SEED + 1
	_noise2.frequency = 0.25
	_noise3.seed = WORLD_SEED + 2
	_noise3.frequency = 0.12

	_world_mat = _water_mat(WorldShader)
	_ground_mat = _water_mat(WorldShader)
	_ground_mat.set_shader_parameter("caustic", 1.0)

	_build_camera()
	_build_ground()
	_build_decor()
	_flush_buckets()
	_build_rays()
	_build_bubbles()
	_build_fish()
	_build_turtles()
	_build_region_texture()


# --- Utilidades públicas ------------------------------------------------------

static func to3(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x * S, h, p.y * S)


func region_weights(p: Vector2) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(REGIONS.size())
	var dmin := INF
	for i in REGIONS.size():
		w[i] = p.distance_to(REGIONS[i].center)
		dmin = minf(dmin, w[i])
	var total := 0.0
	for i in w.size():
		w[i] = exp(-(w[i] - dmin) * 0.45)
		total += w[i]
	for i in w.size():
		w[i] /= total
	return w


func region_at(p: Vector2) -> int:
	var best := 0
	var dmin := INF
	for i in REGIONS.size():
		var d: float = p.distance_to(REGIONS[i].center)
		if d < dmin:
			dmin = d
			best = i
	return best


## Altura del suelo en (x, z) en unidades.
func ground_h(x: float, z: float) -> float:
	var w := region_weights(Vector2(x, z))
	var amp := 0.0
	for i in w.size():
		amp += w[i] * REGIONS[i].amp
	var h := _noise.get_noise_2d(x, z) * amp * 1.7 + _noise2.get_noise_2d(x, z) * 0.12
	var edge := minf(minf(x, z), minf(size.x - x, size.y - z))
	if edge < 3.0:
		h += minf((3.0 - edge) * 0.65, 7.0)
	return h


## Dónde apunta el mouse / dedo, en píxeles del juego.
func pointer_world() -> Vector2:
	var mp := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(mp)
	var d := camera.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return horse.global_position if horse else Vector2.ZERO
	var t := (SWIM_Y - o.y) / d.y
	var p := o + d * t
	return Vector2(p.x, p.z) / S


## Dirección en pantalla (joystick) → dirección en el mapa del juego.
func screen_dir_to_world(v: Vector2) -> Vector2:
	var right := _flat(camera.global_basis.x)
	var fwd := _flat(-camera.global_basis.z)
	var w := right * v.x + fwd * (-v.y)
	return Vector2(w.x, w.z)


## Cuánto se mueve hacia la derecha de la pantalla una dirección del mapa.
func screen_x(d: Vector2) -> float:
	return Vector3(d.x, 0, d.y).dot(_flat(camera.global_basis.x))


## Ejes del mapa vistos en pantalla (para el minimapa en rombo).
func minimap_basis() -> Transform2D:
	var right := _flat(camera.global_basis.x)
	var fwd := _flat(-camera.global_basis.z)
	return Transform2D(Vector2(right.x, -fwd.x), Vector2(right.z, -fwd.z), Vector2.ZERO)


func region_texture() -> ImageTexture:
	return _region_tex


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()


func _water_mat(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("cam_dist", CAM_DIST)
	_water_mats.append(m)
	return m


# --- Cámara -----------------------------------------------------------------

func _build_camera() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = _water
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAM_SIZE
	camera.near = 1.0
	camera.far = 90.0
	camera.environment = _env
	camera.rotation = Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0)
	add_child(camera)
	camera.current = true


func _process(delta: float) -> void:
	_t += delta
	if horse:
		var hp := to3(horse.global_position, SWIM_Y)
		var k := 1.0 - exp(-6.0 * delta)
		_target = hp if _target == Vector3.ZERO else _target.lerp(hp, k)
		var r := region_at(horse.global_position * S)
		if r != region:
			region = r
			region_changed.emit(r)
	camera.global_position = _target + camera.global_basis.z * CAM_DIST

	# Color del agua según la región en la que estás
	var w := region_weights(Vector2(_target.x, _target.z))
	var water := Color(0, 0, 0)
	for i in w.size():
		water += REGIONS[i].water * w[i]
	_water = _water.lerp(water, 1.0 - exp(-2.0 * delta))
	for m in _water_mats:
		m.set_shader_parameter("water", _water)
	_env.background_color = _water.darkened(0.15)

	_bubbles.global_position = Vector3(_target.x, 0.0, _target.z)
	_sync_proxies()
	_sync_horse(delta)
	_swim_fish(delta)
	_swim_turtles(delta)


## Para el menú: la cámara mira un punto (unidades) sin seguir a nadie.
func look_at_point(p: Vector2) -> void:
	_target = Vector3(p.x, SWIM_Y, p.y)


## Punto de la pantalla → posición 3D a la altura de nado.
func screen_to_swim(sp: Vector2) -> Vector3:
	var o := camera.project_ray_origin(sp)
	var d := camera.project_ray_normal(sp)
	return o + d * ((SWIM_Y - o.y) / d.y)


func shake() -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(camera, "h_offset", randf_range(-0.14, 0.14), 0.04)
		tw.parallel().tween_property(camera, "v_offset", randf_range(-0.14, 0.14), 0.04)
	tw.tween_property(camera, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


# --- Suelo ------------------------------------------------------------------

func _ground_color(x: float, z: float, h: float) -> Color:
	var w := region_weights(Vector2(x, z))
	var mix_k := clampf(_noise3.get_noise_2d(x, z) * 0.9 + 0.5, 0.0, 1.0)
	var c := Color(0, 0, 0)
	for i in w.size():
		c += (REGIONS[i].sand as Color).lerp(REGIONS[i].sand2, mix_k) * w[i]
	c = c.darkened(clampf(-h * 0.18, 0.0, 0.22))
	var edge := minf(minf(x, z), minf(size.x - x, size.y - z))
	if edge < 2.0:
		c = c.lerp(Color("#56636f"), clampf((2.0 - edge) / 5.0, 0.0, 0.85))
	return c


func _build_ground() -> void:
	var x0 := -OUTSIDE
	var z0 := -OUTSIDE
	var nx := int((size.x + OUTSIDE * 2.0) / GRID)
	var nz := int((size.y + OUTSIDE * 2.0) / GRID)
	var hs := PackedFloat32Array()
	var cs := PackedColorArray()
	hs.resize((nx + 1) * (nz + 1))
	cs.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * GRID
			var z := z0 + j * GRID
			var h := ground_h(x, z)
			hs[j * (nx + 1) + i] = h
			cs[j * (nx + 1) + i] = _ground_color(x, z, h)

	var per := int(CHUNK / GRID)
	for cj in range(0, nz, per):
		for ci in range(0, nx, per):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(cj, mini(cj + per, nz)):
				for i in range(ci, mini(ci + per, nx)):
					var idx := [j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i]
					var p: Array[Vector3] = []
					for k in 4:
						var ii: int = idx[k]
						var gi := ii % (nx + 1)
						var gj := ii / (nx + 1)
						p.append(Vector3(x0 + gi * GRID, hs[ii], z0 + gj * GRID))
					var c1 := (cs[idx[0]] + cs[idx[1]] + cs[idx[2]]) / 3.0
					var c2 := (cs[idx[0]] + cs[idx[2]] + cs[idx[3]]) / 3.0
					SeaMeshes.tri(st, p[0], p[1], p[2], c1)
					SeaMeshes.tri(st, p[0], p[2], p[3], c2.darkened(0.03))
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = _ground_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


# --- Decoración -------------------------------------------------------------

## Coloca un objeto (se agrupan por pedazo del mundo para dibujar rápido).
func _place(mesh: Mesh, pos: Vector2, scale: float, yaw := 0.0, sink := 0.0, stretch := Vector3.ONE, tilt := Vector2.ZERO) -> void:
	var h := ground_h(pos.x, pos.y)
	var b := Basis.from_euler(Vector3(tilt.x, yaw, tilt.y)).scaled(stretch * scale)
	var xf := Transform3D(b, Vector3(pos.x, h - sink * scale, pos.y))
	var cx := int(floor((pos.x + OUTSIDE) / CHUNK))
	var cz := int(floor((pos.y + OUTSIDE) / CHUNK))
	var key := "%d_%d_%d" % [mesh.get_instance_id(), cx, cz]
	if not _buckets.has(key):
		_buckets[key] = {"mesh": mesh, "xforms": []}
	_buckets[key].xforms.append(xf)


func _flush_buckets() -> void:
	for key in _buckets:
		var b: Dictionary = _buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = b.xforms.size()
		for i in b.xforms.size():
			mm.set_instance_transform(i, b.xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _world_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_buckets.clear()


## Punto al azar dentro de una región (lejos de los bordes).
func _point_in(region_i: int, spread := 26.0) -> Vector2:
	var c: Vector2 = REGIONS[region_i].center
	for t in 40:
		var p := c + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		if p.x < 1.5 or p.y < 1.5 or p.x > size.x - 1.5 or p.y > size.y - 1.5:
			continue
		if region_at(p) == region_i:
			return p
	return c


func _scatter(region_i: int, meshes: Array, count: int, smin: float, smax: float, sink := 0.0, stretch_y := Vector2.ONE, tilt := 0.0) -> void:
	for i in count:
		var p := _point_in(region_i)
		var m: Mesh = meshes[_rng.randi() % meshes.size()]
		var st := Vector3(1, _rng.randf_range(stretch_y.x, stretch_y.y), 1)
		var tl := Vector2(_rng.randf_range(-tilt, tilt), _rng.randf_range(-tilt, tilt))
		_place(m, p, _rng.randf_range(smin, smax), _rng.randf() * TAU, sink, st, tl)


func _build_decor() -> void:
	var rocks := [SeaMeshes.rock(0), SeaMeshes.rock(1), SeaMeshes.rock(2)]
	var dark_rocks := [SeaMeshes.rock(3, Color("#56626f")), SeaMeshes.rock(4, Color("#4b5764")), SeaMeshes.rock(5, Color("#66717d"))]
	var corals: Array = []
	for i in CORAL_COLORS.size():
		corals.append(SeaMeshes.coral_branch(i, CORAL_COLORS[i]))
	var brains := [SeaMeshes.brain_coral(Color("#e79b5a")), SeaMeshes.brain_coral(Color("#c9d36a")), SeaMeshes.brain_coral(Color("#e874a0"))]
	var fans := [SeaMeshes.fan_coral(Color("#d14bd1")), SeaMeshes.fan_coral(Color("#ff6a5a")), SeaMeshes.fan_coral(Color("#ffb347"))]
	var anemones := [SeaMeshes.anemone(Color("#ff7ab8")), SeaMeshes.anemone(Color("#7ae0ff"))]
	var kelps := [SeaMeshes.kelp(0), SeaMeshes.kelp(1), SeaMeshes.kelp(2), SeaMeshes.kelp(3)]
	var grass := [SeaMeshes.grass(), SeaMeshes.grass(Color("#7aa84a"))]
	var stars := [SeaMeshes.starfish(Color("#ff8a3d")), SeaMeshes.starfish(Color("#e8466b")), SeaMeshes.starfish(Color("#f5c242"))]

	# 0 Llanura de arena: abierta, con estrellas, conchas y algo de pasto
	_scatter(0, grass, 140, 0.8, 1.3)
	_scatter(0, stars, 45, 0.8, 1.2, 0.01)
	_scatter(0, [SeaMeshes.shell()], 35, 0.9, 1.3)
	_scatter(0, rocks, 35, 0.3, 0.8, 0.25)
	_scatter(0, brains, 10, 0.8, 1.2, 0.1)
	_scatter(0, anemones, 12, 0.9, 1.3)

	# 1 Bosque de algas
	_scatter(1, kelps, 260, 1.0, 1.3, 0.0, Vector2(1.3, 2.0))
	_scatter(1, kelps, 110, 1.2, 1.6, 0.0, Vector2(2.2, 3.0))
	_scatter(1, grass, 220, 0.9, 1.5)
	_scatter(1, rocks, 35, 0.4, 1.0, 0.25)
	_scatter(1, stars, 12, 0.8, 1.0, 0.01)

	# 2 Ruinas de Atlantis: templo en el centro y restos alrededor
	_build_temple(REGIONS[2].center)
	_scatter(2, [SeaMeshes.column(true, 0), SeaMeshes.column(true, 1), SeaMeshes.column(true, 2)], 45, 0.8, 1.1, 0.05, Vector2.ONE, 0.12)
	_scatter(2, [SeaMeshes.column(false, 0)], 10, 0.9, 1.0, 0.05)
	_scatter(2, [SeaMeshes.tile(0), SeaMeshes.tile(1), SeaMeshes.tile(2)], 45, 0.6, 1.0, 0.04, Vector2.ONE, 0.08)
	_scatter(2, rocks, 25, 0.3, 0.7, 0.25)
	_scatter(2, grass, 80, 0.8, 1.2)
	_scatter(2, kelps, 40, 0.8, 1.0, 0.0, Vector2(0.8, 1.2))

	# 3 Arrecife de coral
	_scatter(3, corals, 120, 0.8, 1.35, 0.0)
	_scatter(3, brains, 40, 0.7, 1.3, 0.1)
	_scatter(3, fans, 50, 0.8, 1.3)
	_scatter(3, anemones, 50, 0.9, 1.4)
	_scatter(3, stars, 25, 0.8, 1.1, 0.01)
	_scatter(3, rocks, 25, 0.4, 0.9, 0.25)

	# 4 Barco hundido
	var c4: Vector2 = REGIONS[4].center
	_place(SeaMeshes.ship(), c4, 1.0, 0.7, 0.35, Vector3.ONE, Vector2(0.0, 0.22))
	_place(SeaMeshes.ship(), c4 + Vector2(-9, 6), 0.65, -1.9, 0.4, Vector3.ONE, Vector2(0.15, -0.3))
	for i in 5:
		_place(SeaMeshes.chest(), c4 + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6)), 1.0, _rng.randf() * TAU, 0.05, Vector3.ONE, Vector2(0, _rng.randf_range(-0.2, 0.2)))
	_scatter(4, [SeaMeshes.barrel()], 30, 0.9, 1.2, 0.05, Vector2.ONE, 0.5)
	_scatter(4, dark_rocks, 60, 0.4, 1.2, 0.25)
	_scatter(4, grass, 90, 0.8, 1.2)
	_scatter(4, kelps, 30, 0.8, 1.0, 0.0, Vector2(0.8, 1.3))
	_scatter(4, [SeaMeshes.shell()], 15, 0.9, 1.2)

	# 5 Cuevas de roca: rocas grandes y oscuras
	_scatter(5, dark_rocks, 85, 0.6, 1.6, 0.3, Vector2(0.8, 1.4))
	_scatter(5, rocks, 60, 0.3, 0.8, 0.25)
	_scatter(5, grass, 60, 0.8, 1.2)
	_scatter(5, anemones, 25, 0.8, 1.2)
	_scatter(5, [SeaMeshes.brain_coral(Color("#8f7fbf"))], 15, 0.7, 1.1, 0.1)

	# Paredes de roca alrededor del mundo
	var step := 2.2
	var x := -1.0
	while x < size.x + 1.0:
		for side in 4:
			var p: Vector2
			match side:
				0: p = Vector2(x, -1.2)
				1: p = Vector2(x, size.y + 1.2)
				2: p = Vector2(-1.2, x)
				_: p = Vector2(size.x + 1.2, x)
			p += Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6))
			_place(dark_rocks[_rng.randi() % 3], p, _rng.randf_range(1.6, 2.6), _rng.randf() * TAU, 0.2, Vector3(1, _rng.randf_range(1.0, 1.6), 1))
		x += step


func _build_temple(c: Vector2) -> void:
	for i in range(-3, 4):
		for j in range(-2, 3):
			_place(SeaMeshes.tile(absi(i + j) % 3), c + Vector2(i * 1.95, j * 1.95), 1.0, 0.0, 0.03)
	var n := 12
	for i in n:
		var a := TAU * i / n
		var p := c + Vector2(cos(a) * 6.5, sin(a) * 4.5)
		var broken := i % 3 == 1
		_place(SeaMeshes.column(broken, i), p, 1.0, a, 0.04)
	_place(SeaMeshes.statue_head(), c, 1.3, deg_to_rad(CAM_YAW), 0.1)


# --- Ambiente: rayos de sol, burbujas, peces ----------------------------------------

func _build_rays() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GlowShader
	mat.set_shader_parameter("mode", 1)
	mat.set_shader_parameter("billboard", false)
	mat.set_shader_parameter("color", Color(0.75, 0.95, 1.0, 0.13))
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 14.0)
	var y := -4.0
	while y < size.y + 4.0:
		var x := -4.0 + fmod(y * 0.37, 3.0)
		while x < size.x + 4.0:
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = mat
			mi.position = Vector3(x + _rng.randf_range(-2, 2), 6.0, y + _rng.randf_range(-2, 2))
			mi.rotation = Vector3(0, deg_to_rad(CAM_YAW), 0.35)
			mi.scale = Vector3(_rng.randf_range(0.6, 1.6), 1, 1)
			add_child(mi)
			x += _rng.randf_range(7.0, 11.0)
		y += _rng.randf_range(7.0, 11.0)


func bubble_material(c: Color, base := 0.08, rim := 0.75) -> ShaderMaterial:
	return _bubble_mat(c, base, rim)


func _bubble_mat(c := Color(0.85, 0.97, 1.0, 1.0), base := 0.08, rim := 0.75) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BubbleShader
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("base_alpha", base)
	m.set_shader_parameter("rim_alpha", rim)
	return m


func _build_bubbles() -> void:
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 70
	_bubbles.lifetime = 6.0
	_bubbles.preprocess = 6.0
	_bubbles.local_coords = false
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(13, 0.5, 13)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 12.0
	_bubbles.gravity = Vector3(0, 0.35, 0)
	_bubbles.initial_velocity_min = 0.4
	_bubbles.initial_velocity_max = 1.1
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 2.2
	var m := SeaMeshes.sphere(0.06, 8).duplicate() as SphereMesh
	m.material = _bubble_mat()
	_bubbles.mesh = m
	add_child(_bubbles)


func _build_fish() -> void:
	var colors := [Color("#ffd43b"), Color("#4dabf7"), Color("#ff922b"), Color("#f06595"), Color("#a9e34b")]
	for i in 16:
		var mesh := SeaMeshes.fish(colors[i % colors.size()])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 9
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _world_mat
		add_child(mmi)
		var c := Vector2(_rng.randf_range(4, size.x - 4), _rng.randf_range(4, size.y - 4))
		_schools.append({"mmi": mmi, "pos": c, "target": c, "phase": _rng.randf() * TAU, "y": _rng.randf_range(0.9, 3.2)})
		_place_school(_schools[-1], 0.0)


func _place_school(s: Dictionary, t: float) -> void:
	var mm: MultiMesh = s.mmi.multimesh
	var c: Vector2 = s.pos
	for k in mm.instance_count:
		var a: float = t * 0.9 + s.phase + k * 0.7
		var r := 0.6 + (k % 3) * 0.35
		var p := Vector3(c.x + cos(a) * r, s.y + sin(a * 1.7 + k) * 0.25, c.y + sin(a) * r)
		var tangent := Vector3(-sin(a), 0, cos(a))
		# El pez mira a +X: se gira para que mire hacia donde nada
		var b := Basis.looking_at(tangent, Vector3.UP) * Basis(Vector3.UP, PI * 0.5)
		mm.set_instance_transform(k, Transform3D(b.scaled(Vector3.ONE * 1.3), p))


func _swim_fish(delta: float) -> void:
	for s in _schools:
		var c: Vector2 = s.pos
		if c.distance_to(s.target) < 1.0:
			s.target = Vector2(clampf(c.x + randf_range(-12, 12), 3, size.x - 3), clampf(c.y + randf_range(-12, 12), 3, size.y - 3))
		s.pos = c.move_toward(s.target, delta * 1.2)
		# Solo se animan los cardúmenes que están cerca de la cámara
		if Vector2(_target.x, _target.z).distance_to(c) < 26.0:
			_place_school(s, _t)


## Tortugas amigas (modelo de Tripo): una cerca del inicio y otras paseando.
## En la fase 2 serán quienes dan las misiones.
func _build_turtles() -> void:
	var mesh: Mesh = load("res://assets/models/turtle.res")
	var tex: Texture2D = load("res://assets/models/turtle.png")
	var spots: Array[Vector2] = [REGIONS[0].center + Vector2(3, -2)]
	for i in range(1, REGIONS.size()):
		spots.append(REGIONS[i].center)
	for i in spots.size():
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := ShaderMaterial.new()
		m.shader = SharkMesh.CreatureShader
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("flap", 0.22)
		m.set_shader_parameter("flap_from", 0.35)
		m.set_shader_parameter("swim_speed", 1.8)
		m.set_shader_parameter("phase", _rng.randf() * TAU)
		mi.material_override = m
		_water_mats.append(m)
		add_child(mi)
		var home: Vector2 = spots[i]
		var t := {"node": mi, "home": home, "pos": home, "target": home, "yaw": 0.0, "y": _rng.randf_range(1.2, 2.6), "shadow": _shadow(0.7, 0.25)}
		_turtles.append(t)


func _swim_turtles(delta: float) -> void:
	for t in _turtles:
		var p: Vector2 = t.pos
		if p.distance_to(t.target) < 0.5:
			# Pasea despacio cerca de su casa
			var home: Vector2 = t.home
			t.target = Vector2(clampf(home.x + randf_range(-7, 7), 3, size.x - 3), clampf(home.y + randf_range(-7, 7), 3, size.y - 3))
		var dir: Vector2 = (t.target - p).normalized()
		t.pos = p + dir * delta * 0.9
		t.yaw = lerp_angle(t.yaw, atan2(-dir.y, dir.x), 1.0 - exp(-1.5 * delta))
		var n: MeshInstance3D = t.node
		var y: float = t.y + sin(_t * 0.9 + t.home.x) * 0.15
		n.global_position = Vector3(t.pos.x, y, t.pos.y)
		n.rotation = Vector3(0, t.yaw, sin(_t * 0.9 + t.home.x) * 0.06)
		var sh: MeshInstance3D = t.shadow
		sh.global_position = Vector3(t.pos.x, ground_h(t.pos.x, t.pos.y) + 0.06, t.pos.y)


# --- Lo que nada: caballito, diamantes, power-ups, pulpos, escondites ---------------------

func _shadow(radius: float, strength := 0.35) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * radius * 2.0
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = ShadowShader
	m.set_shader_parameter("strength", strength)
	mi.material_override = m
	add_child(mi)
	return mi


func _track(node: Node2D, view: Node3D, kind: String, height: float, shadow_r := 0.0, extra := {}) -> void:
	var pr := {"node": node, "view": view, "kind": kind, "h": height, "phase": randf() * TAU}
	if shadow_r > 0.0:
		pr["shadow"] = _shadow(shadow_r)
	pr.merge(extra)
	_proxies.append(pr)
	_sync_one(pr)


func _sync_proxies() -> void:
	for i in range(_proxies.size() - 1, -1, -1):
		var pr := _proxies[i]
		# Ojo: no asignar a una variable tipada antes de revisar, puede estar liberado
		if not is_instance_valid(pr.node) or pr.node.is_queued_for_deletion():
			pr.view.queue_free()
			if pr.has("shadow"):
				pr.shadow.queue_free()
			_proxies.remove_at(i)
			continue
		_sync_one(pr)


func _sync_one(pr: Dictionary) -> void:
	var n: Node2D = pr.node
	var v: Node3D = pr.view
	var p := to3(n.global_position, pr.h)
	var ph: float = pr.phase
	match pr.kind:
		"gem":
			p.y += sin(_t * 2.0 + ph) * 0.12
			v.rotation.y = _t * 1.4 + ph
			v.scale = Vector3.ONE * n.scale.x * 1.1
		"powerup":
			p.y += sin(_t * 2.0 + ph) * 0.1
		"octopus":
			var sq: float = n.get("_squish")
			var pulse := sin(_t * 2.5 + ph)
			v.scale = Vector3(1.0 + pulse * 0.06 - sq * 0.2, 1.0 - pulse * 0.08 + sq * 0.35, 1.0 + pulse * 0.06 - sq * 0.2) * 0.95
			v.rotation.y = deg_to_rad(CAM_YAW)
			p.y += maxf(pulse, 0.0) * 0.25
		"shark":
			pass
	if pr.kind != "shark":
		v.global_position = p
	if pr.has("shadow"):
		var s: MeshInstance3D = pr.shadow
		var gp := n.global_position * S
		s.global_position = Vector3(gp.x, ground_h(gp.x, gp.y) + 0.06, gp.y)


func add_diamond(node: Node2D, frame: int) -> void:
	var root := Node3D.new()
	add_child(root)
	var gem := MeshInstance3D.new()
	gem.mesh = SeaMeshes.gem()
	var m := ShaderMaterial.new()
	m.shader = GemShader
	m.set_shader_parameter("color", GEM_COLORS[frame % GEM_COLORS.size()])
	gem.material_override = m
	root.add_child(gem)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.9
	glow.mesh = q
	var gm := ShaderMaterial.new()
	gm.shader = GlowShader
	var gc: Color = GEM_COLORS[frame % GEM_COLORS.size()]
	gm.set_shader_parameter("color", Color(gc.lightened(0.3), 0.55))
	glow.material_override = gm
	root.add_child(glow)
	_track(node, root, "gem", SWIM_Y - 0.3, 0.45)


func _icon(kind: int) -> Texture2D:
	if _icons.has(kind):
		return _icons[kind]
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Node2D.new()
	n.draw.connect(func() -> void: PowerUp.draw_icon(n, kind, Vector2(48, 48), 1.9, PowerUp.COLORS[kind]))
	vp.add_child(n)
	add_child(vp)
	_icons[kind] = vp.get_texture()
	return _icons[kind]


func add_powerup(node: PowerUp) -> void:
	var root := Node3D.new()
	add_child(root)
	var c: Color = PowerUp.COLORS[node.kind]
	var b := MeshInstance3D.new()
	b.mesh = SeaMeshes.sphere(0.45, 20)
	b.material_override = _bubble_mat(c.lightened(0.5), 0.1, 0.8)
	root.add_child(b)
	var icon := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.62
	icon.mesh = q
	var m := ShaderMaterial.new()
	m.shader = BillboardShader
	m.set_shader_parameter("tex", _icon(node.kind))
	m.set_shader_parameter("frames", 1)
	icon.material_override = m
	_water_mats.append(m)
	root.add_child(icon)
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2.ONE * 1.6
	glow.mesh = gq
	var gm := ShaderMaterial.new()
	gm.shader = GlowShader
	gm.set_shader_parameter("color", Color(c, 0.4))
	glow.material_override = gm
	root.add_child(glow)
	_track(node, root, "powerup", SWIM_Y - 0.2, 0.4)


func add_octopus(node: Node2D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SeaMeshes.octopus()
	mi.material_override = _world_mat
	add_child(mi)
	_track(node, mi, "octopus", SWIM_Y - 0.9, 0.8)


## Bosque de algas alto: el caballito se esconde adentro.
func add_hideout(node: Node2D) -> void:
	var root := Node3D.new()
	add_child(root)
	var c := node.global_position * S
	var r: float = Hideout.RADIUS * S
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = SeaMeshes.kelp(randi() % 4)
	mm.instance_count = 26
	for i in mm.instance_count:
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		var p := Vector2(c.x + cos(a) * d, c.y + sin(a) * d)
		var h := ground_h(p.x, p.y)
		var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(1.6, randf_range(3.0, 4.2), 1.6))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, h, p.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _world_mat
	root.add_child(mmi)
	var g := MultiMesh.new()
	g.transform_format = MultiMesh.TRANSFORM_3D
	g.mesh = SeaMeshes.grass(Color("#3c8f5e"))
	g.instance_count = 14
	for i in g.instance_count:
		var a := randf() * TAU
		var d := sqrt(randf()) * r * 1.1
		var p := Vector2(c.x + cos(a) * d, c.y + sin(a) * d)
		g.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * 1.4), Vector3(p.x, ground_h(p.x, p.y), p.y)))
	var gi := MultiMeshInstance3D.new()
	gi.multimesh = g
	gi.material_override = _world_mat
	root.add_child(gi)
	var sh := _shadow(r * 1.2, 0.3)
	sh.reparent(root)
	sh.global_position = Vector3(c.x, ground_h(c.x, c.y) + 0.05, c.y)


func add_shark_shadow(node: Node2D, scale: float) -> void:
	var dummy := Node3D.new()
	add_child(dummy)
	_track(node, dummy, "shark", SWIM_Y, 1.3 * scale)


# --- Caballito ------------------------------------------------------------------

func set_horse(h: Node2D) -> void:
	horse = h
	_horse_view = Node3D.new()
	add_child(_horse_view)

	_horse_model = make_seahorse(Game.skin, HORSE_SIZE)
	_horse_mat = _horse_model.get_meta("mat")
	_horse_view.add_child(_horse_model)

	_shield = MeshInstance3D.new()
	_shield.mesh = SeaMeshes.sphere(1.25, 24)
	_shield.material_override = _bubble_mat(PowerUp.COLORS[PowerUp.Kind.SHIELD], 0.08, 0.9)
	_shield.visible = false
	_horse_view.add_child(_shield)

	_trail = CPUParticles3D.new()
	_trail.amount = 30
	_trail.lifetime = 1.2
	_trail.local_coords = false
	_trail.emitting = false
	_trail.position = Vector3(0, -0.55, 0)      # sale de la cola, no tapa la cara
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.2
	_trail.direction = Vector3.UP
	_trail.spread = 40.0
	_trail.gravity = Vector3(0, 0.8, 0)
	_trail.initial_velocity_min = 0.2
	_trail.initial_velocity_max = 0.6
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.6
	var bm := SeaMeshes.sphere(0.07, 8).duplicate() as SphereMesh
	bm.material = _bubble_mat(Color(1, 0.85, 0.5, 1.0), 0.15, 0.9)
	_trail.mesh = bm
	_horse_view.add_child(_trail)

	var dummy := Node3D.new()
	add_child(dummy)
	_track(h, dummy, "shark", SWIM_Y, 0.55)
	_target = to3(h.global_position, SWIM_Y)
	_horse_last = h.global_position
	_water_mats.append(_horse_mat)


## Caballito 3D listo para poner en escena (juego, menú y tienda).
static func make_seahorse(skin_id: String, size := 1.1) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = SeahorseMesh.mesh_for(skin_id)
	var mat := SeahorseMesh.material(skin_id)
	mi.material_override = mat
	mi.scale = Vector3.ONE * size
	mi.set_meta("mat", mat)
	return mi


func _sync_horse(delta: float) -> void:
	if horse == null:
		return
	var sprite: Sprite2D = horse.get_node("Sprite")
	var pos := horse.global_position
	_horse_view.global_position = to3(pos, SWIM_Y + sin(_t * 2.2) * 0.08)

	# Gira hacia donde nada y se inclina si va rápido
	var vel := (pos - _horse_last) / maxf(delta, 0.001)
	_horse_last = pos
	var speed := vel.length()
	if speed > 40.0:
		_horse_yaw = lerp_angle(_horse_yaw, atan2(-vel.y, vel.x), 1.0 - exp(-7.0 * delta))
	_horse_lean = lerpf(_horse_lean, clampf(speed / 540.0 * 0.32, 0.0, 0.35), 1.0 - exp(-5.0 * delta))

	# Al atrapar un diamante (el dibujo sonríe) da una vuelta
	if sprite.frame == 1 and _last_frame == 0:
		_spin = 1.0
	_last_frame = sprite.frame
	_spin = maxf(_spin - delta * 2.2, 0.0)
	var spin := TAU * ease(_spin, 0.4)
	_horse_model.rotation = Vector3(0.0, _horse_yaw + spin, -_horse_lean + sin(_t * 1.7) * 0.05)
	_horse_model.scale = Vector3.ONE * HORSE_SIZE * (1.0 + sin(_spin * PI) * 0.18)

	# Parpadeo al ser mordido y tono verde dentro de las algas
	var mod := sprite.modulate
	_horse_model.visible = mod.a > 0.5
	SeahorseMesh.set_param(_horse_mat, "modulate", Color(mod.r, mod.g, mod.b, 1.0))
	SeahorseMesh.set_param(_horse_mat, "flutter_speed", 14.0 + speed / 540.0 * 14.0)
	_shield.visible = horse.get("shield")
	_shield.scale = Vector3.ONE * (1.0 + sin(_t * 5.0) * 0.04)
	_trail.emitting = horse.get("turbo_left") > 0.0


## Burbuja disparada por el caballito (el juego la mueve).
func add_shot(color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var b := MeshInstance3D.new()
	b.mesh = SeaMeshes.sphere(0.24, 16)
	b.material_override = _bubble_mat(color.lightened(0.4), 0.2, 0.95)
	root.add_child(b)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.1
	glow.mesh = q
	var gm := ShaderMaterial.new()
	gm.shader = GlowShader
	gm.set_shader_parameter("color", Color(color, 0.7))
	glow.material_override = gm
	root.add_child(glow)
	return root


## Onda expansiva: anillo de luz que crece desde el caballito.
func wave_fx(at: Vector2, radius_px: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * 2.0
	ring.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = GlowShader
	m.set_shader_parameter("billboard", false)
	m.set_shader_parameter("color", Color(color, 1.0))
	ring.material_override = m
	add_child(ring)
	ring.global_position = to3(at, SWIM_Y - 0.4)
	ring.scale = Vector3.ONE * 0.3
	var r := radius_px * S
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3.ONE * r * 1.3, 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float) -> void: m.set_shader_parameter("color", Color(color, a)), 1.0, 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)
	burst(at, color)
	shake()


## Chispas al atrapar algo.
func burst(at: Vector2, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.7
	p.local_coords = false
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.35
	var m := ShaderMaterial.new()
	m.shader = GlowShader
	m.set_shader_parameter("color", Color(color.lightened(0.4), 1.0))
	q.material = m
	p.mesh = q
	add_child(p)
	p.global_position = to3(at, SWIM_Y - 0.2)
	p.emitting = true

	var ring := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2.ONE * 1.2
	ring.mesh = rq
	var rm := ShaderMaterial.new()
	rm.shader = GlowShader
	rm.set_shader_parameter("color", Color(color.lightened(0.5), 0.9))
	ring.material_override = rm
	add_child(ring)
	ring.global_position = p.global_position
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float) -> void: rm.set_shader_parameter("color", Color(color.lightened(0.5), a)), 0.9, 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# --- Minimapa ---------------------------------------------------------------------

func _build_region_texture() -> void:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var p := Vector2((i + 0.5) * size.x / n, (j + 0.5) * size.y / n)
			var w := region_weights(p)
			var c := Color(0, 0, 0)
			for k in w.size():
				c += (REGIONS[k].water as Color).lerp(REGIONS[k].sand, 0.35) * w[k]
			var edge := minf(minf(p.x, p.y), minf(size.x - p.x, size.y - p.y))
			if edge < 1.5:
				c = Color("#174e78")
			img.set_pixel(i, j, c)
	_region_tex = ImageTexture.create_from_image(img)

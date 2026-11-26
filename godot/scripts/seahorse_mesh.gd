class_name SeahorseMesh
extends RefCounted
## El caballito de mar en 3D, generado por código (sin archivos externos),
## con la forma del dibujo original: cabeza con hocico, cresta en la nuca,
## panza con rayas, aleta dorsal y cola enroscada hacia adelante.
## Mira hacia +X; mide ~1.55 de alto con el centro en el origen.
## UV.x = cuánto aletea (las aletas), UV.y = 1 en aletas (sin borde).

const PINK := Color("#ff74b0")
const DARK := Color("#e0468a")
const BELLY := Color("#ffb6d6")
const FIN := Color("#f2559a")
const LIFT := -0.62               # baja el modelo para centrarlo

const SeahorseShader := preload("res://shaders/seahorse.gdshader")
const OutlineShader := preload("res://shaders/seahorse_outline.gdshader")
const GhostShader := preload("res://shaders/seahorse_ghost.gdshader")

## Caballitos hechos con modelo y textura (no por código): skin -> [mesh, textura]
const MODELS := {
	"cristal": ["res://assets/models/seahorse_cristal.res", "res://assets/models/seahorse_cristal.png"],
}

static var _mesh: ArrayMesh


## Mesh del caballito según la skin (por código o modelo importado).
static func mesh_for(skin_id: String) -> Mesh:
	if MODELS.has(skin_id):
		return load(MODELS[skin_id][0])
	return build()


static func build() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body(st)
	_snout(st)
	_crown(st)
	_fins(st)
	_eyes(st)
	_mesh = st.commit()
	return _mesh


## Materiales con la skin: cuerpo → borde de caricatura → silueta detrás de cosas.
static func material(skin_id: String) -> ShaderMaterial:
	var d := Game.skin_data(skin_id)
	var main := ShaderMaterial.new()
	main.shader = SeahorseShader
	var outline := ShaderMaterial.new()
	outline.shader = OutlineShader
	var ghost := ShaderMaterial.new()
	ghost.shader = GhostShader
	for m in [main, outline, ghost]:
		m.set_shader_parameter("hue", d.hue)
		m.set_shader_parameter("sat", d.sat)
		m.set_shader_parameter("val", d.val)
		m.set_shader_parameter("rainbow", d.get("rainbow", false))
	main.next_pass = outline
	outline.next_pass = ghost
	if MODELS.has(skin_id):
		var tex: Texture2D = load(MODELS[skin_id][1])
		for m in [main, outline, ghost]:
			m.set_shader_parameter("use_tex", true)
			m.set_shader_parameter("albedo_tex", tex)
	return main


static func set_param(mat: ShaderMaterial, name: String, value: Variant) -> void:
	var m := mat
	while m:
		m.set_shader_parameter(name, value)
		m = m.next_pass as ShaderMaterial


# --- Curva del cuerpo ---------------------------------------------------------

## Puntos de control del perfil: x (adelante), y (arriba), radio.
const SPINE := [
	Vector3(-0.03, 1.33, 0.06),
	Vector3(0.0, 1.27, 0.13),
	Vector3(0.05, 1.17, 0.16),
	Vector3(0.0, 1.03, 0.115),
	Vector3(0.04, 0.88, 0.17),
	Vector3(0.08, 0.68, 0.205),
	Vector3(0.05, 0.48, 0.18),
	Vector3(-0.03, 0.3, 0.13),
	Vector3(-0.09, 0.14, 0.095),
]


static func _spine_points() -> Array:
	# Cola enroscada: espiral hacia adelante y adentro
	var pts: Array = SPINE.duplicate()
	var c := Vector2(0.06, 0.02)
	var steps := 9
	for i in steps:
		var t := float(i + 1) / steps
		var a := deg_to_rad(lerpf(175.0, 470.0, t))
		var rs := lerpf(0.15, 0.045, t)
		pts.append(Vector3(c.x + cos(a) * rs, c.y + sin(a) * rs, lerpf(0.075, 0.028, t)))
	return pts


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func _samples(per := 5) -> Array:
	var pts := _spine_points()
	var out := []
	for i in pts.size() - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		for k in per:
			out.append(_catmull(p0, p1, p2, p3, float(k) / per))
	out.append(pts[-1])
	return out


## Agrega un triángulo con el orden de vértices correcto para Godot (horario
## visto desde afuera), según su normal. Sin esto el borde de caricatura
## (que dibuja solo las caras de atrás) sale encima en algunas partes.
## Cada vértice: [posición, normal, color].
static func _add(st: SurfaceTool, a: Array, b: Array, c: Array, uv := Vector2.ZERO) -> void:
	var g: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	var avg: Vector3 = a[1] + b[1] + c[1]
	var verts := [a, b, c] if g.dot(avg) < 0.0 else [a, c, b]
	for v in verts:
		st.set_color(v[2])
		st.set_normal(v[1])
		st.set_uv(uv)
		st.add_vertex(v[0])


static func _v(x: float, y: float, z := 0.0) -> Vector3:
	return Vector3(x, y + LIFT, z)


static func _body(st: SurfaceTool) -> void:
	var s := _samples()
	var sides := 14
	var rings: Array = []
	for i in s.size():
		var c: Vector3 = s[i]
		var prev: Vector3 = s[maxi(i - 1, 0)]
		var nxt: Vector3 = s[mini(i + 1, s.size() - 1)]
		var tan2 := Vector2(nxt.x - prev.x, nxt.y - prev.y).normalized()
		var n2 := Vector2(tan2.y, -tan2.x)           # hacia adelante en el perfil
		if n2.x < 0.0 and c.y > 0.25:
			n2 = -n2
		var r := c.z
		# Anillos marcados, como el dibujo
		if c.y > 0.25 and c.y < 1.05:
			r *= 1.0 + 0.05 * cos(i * PI)
		var ring := []
		for j in sides + 1:
			var a := TAU * j / sides
			var off := Vector3(n2.x * cos(a), n2.y * cos(a), sin(a) * 0.82) * r
			# La panza sale más hacia adelante
			if cos(a) > 0.0 and c.y > 0.35 and c.y < 0.95:
				off += Vector3(n2.x, n2.y, 0) * cos(a) * r * 0.18
			var front := cos(a)
			var col := PINK
			if front > 0.45 and c.y > 0.32 and c.y < 0.98:
				col = BELLY if i % 2 == 0 else PINK.lerp(BELLY, 0.35)
			elif front < -0.55:
				col = DARK.lerp(PINK, 0.35)
			ring.append([_v(c.x + off.x, c.y + off.y, off.z), off.normalized(), col])
		rings.append(ring)
	for i in rings.size() - 1:
		for j in sides:
			var q := [rings[i][j], rings[i + 1][j], rings[i + 1][j + 1], rings[i][j + 1]]
			_add(st, q[0], q[1], q[2])
			_add(st, q[0], q[2], q[3])
	# Tapas: arriba de la cabeza y punta de la cola
	for cap in [[0, Vector3(-0.3, 1, 0)], [rings.size() - 1, Vector3(0, 1, 0)]]:
		var ring: Array = rings[cap[0]]
		var center := Vector3.ZERO
		for v in ring:
			center += v[0]
		center /= ring.size()
		for j in sides:
			_add(st, [center, cap[1], PINK], [ring[j][0], ring[j][1], PINK], [ring[j + 1][0], ring[j + 1][1], PINK])


static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col_a: Color, col_b: Color, sides := 10) -> void:
	var dir := (b - a).normalized()
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := dir.cross(ref).normalized()
	var w := dir.cross(u).normalized()
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := u * cos(a0) + w * sin(a0)
		var n1 := u * cos(a1) + w * sin(a1)
		var q := [[a + n0 * ra, n0, col_a], [b + n0 * rb, n0, col_b], [b + n1 * rb, n1, col_b], [a + n1 * ra, n1, col_a]]
		_add(st, q[0], q[1], q[2])
		_add(st, q[0], q[2], q[3])
	# Tapa en b
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		_add(st, [b, dir, col_b], [b + (u * cos(a0) + w * sin(a0)) * rb, dir, col_b], [b + (u * cos(a1) + w * sin(a1)) * rb, dir, col_b])


static func _sphere(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, steps := 8) -> void:
	for i in steps:
		for j in steps * 2:
			var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			var vs := []
			for k in 4:
				var th: float = PI * quad[k][0] / steps
				var ph: float = TAU * quad[k][1] / (steps * 2)
				var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				vs.append([c + n * r, n, col])
			_add(st, vs[0], vs[1], vs[2])
			_add(st, vs[0], vs[2], vs[3])


static func _snout(st: SurfaceTool) -> void:
	_tube(st, _v(0.12, 1.19), _v(0.4, 1.15), 0.075, 0.05, PINK, PINK)
	# Boquita redonda en la punta
	_sphere(st, _v(0.41, 1.15), Vector3(0.04, 0.058, 0.055), DARK.lerp(PINK, 0.3), 6)


static func _crown(st: SurfaceTool) -> void:
	# Coronita de puntas en la cabeza
	for i in 4:
		var a := -0.5 + i * 0.33
		var base := _v(-0.02 + sin(a) * 0.06, 1.3, cos(a) * 0.05 - 0.02)
		_tube(st, base, base + Vector3(-0.04, 0.12, 0), 0.03, 0.006, DARK, DARK, 5)


static func _fin_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, fa: float, fb: float, fc: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	for v in [[a, fa], [b, fb], [c, fc]]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(v[1], 1.0))
		st.add_vertex(v[0])


static func _fins(st: SurfaceTool) -> void:
	# Cresta con picos en la nuca y la espalda
	var crest := [[1.12, -0.12], [1.02, -0.1], [0.92, -0.13], [0.82, -0.16], [0.72, -0.2]]
	for i in crest.size() - 1:
		var y0: float = crest[i][0]
		var y1: float = crest[i + 1][0]
		var x0: float = crest[i][1]
		var x1: float = crest[i + 1][1]
		var tip := _v((x0 + x1) * 0.5 - 0.13, (y0 + y1) * 0.5 + 0.04)
		_fin_tri(st, _v(x0 + 0.06, y0), _v(x1 + 0.06, y1), tip, FIN, 0.0, 0.0, 0.3)

	# Aleta dorsal (la que mueve rápido para nadar)
	var base_top := _v(-0.12, 0.58)
	var base_bot := _v(-0.1, 0.36)
	var n := 7
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := base_top.lerp(base_bot, t0)
		var p1 := base_top.lerp(base_bot, t1)
		var o0 := p0 + Vector3(-0.2 - sin(t0 * PI) * 0.05, 0.03, 0)
		var o1 := p1 + Vector3(-0.2 - sin(t1 * PI) * 0.05, 0.03, 0)
		var col := FIN if i % 2 == 0 else FIN.lightened(0.2)
		_fin_tri(st, p0, p1, o1, col, 0.0, 0.0, 1.0)
		_fin_tri(st, p0, o1, o0, col, 0.0, 1.0, 1.0)

	# Aletas pectorales a cada lado, detrás de la cabeza
	for side: float in [-1.0, 1.0]:
		var root := _v(0.0, 1.02, 0.1 * side)
		_fin_tri(st, root, root + Vector3(-0.05, -0.12, 0.08 * side), root + Vector3(-0.15, -0.02, 0.06 * side), FIN.lightened(0.1), 0.0, 0.6, 0.6)


static func _eyes(st: SurfaceTool) -> void:
	for side: float in [-1.0, 1.0]:
		var c := _v(0.09, 1.22, 0.12 * side)
		_sphere(st, c, Vector3(0.075, 0.08, 0.045), Color.WHITE)
		_sphere(st, c + Vector3(0.022, 0.0, 0.03 * side), Vector3(0.045, 0.052, 0.025), Color(0.08, 0.02, 0.08), 6)
		_sphere(st, c + Vector3(0.04, 0.022, 0.05 * side), Vector3.ONE * 0.013, Color.WHITE, 4)
		# Pestañas, como en el dibujo
		for k in 3:
			var b := c + Vector3(-0.02 + k * 0.03, 0.072, 0.02 * side)
			_tube(st, b, b + Vector3(-0.02 + k * 0.01, 0.035, 0.012 * side), 0.006, 0.003, Color(0.2, 0.02, 0.12), Color(0.2, 0.02, 0.12), 4)

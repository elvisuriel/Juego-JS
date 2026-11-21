class_name SharkMesh
extends RefCounted
## Modelo 3D de tiburón generado por código (sin archivos externos):
## cuerpo fusiforme, aletas dorsal, pectorales, anal y cola asimétrica.
## El nado (la ola del cuerpo hacia la cola) lo hace el shader.
## El modelo mira hacia +X; mide unas 2.9 unidades de largo.

const BACK := Color(0.32, 0.4, 0.47)      # lomo gris azulado
const BELLY := Color(0.93, 0.94, 0.95)    # vientre blanco
const FIN := Color(0.28, 0.35, 0.42)
const EYE := Color(0.02, 0.02, 0.03)

const RINGS := 40
const SIDES := 24
const LENGTH := 2.0
const HEIGHT := 0.3
const WIDTH := 0.26

static var _mesh: ArrayMesh
static var _shader: Shader


static func build() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body(st)
	_fins(st)
	_eyes(st)
	_mesh = st.commit()
	return _mesh


## Forma del cuerpo: 0 en la nariz, máximo hacia el primer tercio,
## y se afina hasta el pedúnculo de la cola.
static func _profile(t: float) -> float:
	if t < 0.3:
		return pow(sin(t / 0.3 * PI * 0.5), 0.7)
	return lerpf(1.0, 0.12, smoothstep(0.3, 1.0, t))


static func _ring_point(t: float, a: float) -> Vector3:
	var p := _profile(t)
	var x := LENGTH * (0.5 - t)
	var y := cos(a) * HEIGHT * p
	if y < 0.0:
		y *= 0.8                          # vientre algo más plano
	var z := sin(a) * WIDTH * p
	# La nariz queda un poco por encima del centro, como en un tiburón real
	return Vector3(x, y + 0.04 * (1.0 - smoothstep(0.0, 0.25, t)) * p, z)


static func _body(st: SurfaceTool) -> void:
	var eps := 0.002
	for i in RINGS:
		var t0 := float(i) / RINGS
		var t1 := float(i + 1) / RINGS
		for j in SIDES:
			var a0 := TAU * j / SIDES
			var a1 := TAU * (j + 1) / SIDES
			var quad := [[t0, a0], [t1, a0], [t1, a1], [t0, a1]]
			for k in [0, 1, 2, 0, 2, 3]:
				var t: float = quad[k][0]
				var a: float = quad[k][1]
				var p := _ring_point(t, a)
				# Normal por diferencias finitas, apuntando hacia afuera
				var dt := _ring_point(clampf(t + eps, 0.0, 1.0), a) - _ring_point(clampf(t - eps, 0.0, 1.0), a)
				var da := _ring_point(t, a + eps) - _ring_point(t, a - eps)
				var n := dt.cross(da).normalized()
				var outward := Vector3(0, p.y, p.z)
				if n.dot(outward) < 0.0:
					n = -n
				if t <= 0.001:
					n = Vector3.RIGHT
				var belly := smoothstep(0.15, -0.35, n.y)
				st.set_color(BACK.lerp(BELLY, belly))
				st.set_normal(n)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(p)


static func _top_y(t: float) -> float:
	return _ring_point(t, 0.0).y


static func _x(t: float) -> float:
	return LENGTH * (0.5 - t)


static func _fin(st: SurfaceTool, pts: Array, color: Color) -> void:
	# Abanico desde el primer punto; las aletas se ven por ambos lados
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[1]
	var c: Vector3 = pts[2]
	var n := (b - a).cross(c - a).normalized()
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			st.set_color(color)
			st.set_normal(n)
			st.set_uv(Vector2(1, 0))
			st.add_vertex(p)


static func _fins(st: SurfaceTool) -> void:
	# Dorsal: borde delantero largo y curvo, trasero corto con muesca
	_fin(st, [
		Vector3(_x(0.30), _top_y(0.30) - 0.02, 0),
		Vector3(_x(0.36), _top_y(0.36) + 0.2, 0),
		Vector3(_x(0.43), _top_y(0.43) + 0.36, 0),
		Vector3(_x(0.47), _top_y(0.47) + 0.06, 0),
		Vector3(_x(0.52), _top_y(0.52) - 0.02, 0),
	], FIN)

	# Segunda dorsal y anal, pequeñas
	_fin(st, [
		Vector3(_x(0.78), _top_y(0.78) - 0.01, 0),
		Vector3(_x(0.82), _top_y(0.82) + 0.09, 0),
		Vector3(_x(0.85), _top_y(0.85) - 0.01, 0),
	], FIN)
	_fin(st, [
		Vector3(_x(0.76), -_top_y(0.76) * 0.7, 0),
		Vector3(_x(0.80), -_top_y(0.80) * 0.7 - 0.09, 0),
		Vector3(_x(0.83), -_top_y(0.83) * 0.7, 0),
	], FIN)

	# Pectorales: alas hacia abajo y atrás, a cada lado
	for side: float in [-1.0, 1.0]:
		var root_z := WIDTH * 0.75 * side
		_fin(st, [
			Vector3(_x(0.27), -0.08, root_z),
			Vector3(_x(0.44), -0.24, root_z + 0.5 * side),
			Vector3(_x(0.47), -0.21, root_z + 0.42 * side),
			Vector3(_x(0.38), -0.1, root_z),
		], FIN.lerp(BELLY, 0.15))

	# Cola: lóbulo de arriba más grande que el de abajo
	var tail_x := _x(1.0)
	var root_top := Vector3(tail_x + 0.04, 0.05, 0)
	var root_bot := Vector3(tail_x + 0.04, -0.04, 0)
	var notch := Vector3(tail_x - 0.2, 0.01, 0)
	var upper_tip := Vector3(tail_x - 0.55, 0.62, 0)
	var upper_mid := Vector3(tail_x - 0.26, 0.38, 0)
	var lower_tip := Vector3(tail_x - 0.36, -0.36, 0)
	_fin(st, [root_top, upper_mid, upper_tip, notch], FIN)
	_fin(st, [root_top, notch, root_bot], FIN)
	_fin(st, [root_bot, notch, lower_tip], FIN)


static func _eyes(st: SurfaceTool) -> void:
	for side: float in [-1.0, 1.0]:
		var c := _ring_point(0.1, PI * 0.5 * side - 0.55 * side) * 0.98
		var r := 0.028
		var steps := 8
		for i in steps:
			for j in steps:
				var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
				for k in [0, 1, 2, 0, 2, 3]:
					var th: float = PI * quad[k][0] / steps
					var ph: float = TAU * quad[k][1] / steps
					var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
					st.set_color(EYE)
					st.set_normal(n)
					st.set_uv(Vector2(0, 0))
					st.add_vertex(c + n * r)


static func shader() -> Shader:
	if _shader:
		return _shader
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float swim_speed = 3.0;
uniform float phase = 0.0;

varying vec3 v_normal;
varying vec3 v_pos;
varying float v_fin;

void vertex() {
	// Ola de nado: casi nada en la cabeza, mucho en la cola
	float tail = smoothstep(0.6, -1.6, VERTEX.x);
	float wave = sin(TIME * swim_speed + phase - VERTEX.x * 2.6);
	VERTEX.z += wave * tail * tail * 0.32;
	// La cabeza contrarresta un poco
	VERTEX.z -= sin(TIME * swim_speed + phase) * 0.03 * smoothstep(0.2, 1.0, VERTEX.x);
	v_pos = VERTEX;
	v_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_fin = UV.x;
}

void fragment() {
	vec3 n = normalize(v_normal);
	vec3 light = normalize(vec3(0.35, 0.85, 0.45));
	float d = dot(n, light);
	float diff = v_fin > 0.5 ? abs(d) * 0.8 : max(d, 0.0);
	vec3 col = COLOR.rgb * (0.38 + 0.72 * diff);

	// Brillo húmedo
	vec3 h = normalize(light + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, h), 0.0), 28.0) * (1.0 - v_fin);
	col += vec3(0.35, 0.45, 0.5) * spec;

	// Cáusticas del agua sobre el lomo
	float c = sin(v_pos.x * 9.0 + TIME * 1.7) * sin(v_pos.z * 11.0 - TIME * 1.3 + v_pos.x * 3.0);
	col += vec3(0.25, 0.4, 0.45) * max(c, 0.0) * max(n.y, 0.0) * 0.22;

	// Borde azulado: el tiburón está bajo el agua
	float rim = pow(1.0 - abs(n.z), 3.0);
	col = mix(col, vec3(0.35, 0.65, 0.8), rim * 0.25);
	col = mix(col, vec3(0.08, 0.3, 0.42), 0.12);

	ALBEDO = col;
}
"""
	return _shader

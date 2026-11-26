// Criaturas hechas con modelo y textura (tiburón, tortuga de Tripo).
// Miran a +X. El movimiento va en el shader para que sea liviano:
//   wave = ola de nado hacia la cola (tiburón)
//   flap = aleteo de las aletas de los lados (tortuga)
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float swim_speed = 3.0;
uniform float phase = 0.0;
uniform float wave = 0.0;
uniform float flap = 0.0;
uniform float flap_from = 0.3;
uniform float flash = 0.0;        // destello blanco al recibir un golpe
uniform vec3 water : source_color = vec3(0.16, 0.5, 0.74);

varying vec3 v_n;

void vertex() {
	float tail = smoothstep(0.6, -1.6, VERTEX.x);
	VERTEX.z += sin(TIME * swim_speed + phase - VERTEX.x * 2.6) * tail * tail * wave;
	VERTEX.z -= sin(TIME * swim_speed + phase) * 0.03 * wave * smoothstep(0.2, 1.0, VERTEX.x);
	float side = smoothstep(flap_from, flap_from + 0.4, abs(VERTEX.z));
	VERTEX.y += sin(TIME * swim_speed + phase - abs(VERTEX.z) * 1.5) * side * side * flap;
	v_n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_n);
	vec3 L = normalize(vec3(0.35, 0.8, 0.5));
	float d = max(dot(n, L), 0.0);
	vec3 base = texture(albedo_tex, UV).rgb * tint;
	vec3 col = base * (0.72 + 0.45 * smoothstep(0.1, 0.7, d));
	float rim = pow(1.0 - max(dot(n, VIEW), 0.0), 3.0);
	col = mix(col, vec3(0.45, 0.75, 0.9), rim * 0.25);
	col = mix(col, water, 0.08);
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0) * 0.8);
	ALBEDO = col;
}

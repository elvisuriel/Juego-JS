// Suelo, rocas, corales, algas y ruinas del mar en 3D.
// Sin luces de Godot (más rápido en celulares): la luz, las cáusticas
// del agua y la neblina azul se calculan aquí.
// UV.x = cuánto se mece con la corriente (0 = quieto).
// UV.y = 1 en piezas delgadas (algas, aletas): se iluminan por ambos lados.
shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;

uniform vec3 water : source_color = vec3(0.16, 0.5, 0.74);
uniform float cam_dist = 30.0;
uniform float caustic = 1.0;
uniform float sway = 0.22;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 w_pos;
varying vec3 w_nrm;
varying float v_thin;

float caustics(vec2 p, float t) {
	p *= 0.85;
	float a = sin(p.x * 2.1 + t * 0.9 + sin(p.y * 1.7 + t * 0.6) * 1.6);
	float b = sin(p.y * 2.4 - t * 0.7 + sin(p.x * 1.3 - t * 0.5) * 1.6);
	float c = 1.0 - abs(a + b) * 0.5;
	return pow(c, 8.0);
}

void vertex() {
	float s = UV.x;
	if (s > 0.0) {
		float ph = VERTEX.x * 0.7 + VERTEX.z * 0.5;
		VERTEX.x += sin(TIME * 1.3 + ph) * s * sway;
		VERTEX.z += cos(TIME * 1.05 + ph * 1.3) * s * sway * 0.7;
	}
	w_pos = VERTEX;
	w_nrm = NORMAL;
	v_thin = UV.y;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 L = normalize(vec3(-0.4, 0.85, 0.35));
	float d = dot(n, L);
	float diff = v_thin > 0.5 ? abs(d) * 0.85 : max(d, 0.0);
	vec3 col = COLOR.rgb * tint * (0.45 + 0.68 * diff);

	// Cáusticas: la luz del sol que entra moviéndose por el agua
	float up = v_thin > 0.5 ? 0.5 : max(n.y, 0.0);
	col += vec3(0.6, 0.85, 0.9) * caustics(w_pos.xz, TIME) * up * caustic * 0.2;

	// Lo profundo es más oscuro
	col *= mix(0.78, 1.0, smoothstep(-1.0, 1.5, w_pos.y));

	// Neblina azul: lo que está lejos (arriba en pantalla) se pierde en el agua
	float depth = -VERTEX.z;
	float fog = smoothstep(cam_dist - 3.0, cam_dist + 20.0, depth) * 0.8;
	col = mix(col, water, 0.12 + fog);

	ALBEDO = col;
}

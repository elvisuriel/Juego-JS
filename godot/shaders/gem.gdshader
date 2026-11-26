// Diamante tallado: caras planas que destellan al girar.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 color : source_color = vec3(0.4, 0.8, 1.0);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 L = normalize(vec3(0.3, 0.8, 0.5));
	float d = max(dot(n, L), 0.0);
	vec3 col = color * (0.35 + 0.75 * d);
	// Destello de las caras
	vec3 r = reflect(-VIEW, n);
	float spark = pow(max(dot(r, L), 0.0), 18.0);
	col += vec3(1.0) * spark * 0.9;
	// Borde brillante
	float rim = pow(1.0 - max(dot(n, VIEW), 0.0), 2.5);
	col += mix(color, vec3(1.0), 0.5) * rim * 0.6;
	ALBEDO = col;
}

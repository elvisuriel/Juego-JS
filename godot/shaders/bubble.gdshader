// Burbuja transparente (power-ups, escudo, burbujas que suben).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float base_alpha = 0.08;
uniform float rim_alpha = 0.75;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.2);
	// Reflejo de luz arriba a la izquierda
	vec3 h = normalize(vec3(-0.45, 0.6, 0.65));
	float spot = pow(max(dot(normalize(NORMAL), h), 0.0), 40.0);
	ALBEDO = mix(color.rgb, vec3(1.0), spot);
	ALPHA = clamp(base_alpha + f * rim_alpha + spot * 0.8, 0.0, 1.0) * color.a;
}

// Sombra redonda en el suelo debajo de lo que nada.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float strength = 0.35;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0, 0.06, 0.12);
	ALPHA = smoothstep(1.0, 0.2, r) * strength;
}

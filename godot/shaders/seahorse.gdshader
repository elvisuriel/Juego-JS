// Caballito de mar 3D: color de la skin, luz suave tipo caricatura y brillo.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/skin.gdshaderinc"

uniform vec4 modulate : source_color = vec4(1.0);
uniform float flutter_speed = 14.0;
uniform vec3 water : source_color = vec3(0.16, 0.5, 0.74);

varying vec3 v_n;
varying float v_y;

void vertex() {
	VERTEX = flutter(VERTEX, UV, TIME, flutter_speed);
	v_n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_y = VERTEX.y;
}

void fragment() {
	vec3 n = normalize(v_n);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 L = normalize(vec3(0.35, 0.8, 0.5));
	float d = max(dot(n, L), 0.0);
	// Dos tonos suaves, como dibujo animado
	float toon = smoothstep(0.1, 0.3, d) * 0.45 + smoothstep(0.55, 0.75, d) * 0.25;
	vec3 base = skin(use_tex ? texture(albedo_tex, UV).rgb : COLOR.rgb, v_y + 0.6);
	// Los modelos con textura ya traen sus sombras: se aclaran más
	vec3 col = use_tex ? base * (0.78 + toon * 0.45) : base * (0.48 + toon);
	float spec = pow(max(dot(reflect(-L, n), VIEW), 0.0), 30.0);
	col += vec3(1.0) * spec * 0.35;
	float rim = pow(1.0 - max(dot(n, VIEW), 0.0), 3.0);
	col += vec3(1.0, 0.9, 0.95) * rim * 0.25;
	col = mix(col, water, 0.06);
	ALBEDO = col * modulate.rgb;
}

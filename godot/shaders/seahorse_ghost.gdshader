// Silueta del caballito cuando queda detrás de rocas o algas: solo se
// dibuja donde algo lo tapa, así nunca se pierde de vista.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never, depth_test_inverted;

#include "res://shaders/skin.gdshaderinc"

uniform float flutter_speed = 14.0;

// Se adelanta hacia la cámara: así el caballito no se "tapa a sí mismo"
// (aleta detrás del cuerpo) y solo sale la silueta si lo tapa otra cosa.
uniform float push = 0.7;

void vertex() {
	vec3 v = flutter(VERTEX, UV, TIME, flutter_speed);
	vec4 vp = MODELVIEW_MATRIX * vec4(v, 1.0);
	vp.z += push;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), VIEW), 0.0), 1.5);
	ALBEDO = skin(vec3(1.0, 0.55, 0.78), 0.0);
	ALPHA = 0.35 + rim * 0.4;
}

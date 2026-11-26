// Borde oscuro de caricatura del caballito (casco invertido).
shader_type spatial;
render_mode unshaded, cull_front;

#include "res://shaders/skin.gdshaderinc"

uniform float width = 0.022;
uniform float flutter_speed = 14.0;

void vertex() {
	if (!use_tex && UV.y > 0.5) {
		VERTEX = vec3(0.0);       // las aletas no llevan borde
	} else {
		VERTEX += NORMAL * width;
	}
}

void fragment() {
	ALBEDO = use_tex ? vec3(0.02, 0.07, 0.16) : skin(vec3(0.42, 0.04, 0.2), 0.0);
}

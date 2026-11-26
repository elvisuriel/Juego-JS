// Brillo suave (se suma a lo de atrás): halo de diamantes, chispas y
// rayos de sol. mode 0 = círculo de frente a la cámara, 1 = rayo de luz.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.5, 0.6);
uniform int mode = 0;
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * sx,
			INV_VIEW_MATRIX[1] * sy,
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
	}
}

void fragment() {
	float a;
	if (mode == 0) {
		float r = length(UV - vec2(0.5)) * 2.0;
		a = pow(max(1.0 - r, 0.0), 2.2);
	} else {
		// Rayo: se desvanece hacia abajo y en los lados, y titila
		float side = 1.0 - abs(UV.x - 0.5) * 2.0;
		a = pow(max(side, 0.0), 1.5) * (1.0 - UV.y) * (0.75 + 0.25 * sin(TIME * 0.8 + UV.x * 3.0));
	}
	ALBEDO = color.rgb * a * color.a;
}

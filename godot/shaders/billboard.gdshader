// Personaje dibujado (el caballito) parado en el mundo 3D y siempre de
// frente a la cámara, como los personajes de Dofus. Incluye las skins
// (giro de tono), cuadro de animación, espejo y parpadeo.
// Se dibuja siempre encima: el caballito nunca queda tapado por algas o rocas.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform int frames = 2;
uniform int frame = 0;
uniform bool flip = false;
uniform vec4 modulate : source_color = vec4(1.0);
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;
uniform bool rainbow = false;
uniform vec3 water : source_color = vec3(0.16, 0.5, 0.74);

void vertex() {
	// De frente a la cámara, conservando la escala del nodo
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * sx,
		INV_VIEW_MATRIX[1] * sy,
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float u = flip ? 1.0 - UV.x : UV.x;
	vec2 uv = vec2((u + float(frame)) / float(frames), UV.y);
	vec4 t = texture(tex, uv);
	vec3 hsv = rgb2hsv(t.rgb);
	float h = hue;
	if (rainbow) {
		h += TIME * 0.25 + UV.y * 0.8;
	}
	hsv.x = fract(hsv.x + h);
	hsv.y = clamp(hsv.y * sat, 0.0, 1.0);
	hsv.z = clamp(hsv.z * val, 0.0, 1.0);
	vec3 col = hsv2rgb(hsv) * modulate.rgb;
	col = mix(col, water, 0.08);
	ALBEDO = col;
	ALPHA = t.a * modulate.a;
}

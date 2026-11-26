// Skins del caballito: giro de tono sobre el rosa original.
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;
uniform bool rainbow = false;
// Modelos con textura (ej. el caballito Cristal hecho en Tripo)
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;

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

vec3 skin(vec3 c, float y) {
	vec3 hsv = rgb2hsv(c);
	float h = hue;
	if (rainbow) {
		h += TIME * 0.25 + y * 0.8;
	}
	hsv.x = fract(hsv.x + h);
	hsv.y = clamp(hsv.y * sat, 0.0, 1.0);
	hsv.z = clamp(hsv.z * val, 0.0, 1.0);
	return hsv2rgb(hsv);
}

// Aleteo de las aletas (UV.x = cuánto aletea)
vec3 flutter(vec3 v, vec2 uv, float t, float speed) {
	if (!use_tex && uv.x > 0.0) {
		v.z += sin(t * speed + v.y * 16.0) * uv.x * 0.06;
	}
	return v;
}

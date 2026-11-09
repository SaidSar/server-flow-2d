shader_type canvas_item;
// Cambia el color de la sudadera del avatar sin tocar piel, pelo, silla ni audífonos:
// solo se recolorean los píxeles claros y saturados cuyo tono está cerca de `base_hue`.
// El sombreado (los pliegues) se conserva escalando saturación y valor.

uniform bool recolor = false;
uniform float base_hue = 0.61;
uniform float hue_range = 0.07;
// Saturación y valor de la sudadera original.
uniform vec2 base_sv = vec2(0.71, 0.97);
uniform vec3 target : source_color = vec3(1.0);

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (recolor) {
		vec3 hsv = rgb2hsv(col.rgb);
		float dh = abs(hsv.x - base_hue);
		dh = min(dh, 1.0 - dh);
		float key = (1.0 - smoothstep(hue_range * 0.6, hue_range, dh)) * smoothstep(0.25, 0.4, hsv.y) * smoothstep(0.4, 0.55, hsv.z);
		vec3 t = rgb2hsv(target);
		vec3 shifted = vec3(t.x, clamp(hsv.y * t.y / max(base_sv.x, 0.01), 0.0, 1.0), clamp(hsv.z * t.z / max(base_sv.y, 0.01), 0.0, 1.0));
		col.rgb = mix(col.rgb, hsv2rgb(shifted), key);
	}
	COLOR = col;
}

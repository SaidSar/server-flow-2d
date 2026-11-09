shader_type canvas_item;
// Pared o piso que no tiene su propio PNG renderizado.
// La textura del sprite es el render de una opción "base" (forma y sombras ya horneadas).
//  - Tinte: base * (color / color_base). Reproduce los renders de Blender con ~1-6/255 de error.
//  - Patrón: el patrón se proyecta sobre el plano de la pared o del piso con la proyección isométrica del cuarto
//    (así se ve en perspectiva) y se multiplica por la iluminación de la base.
// En las paredes, `mask_ref` es el render del mismo muro con otro color: donde casi no cambia (pizarrón, trazos)
// no es pared y se deja igual.

uniform sampler2D mask_ref : filter_nearest;
uniform bool use_mask = false;
uniform vec3 base_color = vec3(0.9, 0.88, 0.83);
uniform vec3 tint = vec3(1.0);
uniform bool use_pattern = false;
uniform sampler2D pattern : source_color, filter_linear_mipmap, repeat_enable;
// Posición del sprite en el lienzo 2x del cuarto (px).
uniform vec2 layer_offset = vec2(0.0);
// Punto del lienzo que corresponde a (0, 0) del plano y matriz inversa 2x2 (fila mayor) píxel → metros.
uniform vec2 plane_origin = vec2(0.0);
uniform vec4 plane_inv = vec4(1.0, 0.0, 0.0, 1.0);
uniform float tile_m = 1.0;
// En las paredes la v crece hacia arriba y la textura hacia abajo.
uniform bool flip_v = true;

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec3 base = max(base_color, vec3(0.02));
	vec3 result;
	if (use_pattern) {
		vec2 px = UV / TEXTURE_PIXEL_SIZE + layer_offset - plane_origin;
		vec2 meters = vec2(plane_inv.x * px.x + plane_inv.y * px.y, plane_inv.z * px.x + plane_inv.w * px.y);
		if (flip_v) {
			meters.y = -meters.y;
		}
		vec3 ratio = a.rgb / base;
		float light = (ratio.r + ratio.g + ratio.b) / 3.0;
		result = texture(pattern, meters / tile_m).rgb * light;
	} else {
		result = a.rgb * (tint / base);
	}
	float amount = 1.0;
	if (use_mask) {
		vec3 other = texture(mask_ref, UV).rgb;
		float relative = length(a.rgb - other) / max(length(a.rgb), 0.02);
		amount = smoothstep(0.4, 0.6, relative);
	}
	COLOR = vec4(mix(a.rgb, clamp(result, 0.0, 1.0), amount), a.a);
}

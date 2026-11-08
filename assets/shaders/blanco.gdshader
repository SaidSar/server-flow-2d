shader_type canvas_item;

// Color de los íconos: lo pone icono_particula.gd con el token title_particle del tema.
uniform vec4 tinte : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // Lee el color original del píxel de la textura
    vec4 color_original = texture(TEXTURE, UV);
    
    // Sobrescribe RGB con el tinte (blanco en el tema oscuro), mantiene el alpha original
    COLOR = vec4(tinte.rgb, color_original.a);
}

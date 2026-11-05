shader_type canvas_item;

void fragment() {
    // Lee el color original del píxel de la textura
    vec4 color_original = texture(TEXTURE, UV);
    
    // Sobrescribe RGB a blanco puro, mantiene el alpha original
    COLOR = vec4(1.0, 1.0, 1.0, color_original.a);
}

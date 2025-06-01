shader_type canvas_item;

uniform bool in_water = false;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (in_water && UV.y > 0.5) {
        // Completely hide bottom half
        discard;  // This completely removes the pixel
    }

    COLOR = tex_color;
}
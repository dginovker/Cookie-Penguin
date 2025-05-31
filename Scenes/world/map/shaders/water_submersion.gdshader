shader_type canvas_item;

uniform bool in_water;
uniform float submersion_alpha : hint_range(0.0, 1.0) = 0.2;
uniform vec3 water_tint : source_color = vec3(0.8, 0.9, 1.0);
uniform float water_darkness : hint_range(0.0, 1.0) = 0.8;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (in_water && UV.y > 0.5) {
        // Apply water effects to bottom half
        tex_color.rgb *= water_tint * water_darkness;
        tex_color.a *= submersion_alpha;
    }

    COLOR = tex_color;
}
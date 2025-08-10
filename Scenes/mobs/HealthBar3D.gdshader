shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_test_disabled; // add depth_test_disabled if you want always on top

uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform float border = 0.10;
uniform vec4 bg_color   : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec4 fill_full  : source_color = vec4(0.2, 0.85, 0.3, 1.0);
uniform vec4 fill_empty : source_color = vec4(0.85, 0.2, 0.2, 1.0);
uniform vec4 border_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec2 uv = clamp(UV, vec2(0.0), vec2(1.0));

    bool in_border = (uv.x < border) || (uv.x > 1.0 - border) || (uv.y < border) || (uv.y > 1.0 - border);
    vec4 col = bg_color;

    if (in_border) {
        col = border_col;
    } else {
        float inner_x = (uv.x - border) / max(1.0 - 2.0 * border, 0.001);
        if (inner_x <= health) {
            col = mix(fill_empty, fill_full, clamp(health, 0.0, 1.0));
        }
    }

    ALBEDO = col.rgb;
    ALPHA  = col.a; // enabled by blend_mix
}

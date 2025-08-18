shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;

void vertex() {
    // world origin
    vec3 origin_ws = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // camera axes (Godot 4 names)
    vec3 cam_right_ws = normalize(INV_VIEW_MATRIX[0].xyz);
    vec3 cam_up_ws    = normalize(INV_VIEW_MATRIX[1].xyz);

    // recover original sprite scale along local X,Y from MODEL_MATRIX
    float sx = length(MODEL_MATRIX[0].xyz);
    float sy = length(MODEL_MATRIX[1].xyz);

    // place vertex in world using camera axes but with original scale
    vec3 pos_ws = origin_ws + cam_right_ws * (VERTEX.x * sx) + cam_up_ws * (VERTEX.y * sy);

    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos_ws, 1.0);
}

void fragment() {
    if (UV.y > 0.5) discard;     // hide bottom half, exact 50% of the frame
    vec4 c = texture(sprite_tex, UV);
    ALBEDO = c.rgb;
    ALPHA  = c.a;
}

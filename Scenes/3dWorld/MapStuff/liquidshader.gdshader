// water_overlay_asset.gdshader  (Godot 4.x)
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D water_tex : source_color; // your 32x32 PNG
uniform sampler2D liquid_mask;

uniform vec2  map_origin   = vec2(0.0); // world coords for mask pixel (0,0)
uniform float ppm          = 1.0;       // pixels per meter in the mask

// Asset tiling and scroll (repeats PER METER)
uniform float water_tiling = 1.0;       // 1.0 = one 32x32 tex per 1m tile
uniform vec2  scroll       = vec2(0.05, 0.03);

// Shoreline tint (no “deep” color nonsense)
uniform vec3  shore_tint_color    = vec3(0.45, 0.75, 0.95); // light blue
uniform float shore_tint_strength = 0.35;  // 0..1 mix toward tint
uniform float shore_edge          = 0.08;  // 0..0.5 band width in mask units
uniform float shore_blur_texels   = 1.0;   // >0 to stabilize band; 0 = use raw mask

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

float mask_raw(vec2 uv){ return texture(liquid_mask, uv).r; }

float mask_blur(vec2 uv){
    if (shore_blur_texels <= 0.0) return mask_raw(uv);
    vec2 o = shore_blur_texels / vec2(textureSize(liquid_mask, 0));
    float m = texture(liquid_mask, uv).r;
    m += texture(liquid_mask, uv+vec2( o.x,0)).r;
    m += texture(liquid_mask, uv+vec2(-o.x,0)).r;
    m += texture(liquid_mask, uv+vec2(0, o.y)).r;
    m += texture(liquid_mask, uv+vec2(0,-o.y)).r;
    return m * 0.2;
}

void fragment(){
    // Map-space UV for the mask
    vec2 mu = ((WP.xz - map_origin) * ppm) / vec2(textureSize(liquid_mask,0));

    // Crisp coverage (no softened discard => no gaps)
    if (mask_raw(mu) <= 0.5) discard;

    // Tile your water asset per meter, with manual wrap
    vec2 uv = fract((WP.xz - map_origin) * water_tiling + TIME * scroll);
    vec3 base = texture(water_tex, uv).rgb;

    // Shoreline band computed from a blurred mask (visual only)
    float m_blur = mask_blur(mu);
    float band   = 1.0 - smoothstep(0.0, shore_edge, abs(m_blur - 0.5)); // 1 near shoreline, 0 elsewhere

    // Apply shoreline tint toward light blue without touching coverage
    vec3 tinted = base + band * shore_tint_strength * (shore_tint_color - base);

    ALBEDO    = tinted;
    ROUGHNESS = 0.2;
}

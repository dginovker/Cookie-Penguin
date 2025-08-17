// water_overlay_liquids_groundshore.gdshader (Godot 4.x)
shader_type spatial;
render_mode unshaded, cull_back;

// Liquid textures (32x32 tileable)
uniform sampler2D tex_shallow : source_color;
uniform sampler2D tex_deep    : source_color;
uniform sampler2D tex_lava    : source_color;

// Masks
uniform sampler2D mask_liquids; // RGB: R=shallow, G=deep, B=lava
uniform sampler2D mask0;        // ground layers 0..2 in RGB
uniform sampler2D mask1;        // ground layers 3..5 in RGB

// Mapping (world → mask/tiles)
uniform vec2  map_origin   = vec2(0.0); // world coord of mask pixel (0,0)
uniform float ppm          = 1.0;       // pixels per meter in masks
uniform bool  center_samples = true;    // add half-texel to hit pixel centers

// Per-liquid tiling (repeats per meter) and scroll
uniform float tile_shallow = 1.0;
uniform float tile_deep    = 1.0;
uniform float tile_lava    = 1.0;
uniform vec2  scroll_shallow = vec2(0.05, 0.03);
uniform vec2  scroll_deep    = vec2(0.03, 0.02);
uniform vec2  scroll_lava    = vec2(0.07, 0.05);

// Shoreline tints (per liquid)
uniform vec3  shore_tint_water    = vec3(0.45, 0.75, 0.95); // light blue
uniform float shore_strength_shallow = 0.35;
uniform float shore_strength_deep    = 0.35;
uniform float shore_strength_lava    = 0.00;                // no blue on lava

// Band shaping (visual only; does not affect coverage)
uniform float shore_edge          = 0.08; // ~0.04..0.12 typical
uniform float shore_blur_texels   = 1.0;  // 0 = off

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; } // world pos via model matrix :contentReference[oaicite:1]{index=1}

vec2 texel_center_offset(){
    if (!center_samples) return vec2(0.0);
    return 0.5 / vec2(textureSize(mask_liquids, 0));        // need tex size; available in Godot shaders :contentReference[oaicite:2]{index=2}
}

vec2 mu(){ // mask UV (0..1), aligned to pixel centers if requested
    return ((WP.xz - map_origin) * ppm) / vec2(textureSize(mask_liquids,0)) + texel_center_offset();
}

vec2 uv(float rpt, vec2 scr){ // tile UV for the liquid textures
    return fract((WP.xz - map_origin) * rpt + TIME * scr);
}

float max_rgb(sampler2D M, vec2 uv){
    vec3 v = texture(M, uv).rgb;
    return max(v.r, max(v.g, v.b));
}

float blur_max_rgb(sampler2D M, vec2 uv, float texels){
    if (texels <= 0.0) return max_rgb(M, uv);
    vec2 o = texels / vec2(textureSize(M,0));
    float m = max_rgb(M, uv);
    m = max(m, max_rgb(M, uv + vec2( o.x, 0.0)));
    m = max(m, max_rgb(M, uv + vec2(-o.x, 0.0)));
    m = max(m, max_rgb(M, uv + vec2(0.0,  o.y)));
    m = max(m, max_rgb(M, uv + vec2(0.0, -o.y)));
    return m;
}

void fragment(){
    vec2 m = mu();

    // Coverage: liquid present?
    vec3 lw = texture(mask_liquids, m).rgb;
    float liq_any = max(lw.r, max(lw.g, lw.b));
    if (liq_any <= 0.5) discard; // crisp edge; no gaps

    // Choose base liquid sample (priority: lava > deep > shallow)
    vec3 col = lw.b>0.5 ? texture(tex_lava,    uv(tile_lava,    scroll_lava)).rgb :
               lw.g>0.5 ? texture(tex_deep,    uv(tile_deep,    scroll_deep)).rgb :
                          texture(tex_shallow, uv(tile_shallow, scroll_shallow)).rgb;

    // Ground occupancy (used ONLY to compute shoreline band)
    // Blend masks locally to avoid band on water–water seams.
    float g0 = blur_max_rgb(mask0, m, shore_blur_texels);
    float g1 = blur_max_rgb(mask1, m, shore_blur_texels);
    float g  = max(g0, g1); // 1≈ground, 0≈not ground

    // Band centered at ground edge, restricted to liquid side
    float band = 1.0 - smoothstep(0.0, shore_edge, abs(g - 0.5));
    band *= step(0.5, liq_any); // only on the water side

    // Per-liquid shoreline tint (lava default = 0 strength)
    float s = lw.b>0.5 ? shore_strength_lava :
              lw.g>0.5 ? shore_strength_deep  :
                         shore_strength_shallow;
    vec3  tc = lw.b>0.5 ? col /* no change */ : shore_tint_water;

    col += band * s * (tc - col);

    ALBEDO = col;
    ROUGHNESS = 0.2;
}

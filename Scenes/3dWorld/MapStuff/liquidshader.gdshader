// water_overlay_liquids_nohalo.gdshader (Godot 4.x)
shader_type spatial;
render_mode unshaded, cull_back;

// assets
uniform sampler2D tex_shallow : source_color;
uniform sampler2D tex_deep    : source_color;
uniform sampler2D tex_lava    : source_color;

// masks
uniform sampler2D mask_liquids; // RGB: R=shallow, G=deep, B=lava
uniform sampler2D mask0;        // ground 0..2 (RGB) — for rim only
uniform sampler2D mask1;        // ground 3..5 (RGB) — for rim only

// mapping
uniform vec2  map_origin = vec2(0.0);
uniform float ppm        = 1.0;
uniform bool  center_samples = false;

// tiling (repeats PER METER) + scroll
uniform float tile_shallow = 1.0;
uniform float tile_deep    = 1.0;
uniform float tile_lava    = 1.0;
uniform vec2  scroll_shallow = vec2(0.05,0.03);
uniform vec2  scroll_deep    = vec2(0.03,0.02);
uniform vec2  scroll_lava    = vec2(0.07,0.05);

// rim colors/strengths
uniform vec3  shore_tint_water       = vec3(0.45,0.75,0.95);
uniform float shore_strength_shallow = 0.35;
uniform float shore_strength_deep    = 0.35;

uniform vec3  shore_tint_lava        = vec3(1.0,0.55,0.20);
uniform float shore_strength_lava    = 0.30;   // set 0.0 to kill lava rim

// rim shaping (visual only; coverage is crisp)
uniform float shore_edge        = 0.3;
uniform float shore_blur_texels = 0.0;

// coverage + seams
uniform float coverage_dilate_texels = 0.01; // fills hairline gaps
uniform float water_mix_blur_texels  = 0.0;  // 0 = hard shallow↔deep seam

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 _center_off(){ return center_samples ? 0.5 / vec2(textureSize(mask_liquids,0)) : vec2(0.0); }
vec2 _mu(){ return ((WP.xz - map_origin) * ppm) / vec2(textureSize(mask_liquids,0)) + _center_off(); }
vec2 _tuv(float rpt, vec2 scr){ return fract((WP.xz - map_origin) * rpt + TIME*scr); }

vec3 _lr(vec2 uv){ return texture(mask_liquids, uv).rgb; } // raw liquids

// per-channel 8-neigh dilation (in texels)
vec3 _dilate(vec2 uv, float texels){
    if (texels <= 0.0) return _lr(uv);
    vec2 o = texels / vec2(textureSize(mask_liquids,0));
    vec3 m = _lr(uv);
    m = max(m, _lr(uv+vec2( o.x, 0.0)));
    m = max(m, _lr(uv+vec2(-o.x, 0.0)));
    m = max(m, _lr(uv+vec2(0.0,  o.y)));
    m = max(m, _lr(uv+vec2(0.0, -o.y)));
    m = max(m, _lr(uv+vec2( o.x,  o.y)));
    m = max(m, _lr(uv+vec2(-o.x,  o.y)));
    m = max(m, _lr(uv+vec2( o.x, -o.y)));
    m = max(m, _lr(uv+vec2(-o.x, -o.y)));
    return m;
}

float _blur_max_rgb(sampler2D m, vec2 uv, float texels){
    if (texels <= 0.0) { vec3 v = texture(m,uv).rgb; return max(v.r, max(v.g, v.b)); }
    vec2 o = texels / vec2(textureSize(m,0));
    vec3 a = texture(m,uv).rgb;
    vec3 b = texture(m,uv+vec2( o.x,0)).rgb;
    vec3 c = texture(m,uv+vec2(-o.x,0)).rgb;
    vec3 d = texture(m,uv+vec2(0, o.y)).rgb;
    vec3 e = texture(m,uv+vec2(0,-o.y)).rgb;
    vec3 mx = max(a, max(b, max(c, max(d, e))));
    return max(mx.r, max(mx.g, mx.b));
}
float _blur_ch(int ch, float texels, vec2 uv){
    if (texels <= 0.0) return texture(mask_liquids, uv)[ch];
    vec2 o = texels / vec2(textureSize(mask_liquids,0));
    vec3 a = texture(mask_liquids,uv).rgb;
    vec3 b = texture(mask_liquids,uv+vec2( o.x,0)).rgb;
    vec3 c = texture(mask_liquids,uv+vec2(-o.x,0)).rgb;
    vec3 d = texture(mask_liquids,uv+vec2(0, o.y)).rgb;
    vec3 e = texture(mask_liquids,uv+vec2(0,-o.y)).rgb;
    return (a[ch]+b[ch]+c[ch]+d[ch]+e[ch]) * 0.2;
}

void fragment(){
    vec2 mu = _mu();
    vec3 w_raw = _lr(mu);
    vec3 w_d   = _dilate(mu, coverage_dilate_texels);

    float cov      = max(w_d.r, max(w_d.g, w_d.b));      // dilated union
    float core_any = max(w_raw.r, max(w_raw.g, w_raw.b)); // non-dilated union
    if (cov <= 0.5) discard;

    // which liquid? choose from DILATED (for coverage consistency)
    bool lava_d  = (w_d.b > max(w_d.r, w_d.g));
    bool deep_d  = (!lava_d) && (w_d.g > w_d.r);
    bool shallow_d = (!lava_d) && !deep_d;

    // BASE COLOR:
    vec3 col;
    if (core_any > 0.5){
        // inside core liquid → sample asset (lava wins; water can blend)
        if (lava_d){
            col = texture(tex_lava, _tuv(tile_lava, scroll_lava)).rgb;
        } else {
            float ws = _blur_ch(0, water_mix_blur_texels, mu); // shallow
            float wd = _blur_ch(1, water_mix_blur_texels, mu); // deep
            float s = ws + wd; if (s > 1e-5){ ws/=s; wd/=s; } else { ws = shallow_d?1.0:0.0; wd = deep_d?1.0:0.0; }
            vec3 cs = texture(tex_shallow, _tuv(tile_shallow, scroll_shallow)).rgb;
            vec3 cd = texture(tex_deep,    _tuv(tile_deep,    scroll_deep   )).rgb;
            col = cs*ws + cd*wd;
        }
    } else {
        // in DILATION-ONLY margin → draw PURE rim color, NO water texture
        col = lava_d ? shore_tint_lava : shore_tint_water;
    }

    // RIM from ground; anchored to raw edge; widened by dilation so rim doesn’t “walk”
    float g0 = _blur_max_rgb(mask0, mu, shore_blur_texels);
    float g1 = _blur_max_rgb(mask1, mu, shore_blur_texels);
    float g  = max(g0, g1);

    vec2 ts = vec2(textureSize(mask_liquids,0));
    float extra = (coverage_dilate_texels <= 0.0) ? 0.0 : coverage_dilate_texels / min(ts.x, ts.y);
    float band = 1.0 - smoothstep(0.0, shore_edge + extra, abs(g - 0.5));
    band *= step(0.5, core_any); // rim only on water side of the RAW edge

    float strength = lava_d ? shore_strength_lava
                   : deep_d ? shore_strength_deep
                            : shore_strength_shallow;
    vec3  tint     = lava_d ? shore_tint_lava : shore_tint_water;

    col += band * strength * (tint - col);

    ALBEDO = col;
    ROUGHNESS = 0.2;
}

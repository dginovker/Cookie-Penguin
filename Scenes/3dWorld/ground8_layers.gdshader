// ground_6layers_rgb.shader
shader_type spatial;
render_mode cull_back;

// layer textures (seamless ideally)
uniform sampler2D t0 : source_color;
uniform sampler2D t1 : source_color;
uniform sampler2D t2 : source_color;
uniform sampler2D t3 : source_color;
uniform sampler2D t4 : source_color;
uniform sampler2D t5 : source_color;

uniform sampler2D detail_tex : source_color;

uniform sampler2D mask0;      // RGB -> layers 0..2
uniform sampler2D mask1;      // RGB -> layers 3..5
uniform sampler2D liquid_mask;

uniform vec3 tiling0 = vec3(3.0,3.0,3.0); // per-layer repeats per map
uniform vec3 tiling1 = vec3(3.0,3.0,3.0);
uniform float detail_tiling = 14.0;
uniform float detail_mix    = 0.3;

uniform vec2  map_origin = vec2(0.0); // world coords for mask pixel (0,0)
uniform float ppm        = 1.0;       // pixels per meter for masks
uniform float mask_soften = 1.0;      // texels; 0 disables blur

varying vec3 WP;

void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 map_size(){
    return vec2(textureSize(mask0,0)) / ppm;        // meters
}

vec2 base_uv(float repeats){
    vec2 uv = (WP.xz - map_origin) / map_size();    // 0..1 across map
    return fract(uv * repeats);                     // manual wrap
}

vec3 tex_rgb(sampler2D t, vec2 uv){ return texture(t, uv).rgb; }

vec3 blur3_rgb(sampler2D m, vec2 uv){
    if (mask_soften <= 0.0) return texture(m, uv).rgb;
    vec2 o = mask_soften / vec2(textureSize(m,0));
    vec3 c = texture(m, uv).rgb;
    c += texture(m, uv+vec2( o.x,0)).rgb;
    c += texture(m, uv+vec2(-o.x,0)).rgb;
    c += texture(m, uv+vec2(0, o.y)).rgb;
    c += texture(m, uv+vec2(0,-o.y)).rgb;
    return c * 0.2;
}

void fragment(){
    // liquid cutout
    vec2 mu = ((WP.xz - map_origin) * ppm) / vec2(textureSize(liquid_mask,0));
    float water = texture(liquid_mask, mu).r;
    if (water > 0.5) { ALPHA = 0.0; ALPHA_SCISSOR_THRESHOLD = 0.5; discard; }

    ivec2 ts = textureSize(mask0,0);
    vec2 m0u = ((WP.xz - map_origin) * ppm) / vec2(ts);
    vec3 a = blur3_rgb(mask0, m0u); // weights 0..2
    vec3 b = blur3_rgb(mask1, m0u); // weights 3..5

    vec3 c = vec3(0.0);
    c += tex_rgb(t0, base_uv(tiling0.x)) * a.r;
    c += tex_rgb(t1, base_uv(tiling0.y)) * a.g;
    c += tex_rgb(t2, base_uv(tiling0.z)) * a.b;
    c += tex_rgb(t3, base_uv(tiling1.x)) * b.r;
    c += tex_rgb(t4, base_uv(tiling1.y)) * b.g;
    c += tex_rgb(t5, base_uv(tiling1.z)) * b.b;

    float w = a.r+a.g+a.b + b.r+b.g+b.b;
    if (w > 0.0) c /= w;

    float d = texture(detail_tex, fract(((WP.xz - map_origin)/map_size()) * detail_tiling)).r;
    ALBEDO = c * mix(1.0, d*1.15, detail_mix);
    ROUGHNESS = 0.9;
}

// ground_6layers_rgb_meter.shader
shader_type spatial;
render_mode cull_back;

// 6 layer textures (color, seamless ideally)
uniform sampler2D t0 : source_color; // grass
uniform sampler2D t1 : source_color; // sand
uniform sampler2D t2 : source_color; // forest
uniform sampler2D t3 : source_color; // rock
uniform sampler2D t4 : source_color; // ice
uniform sampler2D t5 : source_color; // desolate

// breakup noise (grayscale)
uniform sampler2D detail_tex : source_color;

// masks: RGB carries 3 layers each
uniform sampler2D mask0;         // layers 0..2
uniform sampler2D mask1;         // layers 3..5
uniform sampler2D liquid_mask;   // L8: 0 solid, 1 liquid

// per-layer repeats PER METER
uniform vec3 tiling0 = vec3(1.0,1.0,1.0); // t0..t2
uniform vec3 tiling1 = vec3(1.0,1.0,1.0); // t3..t5
uniform float detail_tiling = 8.0;        // repeats per meter

// mask mapping
uniform vec2  map_origin = vec2(0.0);  // world coord of mask pixel (0,0)
uniform float ppm        = 1.0;        // pixels per meter in masks
uniform float mask_soften = 0.0;       // texels; 0 = crisp

// geometry option: 1 = cut holes; 0 = keep solid for overlay water
uniform float cutout = 1.0;

varying vec3 WP;

void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 uv_repeat(float repeats_per_meter){
    return fract((WP.xz - map_origin) * repeats_per_meter);
}

vec3 blur_rgb(sampler2D m, vec2 uv){
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
    ivec2 ts = textureSize(mask0,0);
    vec2 mu  = ((WP.xz - map_origin) * ppm) / vec2(ts);

    float water = texture(liquid_mask, mu).r;
    if (cutout > 0.5 && water > 0.5){
        ALPHA = 0.0; ALPHA_SCISSOR_THRESHOLD = 0.5; discard;
    }

    vec3 a = blur_rgb(mask0, mu); // weights for t0..t2
    vec3 b = blur_rgb(mask1, mu); // weights for t3..t5

    vec3 c = vec3(0.0);
    c += texture(t0, uv_repeat(tiling0.x)).rgb * a.r;
    c += texture(t1, uv_repeat(tiling0.y)).rgb * a.g;
    c += texture(t2, uv_repeat(tiling0.z)).rgb * a.b;
    c += texture(t3, uv_repeat(tiling1.x)).rgb * b.r;
    c += texture(t4, uv_repeat(tiling1.y)).rgb * b.g;
    c += texture(t5, uv_repeat(tiling1.z)).rgb * b.b;

    float w = a.r+a.g+a.b + b.r+b.g+b.b;
    if (w > 0.0) c /= w;

    float d = texture(detail_tex, uv_repeat(detail_tiling)).r;
    ALBEDO = c * mix(1.0, d*1.15, 0.30);
    ROUGHNESS = 0.9;
}

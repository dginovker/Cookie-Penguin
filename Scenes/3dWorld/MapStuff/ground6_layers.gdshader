// ground_6layers_cutout_liquids.gdshader
shader_type spatial;
render_mode cull_back;

// 6 terrain textures (color)
uniform sampler2D t0 : source_color; // layer 0
uniform sampler2D t1 : source_color; // layer 1
uniform sampler2D t2 : source_color; // layer 2
uniform sampler2D t3 : source_color; // layer 3
uniform sampler2D t4 : source_color; // layer 4
uniform sampler2D t5 : source_color; // layer 5

// breakup noise (grayscale)
uniform sampler2D detail_tex : source_color;

// masks
uniform sampler2D mask0;          // RGB -> layers 0..2
uniform sampler2D mask1;          // RGB -> layers 3..5
uniform sampler2D mask_liquids;   // RGB: R=shallow, G=deep, B=lava

// repeats PER METER
uniform vec3 tiling0 = vec3(1.0,1.0,1.0); // t0..t2
uniform vec3 tiling1 = vec3(1.0,1.0,1.0); // t3..t5
uniform float detail_tiling = 8.0;

// where mask pixel (0,0) lives in world coords, and pixels-per-meter
uniform vec2  map_origin = vec2(0.0);
uniform float ppm        = 1.0;

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 uv_map(){ return ((WP.xz - map_origin) * ppm) / vec2(textureSize(mask0,0)); }
vec2 uv_tile(float rpt){ return fract((WP.xz - map_origin) * rpt); }

void fragment(){
    // cutout: if any liquid present at this pixel, discard ground
    vec3 L = texture(mask_liquids, uv_map()).rgb;
    if (max(max(L.r, L.g), L.b) > 0.5) discard;

    vec3 a = texture(mask0, uv_map()).rgb; // weights 0..2
    vec3 b = texture(mask1, uv_map()).rgb; // weights 3..5

    vec3 col = vec3(0.0);
    col += texture(t0, uv_tile(tiling0.x)).rgb * a.r;
    col += texture(t1, uv_tile(tiling0.y)).rgb * a.g;
    col += texture(t2, uv_tile(tiling0.z)).rgb * a.b;
    col += texture(t3, uv_tile(tiling1.x)).rgb * b.r;
    col += texture(t4, uv_tile(tiling1.y)).rgb * b.g;
    col += texture(t5, uv_tile(tiling1.z)).rgb * b.b;

    float w = a.r+a.g+a.b + b.r+b.g+b.b;
    if (w > 0.0) col /= w;

    float d = texture(detail_tex, uv_tile(detail_tiling)).r;
    ALBEDO = col * mix(1.0, d*1.15, 0.30);
    ROUGHNESS = 0.9;
}

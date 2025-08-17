// ground_9layers_rgb_meter.gdshader
shader_type spatial;
render_mode cull_back;

// layer textures (color)
uniform sampler2D t0 : source_color; uniform sampler2D t1 : source_color; uniform sampler2D t2 : source_color;
uniform sampler2D t3 : source_color; uniform sampler2D t4 : source_color; uniform sampler2D t5 : source_color;
uniform sampler2D t6 : source_color; uniform sampler2D t7 : source_color; uniform sampler2D t8 : source_color;

// breakup noise
uniform sampler2D detail_tex : source_color;

// masks
uniform sampler2D mask0; // RGB -> layers 0..2
uniform sampler2D mask1; // RGB -> layers 3..5
uniform sampler2D mask2; // RGB -> layers 6..8

// repeats PER METER
uniform vec3 tiling0 = vec3(1.0); // t0..t2
uniform vec3 tiling1 = vec3(1.0); // t3..t5
uniform vec3 tiling2 = vec3(1.0); // t6..t8
uniform float detail_tiling = 8.0;

// mapping
uniform vec2  map_origin = vec2(0.0);
uniform float ppm        = 1.0;
uniform float mask_soften = 0.0; // texels; 0 = crisp

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 muv(sampler2D m){ return ((WP.xz - map_origin) * ppm) / vec2(textureSize(m,0)); }
vec2 tuv(float rpt){ return fract((WP.xz - map_origin) * rpt); }

vec3 blur3(sampler2D m, vec2 uv){
    if (mask_soften<=0.0) return texture(m,uv).rgb;
    vec2 o = mask_soften/vec2(textureSize(m,0));
    vec3 c=texture(m,uv).rgb;
    c+=texture(m,uv+vec2( o.x,0)).rgb;
    c+=texture(m,uv+vec2(-o.x,0)).rgb;
    c+=texture(m,uv+vec2(0, o.y)).rgb;
    c+=texture(m,uv+vec2(0,-o.y)).rgb;
    return c*0.2;
}

void fragment(){
    vec3 a = blur3(mask0, muv(mask0));
    vec3 b = blur3(mask1, muv(mask1));
    vec3 c = blur3(mask2, muv(mask2));

    vec3 col = vec3(0.0);
    col += texture(t0, tuv(tiling0.x)).rgb * a.r;
    col += texture(t1, tuv(tiling0.y)).rgb * a.g;
    col += texture(t2, tuv(tiling0.z)).rgb * a.b;
    col += texture(t3, tuv(tiling1.x)).rgb * b.r;
    col += texture(t4, tuv(tiling1.y)).rgb * b.g;
    col += texture(t5, tuv(tiling1.z)).rgb * b.b;
    col += texture(t6, tuv(tiling2.x)).rgb * c.r;
    col += texture(t7, tuv(tiling2.y)).rgb * c.g;
    col += texture(t8, tuv(tiling2.z)).rgb * c.b;

    float w = a.r+a.g+a.b + b.r+b.g+b.b + c.r+c.g+c.b;
    if (w>0.0) col /= w;

    float d = texture(detail_tex, tuv(detail_tiling)).r;
    ALBEDO = col * mix(1.0, d*1.15, 0.30);
    ROUGHNESS = 0.9;
}

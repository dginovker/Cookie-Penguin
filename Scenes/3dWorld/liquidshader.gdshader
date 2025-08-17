// water_plane.shader
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D water_norm;
uniform sampler2D liquid_mask;

uniform vec2  map_origin = vec2(0.0);
uniform float ppm        = 1.0;
uniform float mask_soften = 1.0;
uniform float tile = 2.5;
uniform vec2  scroll = vec2(0.05,0.03);
uniform vec3  deep_color = vec3(0.02,0.12,0.18);
uniform vec3  shallow_color = vec3(0.12,0.28,0.35);

varying vec3 WP;

void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 map_size(){ return vec2(textureSize(liquid_mask,0)) / ppm; }

float sample_liquid(vec2 mu){
    if (mask_soften <= 0.0) return texture(liquid_mask, mu).r;
    vec2 o = mask_soften / vec2(textureSize(liquid_mask,0));
    float m = texture(liquid_mask, mu).r;
    m += texture(liquid_mask, mu+vec2( o.x,0)).r;
    m += texture(liquid_mask, mu+vec2(-o.x,0)).r;
    m += texture(liquid_mask, mu+vec2(0, o.y)).r;
    m += texture(liquid_mask, mu+vec2(0,-o.y)).r;
    return m*0.2;
}

void fragment(){
    vec2 mu = ((WP.xz - map_origin) * ppm) / vec2(textureSize(liquid_mask,0));
    float m = sample_liquid(mu);
    if (m <= 0.5) { ALPHA = 0.0; ALPHA_SCISSOR_THRESHOLD = 0.5; discard; }

    vec2 uv = fract(((WP.xz - map_origin)/map_size()) * tile + TIME*scroll);
    vec3 n  = texture(water_norm, uv).xyz*2.0-1.0;
    vec3 col = mix(deep_color, shallow_color, clamp(m*1.2,0.0,1.0));
    ALBEDO = col;
    ROUGHNESS = 0.2;
}

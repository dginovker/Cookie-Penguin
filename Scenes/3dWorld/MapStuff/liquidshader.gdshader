// water_overlay_liquids.gdshader
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D tex_shallow : source_color;
uniform sampler2D tex_deep    : source_color;
uniform sampler2D tex_lava    : source_color;

uniform sampler2D mask_liquids; // RGB: R=shallow, G=deep, B=lava

uniform vec2  map_origin   = vec2(0.0);
uniform float ppm          = 1.0;

uniform float tile_shallow = 1.0;
uniform float tile_deep    = 1.0;
uniform float tile_lava    = 1.0;
uniform vec2  scroll_shallow = vec2(0.05,0.03);
uniform vec2  scroll_deep    = vec2(0.03,0.02);
uniform vec2  scroll_lava    = vec2(0.07,0.05);

uniform vec3  shore_tint_color    = vec3(0.45,0.75,0.95);
uniform float shore_tint_strength = 0.35;
uniform float shore_edge          = 0.08;
uniform float shore_blur_texels   = 1.0;

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 mu(){ return ((WP.xz - map_origin) * ppm) / vec2(textureSize(mask_liquids,0)); }
vec2 uv(float tile, vec2 scr){ return fract((WP.xz - map_origin) * tile + TIME*scr); }

vec3 blur_rgb(sampler2D m, vec2 uv, float t){
    if (t <= 0.0) return texture(m, uv).rgb;
    vec2 o = t/vec2(textureSize(m,0));
    vec3 c = texture(m, uv).rgb;
    c += texture(m, uv+vec2( o.x,0)).rgb;
    c += texture(m, uv+vec2(-o.x,0)).rgb;
    c += texture(m, uv+vec2(0, o.y)).rgb;
    c += texture(m, uv+vec2(0,-o.y)).rgb;
    return c*0.2;
}

void fragment(){
    vec2 m = mu();
    vec3 w = texture(mask_liquids, m).rgb;
    if (w.r<=0.5 && w.g<=0.5 && w.b<=0.5) discard;

    vec3 col = w.b>0.5 ? texture(tex_lava,    uv(tile_lava,    scroll_lava)).rgb
            : w.g>0.5 ? texture(tex_deep,    uv(tile_deep,    scroll_deep)).rgb
                       : texture(tex_shallow, uv(tile_shallow, scroll_shallow)).rgb;

    vec3 wb = blur_rgb(mask_liquids, m, shore_blur_texels);
    float u = max(max(wb.r, wb.g), wb.b);
    float band = 1.0 - smoothstep(0.0, shore_edge, abs(u - 0.5));
    col += band * shore_tint_strength * (shore_tint_color - col);

    ALBEDO = col; ROUGHNESS = 0.2;
}

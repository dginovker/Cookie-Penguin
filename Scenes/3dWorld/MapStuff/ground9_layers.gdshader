shader_type spatial;
render_mode cull_back;

// Layer textures (color)
uniform sampler2D t0 : source_color; uniform sampler2D t1 : source_color; uniform sampler2D t2 : source_color;
uniform sampler2D t3 : source_color; uniform sampler2D t4 : source_color; uniform sampler2D t5 : source_color;
uniform sampler2D t6 : source_color; uniform sampler2D t7 : source_color; uniform sampler2D t8 : source_color;

// Breakup (grayscale)
uniform sampler2D detail_tex : source_color;

// Masks (RGB weights): mask0 -> 0..2, mask1 -> 3..5, mask2 -> 6..8
uniform sampler2D mask0;
uniform sampler2D mask1;
uniform sampler2D mask2;

// Repeats PER METER
uniform vec3 tiling0 = vec3(1.0); // t0..t2
uniform vec3 tiling1 = vec3(1.0); // t3..t5
uniform vec3 tiling2 = vec3(1.0); // t6..t8

// Map alignment
uniform vec2 map_origin = vec2(0.0); // world XZ of mask pixel (0,0)

varying vec3 WP;
void vertex(){ WP = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }

vec2 mu(sampler2D m){
    vec2 ts = vec2(textureSize(m,0));
    return ((WP.xz - map_origin) / ts) + (0.1/ts); // ppm=1, center-sample
}
vec2 uv(float rpt){ return fract((WP.xz - map_origin) * rpt); } // repeats/meter

void fragment(){
    vec3 A = texture(mask0, mu(mask0)).rgb; // 0..2
    vec3 B = texture(mask1, mu(mask1)).rgb; // 3..5
    vec3 C = texture(mask2, mu(mask2)).rgb; // 6..8

    float w0=A.r, w1=A.g, w2=A.b, w3=B.r, w4=B.g, w5=B.b, w6=C.r, w7=C.g, w8=C.b;

    // mix_power = 3 (sharpen)
    w0*=w0*w0; w1*=w1*w1; w2*=w2*w2; w3*=w3*w3; w4*=w4*w4; w5*=w5*w5; w6*=w6*w6; w7*=w7*w7; w8*=w8*w8;

    // keep_top_n = 2
    float m1 = max(max(max(w0,w1),max(w2,w3)), max(max(w4,w5), max(w6, max(w7,w8))));
    float c0=(w0<m1)?w0:0.0, c1=(w1<m1)?w1:0.0, c2=(w2<m1)?w2:0.0, c3=(w3<m1)?w3:0.0, c4=(w4<m1)?w4:0.0;
    float c5=(w5<m1)?w5:0.0, c6=(w6<m1)?w6:0.0, c7=(w7<m1)?w7:0.0, c8=(w8<m1)?w8:0.0;
    float m2 = max(max(max(c0,c1),max(c2,c3)), max(max(c4,c5), max(c6, max(c7,c8))));
    float k0=step(m2,w0), k1=step(m2,w1), k2=step(m2,w2), k3=step(m2,w3), k4=step(m2,w4);
    float k5=step(m2,w5), k6=step(m2,w6), k7=step(m2,w7), k8=step(m2,w8);
    w0*=k0; w1*=k1; w2*=k2; w3*=k3; w4*=k4; w5*=k5; w6*=k6; w7*=k7; w8*=k8;

    float W = w0+w1+w2+w3+w4+w5+w6+w7+w8;
    if (W>0.0){ w0/=W; w1/=W; w2/=W; w3/=W; w4/=W; w5/=W; w6/=W; w7/=W; w8/=W; }

    vec3 col = vec3(0.0);
    col += texture(t0, uv(tiling0.x)).rgb * w0;
    col += texture(t1, uv(tiling0.y)).rgb * w1;
    col += texture(t2, uv(tiling0.z)).rgb * w2;
    col += texture(t3, uv(tiling1.x)).rgb * w3;
    col += texture(t4, uv(tiling1.y)).rgb * w4;
    col += texture(t5, uv(tiling1.z)).rgb * w5;
    col += texture(t6, uv(tiling2.x)).rgb * w6;
    col += texture(t7, uv(tiling2.y)).rgb * w7;
    col += texture(t8, uv(tiling2.z)).rgb * w8;

    float d = texture(detail_tex, uv(8.0)).r; // detail_tiling = 8
    ALBEDO = col * mix(1.0, d*1.15, 0.30);
    ROUGHNESS = 0.9;
}

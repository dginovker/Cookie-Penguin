shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform float start_time = 0.0;
uniform float life = 1.0;
uniform float rise = 1.0;
uniform float hp_left = 1.0;

float t01(){ return clamp((TIME - start_time)/max(life,0.0001), 0.0, 1.0); }

void vertex(){ VERTEX.z += rise * t01(); }   // local +Y == world +Z after the basis above
void fragment(){
    vec3 g = vec3(0.25,1.0,0.25), r = vec3(1.0,0.25,0.25);
    ALBEDO = mix(r, g, clamp(hp_left, 0.0, 1.0));
    ALPHA  = 1.0 - t01();
}

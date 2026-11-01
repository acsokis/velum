shader_type spatial;
render_mode cull_back, depth_draw_never;
uniform float flow_clock = 0.0;
uniform float coolant = 0.8;
uniform float charge = 0.8;
uniform float heat = 0.2;
uniform bool instanced_paths = false;
varying vec4 path_data;
void vertex() { path_data = INSTANCE_CUSTOM; }
void fragment() {
	float distance_along = instanced_paths ? (1.0-UV.y)*path_data.x+path_data.y : UV.y*2.0;
	float phase = distance_along*0.5-flow_clock;
	float strands = sin(phase*6.283185+sin(UV.x*18.84956+phase*2.0)*0.35);
	float bubbles = pow(max(0.0,sin(phase*12.56637)*sin(UV.x*31.4159+phase)),12.0);
	float filaments = smoothstep(0.6,0.97,strands);
	vec3 cold = vec3(0.025,0.20,0.17);
	vec3 warm = vec3(0.26,0.15,0.055);
	vec3 liquid = mix(cold,warm,clamp(heat*0.65,0.0,0.75));
	ALBEDO = liquid+vec3(0.08,0.19,0.15)*filaments;
	ROUGHNESS = 0.18;
	METALLIC = 0.12;
	EMISSION = vec3(0.12,0.65,0.47)*(filaments*0.32+bubbles*0.5)*(0.15+charge*0.45);
	ALPHA = clamp((0.38+filaments*0.30+bubbles*0.2)*(0.4+coolant*0.6),0.1,0.85);
}

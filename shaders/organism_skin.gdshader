shader_type spatial;
render_mode cull_back;
uniform float roll_phase = 0.0;
uniform float charge = 0.8;
uniform float wetness = 0.0;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
	float lower = 1.0-smoothstep(-0.5,0.3,VERTEX.y);
	VERTEX.x += sin(VERTEX.z*7.0-roll_phase*2.0)*0.045*lower;
	VERTEX.z += sin(VERTEX.y*5.0-roll_phase)*0.035*lower;
}
void fragment() {
	float folds = sin(local_position.y*32.0+sin(local_position.z*13.0)*0.7);
	float plates = smoothstep(0.74,0.90,folds);
	vec3 shell = mix(vec3(0.21,0.29,0.24),vec3(0.58,0.61,0.46),smoothstep(-0.2,1.2,local_position.y));
	ALBEDO = mix(shell,vec3(0.10,0.19,0.16),plates*0.65);
	ROUGHNESS = mix(0.58,0.22,wetness);
	METALLIC = 0.28;
	float fibers = smoothstep(0.97,0.995,sin(local_position.x*57.0+sin(local_position.y*9.0)));
	EMISSION = vec3(0.01,0.18,0.12)*fibers*plates*charge;
}

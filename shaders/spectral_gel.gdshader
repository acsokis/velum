shader_type spatial;
render_mode cull_disabled;
uniform sampler2D spectral_field : repeat_enable, filter_linear;
uniform bool discharges = true;
varying vec3 world_pos;
vec2 swirl(vec2 p) {
	p -= vec2(145.0,145.0);
	float radius = length(p);
	float angle = atan(p.y,p.x)+TIME*0.045+5.5*exp(-radius*0.018);
	return vec2(cos(angle),sin(angle))*radius/180.0;
}
void vertex() {
	world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y += (texture(spectral_field,swirl(world_pos.xz)).r-0.5)*8.0;
	vec2 vortex = world_pos.xz-vec2(145.0,145.0);
	VERTEX.y -= 18.0*exp(-dot(vortex,vortex)/1800.0);
}
void fragment() {
	vec2 q = swirl(world_pos.xz);
	float h = texture(spectral_field,q).r;
	float dx = texture(spectral_field,q+vec2(0.015,0.0)).r-h;
	float dz = texture(spectral_field,q+vec2(0.0,0.015)).r-h;
	NORMAL_MAP = normalize(vec3(-dx*4.0,-dz*4.0,1.0))*0.5+0.5;
	float veins = pow(max(0.0,1.0-abs(sin(q.x*27.0+q.y*13.0+h*12.0+sin(q.y*19.0)))),24.0);
	float pulse = smoothstep(0.92,0.99,sin(TIME*0.7+floor(q.x*5.0)*2.0+floor(q.y*5.0)));
	ALBEDO = mix(vec3(0.012,0.028,0.05),vec3(0.055,0.18,0.16),h);
	ROUGHNESS = 0.15;METALLIC = 0.38;
	EMISSION = vec3(0.11,0.48,0.62)*veins*(0.13+(discharges ? pulse*2.0 : 0.0));
}

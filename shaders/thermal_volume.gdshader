shader_type fog;
uniform float condensation = 0.02;
uniform vec4 wakes[12];
uniform vec4 flows[12];
uniform vec3 wind = vec3(0.0);
void fog() {
	vec3 p = WORLD_POSITION;
	float clearing = 0.0;
	for (int i=0;i<12;i++) {
		if (wakes[i].w < 0.005) { continue; }
		vec3 offset = p-wakes[i].xyz;
		if (dot(offset,offset) > 36.0) { continue; }
		float influence = exp(-dot(offset,offset)*0.25)*wakes[i].w;
		vec3 swirl = cross(vec3(0.0,1.0,0.0),offset);
		p -= (flows[i].xyz*0.3+swirl*0.55)*influence;
		clearing += influence*0.3;
	}
	p -= wind*TIME*0.3;
	float billow = 0.65+0.35*sin(p.x*2.2+TIME*0.65)*sin(p.z*1.8-p.y*2.0+TIME*0.8);
	vec3 q = UVW*2.0-1.0;
	float boundary = max(0.0,1.0-dot(q,q));
	DENSITY = condensation*boundary*billow*max(0.15,1.0-clearing);
	ALBEDO = vec3(0.53,0.64,0.59);
}

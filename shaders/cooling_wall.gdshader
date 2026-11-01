shader_type spatial;
varying vec3 world_pos;
varying vec3 world_normal;
varying float perimeter;
uniform vec2 procedural_offset = vec2(0.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float patches(vec2 p) {
	vec2 i = floor(p);vec2 f = fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	perimeter = step(98.0,max(abs(MODEL_MATRIX[3].x),abs(MODEL_MATRIX[3].z)));
}
void fragment() {
	float axis = abs(world_normal.x)>0.5 ? world_pos.z : world_pos.x;
	float strata = smoothstep(0.88,0.96,fract(world_pos.y*5.0));
	float panel = smoothstep(0.965,0.99,fract((axis+9.0)/3.0));
	float copper = smoothstep(0.90,0.98,sin(axis*1.0472+world_pos.y*0.12));
	vec3 resin = mix(vec3(0.025,0.065,0.055),vec3(0.10,0.15,0.12),fract(world_pos.y*0.625));
	ALBEDO = mix(resin,vec3(0.29,0.19,0.09),strata*0.8);
	ALBEDO = mix(ALBEDO,vec3(0.014,0.025,0.023),panel);
	ALBEDO += vec3(0.10,0.065,0.02)*copper*strata;
	float corrosion = smoothstep(0.54,0.77,patches(vec2(axis*0.35,world_pos.y*0.6)+procedural_offset));
	float pits = hash(floor(vec2(axis,world_pos.y)*32.0)+procedural_offset);
	ALBEDO = mix(ALBEDO,mix(vec3(0.26,0.13,0.045),vec3(0.08,0.23,0.16),pits),corrosion*0.85);
	ALBEDO *= 1.0-corrosion*step(0.93,pits)*0.7;
	ROUGHNESS = 0.55;
	METALLIC = 0.25+strata*0.35;
}

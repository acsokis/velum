shader_type spatial;
varying vec4 growth;
void vertex() {
	growth = INSTANCE_CUSTOM;
	VERTEX.y *= max(0.06,growth.x);
	VERTEX.xz *= 0.65+growth.x*0.35;
	VERTEX.x += sin(TIME*1.2+VERTEX.y*3.0+growth.z*6.0)*growth.y*VERTEX.y*0.06;
}
void fragment() {
	float flow = pow(0.5+0.5*sin(VERTEX.y*12.0-TIME*3.0),6.0)*growth.y;
	ALBEDO = mix(vec3(0.08,0.18,0.14),vec3(0.25,0.62,0.43),growth.x);
	ROUGHNESS = 0.48;METALLIC = 0.25;
	EMISSION = vec3(0.12,0.65,0.38)*flow*0.4;
}

varying vec3 sky_ray;
void vertex() {
	sky_ray = VERTEX;
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	POSITION.z = CLIP_SPACE_FAR*POSITION.w;
}
void fragment() {
	vec3 ray = normalize(sky_ray);
	ray.x += step(0.92,fract(ray.y*27.0+floor(TIME*5.0)*0.13))*signal_glitch*0.012;
	vec3 color = cable_canopy(ray);
	float angle = acos(clamp(dot(ray,SUN_DIR),-1.0,1.0));
	float core = 1.0-smoothstep(0.027,0.032,angle);
	float ring = 1.0-smoothstep(0.0011,0.0028,abs(angle-0.065));
	color += vec3(2.8,2.2,1.4)*core+vec3(0.12,1.0,0.78)*ring;
	if (ray.y > 0.025) {
		vec2 wind = vec2(TIME*0.014,-TIME*0.007)*cloud_speed;
		vec4 cloud = cloud_layer(ray,1.55,wind+vec2(4.0,9.0),0.94);
		color = mix(color,cloud.rgb,cloud.a);
	}
	ALBEDO = color;
}

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float aperture = 8.0;
uniform float focus_distance = 14.0;
uniform int sample_count = 15;
float distance_at(vec2 uv, mat4 inverse_projection) {
	float depth = texture(scene_depth,uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv,depth)*2.0-1.0;
#else
	vec3 ndc = vec3(uv*2.0-1.0,depth);
#endif
	vec4 p = inverse_projection*vec4(ndc,1.0);
	return -p.z/p.w;
}
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
	float depth = distance_at(SCREEN_UV,INV_PROJECTION_MATRIX);
	// Keep the handheld and nearby interactables sharp; far bokeh uses a triangular aperture.
	float radius = aperture*smoothstep(focus_distance,focus_distance+35.0,depth);
	vec3 total = texture(scene,SCREEN_UV).rgb;float weight = 1.0;
	if (radius > 0.2) {
		for (int i=0;i<15;i++) {
			if (i>=sample_count) break;
			float u = (float(i)+0.5)/float(sample_count);float v = fract(float(i)*0.618034+0.17);
			if (u+v>1.0) { u=1.0-u;v=1.0-v; }
			vec2 triangle = vec2(-0.866,0.5)*(1.0-u-v)+vec2(0.866,0.5)*u+vec2(0.0,-1.0)*v;
			vec2 uv = clamp(SCREEN_UV+triangle*radius/VIEWPORT_SIZE,vec2(0.001),vec2(0.999));
			float sample_depth = distance_at(uv,INV_PROJECTION_MATRIX);
			float valid = smoothstep(depth*0.55,depth*0.85,sample_depth);
			vec3 color = texture(scene,uv).rgb;float highlight = 1.0+min(max(color.r,max(color.g,color.b)),2.0)*0.35;
			total += color*valid*highlight;weight += valid*highlight;
		}
	}
	ALBEDO = total/weight;
}

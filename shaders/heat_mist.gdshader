shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float humidity = 0.3;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
	vec2 q = UV*2.0-1.0;
	float billow = 0.85+0.15*sin(UV.x*15.0+TIME*0.7)*sin(UV.y*13.0-TIME*0.4);
	float alpha = exp(-dot(q,q)*3.8)*billow;
	ALBEDO = vec3(0.60,0.70,0.65);
	ALPHA = alpha*humidity*0.12;
}

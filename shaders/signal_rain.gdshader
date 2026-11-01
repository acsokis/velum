shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
	vec2 cell = floor(UV*vec2(3.0,18.0));
	float digit = fract(sin(dot(cell,vec2(12.9898,78.233))+floor(TIME*3.0))*43758.5453);
	vec2 glyph = fract(UV*vec2(3.0,18.0));
	float ink = step(0.23,digit)*step(0.15,glyph.x)*step(glyph.x,0.85)*step(0.15,glyph.y)*step(glyph.y,0.85);
	ALBEDO = vec3(0.12,0.8,0.5);
	EMISSION = vec3(0.08,0.55,0.3);
	ALPHA = ink*strength*(1.0-UV.y)*0.7;
}

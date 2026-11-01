shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float surge_clock = 0.0;
uniform bool flashes = true;
varying vec4 cell;
void vertex() { cell = INSTANCE_CUSTOM; }
void fragment() {
	float pulse = 0.5+0.5*sin(surge_clock*2.5-cell.x*34.0);
	float tip = pow(max(0.0,1.0-abs(fract(UV.x*5.0+cell.x*9.0)-0.5)*2.0),5.0);
	float height = 0.12+tip*(0.25+pulse*0.55);
	float y = 1.0-UV.y;
	float edge = 1.0-smoothstep(0.01,0.035,abs(y-height));
	float stem = (1.0-smoothstep(height-0.02,height+0.02,y))*exp(-y*4.0)*0.25;
	ALBEDO = mix(vec3(0.12,0.85,1.05),vec3(0.7,1.6,1.2),pulse);
	ALPHA = clamp(edge*1.8+stem,0.0,1.0)*cell.y*(flashes ? 0.7+0.2*pulse : 0.4);
}

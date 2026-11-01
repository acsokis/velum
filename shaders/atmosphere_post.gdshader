shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float twilight = 0.0;
uniform float night = 0.0;
uniform float storm = 0.0;
uniform float glitch = 0.0;
uniform vec4 heat_spots[6];
void fragment() {
	vec2 uv = SCREEN_UV;
	float heat = 0.0;
	for (int i=0;i<6;i++) {
		float distance = length((uv-heat_spots[i].xy)*vec2(1.6,1.0));
		heat += (1.0-smoothstep(0.0,heat_spots[i].z,distance))*heat_spots[i].w;
	}
	uv.x += sin(uv.y*130.0+TIME*2.5)*heat*0.0012;
	float band = step(0.94,fract(uv.y*23.0+floor(TIME*5.0)*0.17));
	uv.x += band*glitch*0.0025;
	vec3 color = texture(screen_texture,uv).rgb;
	float split = 0.0004*storm;
	color.r = texture(screen_texture,uv+vec2(split,0)).r;
	color.b = texture(screen_texture,uv-vec2(split,0)).b;
	color *= mix(vec3(1.0),vec3(1.05,0.98,0.94),twilight*0.6);
	color *= mix(vec3(1.0),vec3(0.91,0.98,1.06),night*0.6);
	float vignette = smoothstep(0.25,0.78,length(SCREEN_UV-vec2(0.5)));
	color *= 1.0-vignette*0.15;
	COLOR = vec4(color,1.0);
}

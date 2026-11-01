shader_type spatial;
render_mode cull_back;

varying vec3 board_position;
varying vec2 board_uv;
varying float laminate_edge;
uniform vec2 board_offset = vec2(0.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0,0.0)),f.x),
		mix(hash21(i + vec2(0.0,1.0)),hash21(i + 1.0),f.x),f.y);
}

float line_mask(float distance, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(distance));
}

void vertex() {
	board_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	board_uv = board_position.xz;
	laminate_edge = 1.0-abs(NORMAL.y);
}

void fragment() {
	vec2 p = board_uv+board_offset;
	vec2 cell = floor(p / 14.0);
	vec2 uv = fract(p / 14.0);
	float aa = max(length(fwidth(p / 14.0)),0.0007);
	// Functional grooves are generated as connected geometry by signal_network.gd.
	// No decorative shader lanes are allowed to terminate in arbitrary cell boundaries.
	vec2 panel = abs(fract((p + 21.0) / 42.0) - 0.5);
	float panel_seam = smoothstep(0.489 - aa,0.496,panel.x) + smoothstep(0.489 - aa,0.496,panel.y);
	float dust = smoothstep(0.30,0.83,noise2(p * 0.12) * 0.7 + noise2(p * 0.65) * 0.3);
	float grain = hash21(floor(p * 24.0));
	float oxidation = noise2(p*0.25);
	float corrosion = smoothstep(0.58,0.79,oxidation);
	vec3 resin = mix(vec3(0.018,0.052,0.041),vec3(0.044,0.10,0.078),oxidation);
	if (board_position.x < 0.0) resin *= vec3(1.20,1.04,0.86);
	vec3 color = resin*(0.96+grain*0.08);
	color = mix(color,vec3(0.15,0.13,0.09),dust * 0.48);
	color = mix(color,mix(vec3(0.19,0.105,0.035),vec3(0.075,0.25,0.16),grain),corrosion*0.8);
	color *= 1.0-corrosion*step(0.91,grain)*0.65;
	color = mix(color,vec3(0.007,0.014,0.011),clamp(panel_seam * 0.7,0.0,1.0));
	// Sparse worn silkscreen corners; not texture-baked lettering.
	float ink = line_mask(uv.x - 0.62,0.002,aa) * step(0.66,uv.y) * step(uv.y,0.85);
	ink += line_mask(uv.y - 0.85,0.002,aa) * step(0.62,uv.x) * step(uv.x,0.88);
	color = mix(color,vec3(0.39,0.43,0.31),clamp(ink,0.0,1.0) * (1.0 - dust * 0.7));
	float copper_layer = smoothstep(0.80,0.86,fract(board_position.y*10.0));
	vec3 strata = mix(vec3(0.14,0.105,0.055),vec3(0.43,0.26,0.10),copper_layer);
	ALBEDO = mix(color,strata,laminate_edge);
	ROUGHNESS = 0.86;
	METALLIC = laminate_edge*0.25;
}

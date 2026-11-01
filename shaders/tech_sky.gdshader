shader_type sky;
render_mode use_half_res_pass, disable_fog;

// Abstract overhead cable ecology: suspended bundles, combs and connector nodes in machine mist.
uniform float cloud_speed : hint_range(0.0, 2.0) = 1.0;
uniform bool web_profile = false;
uniform float signal_storm = 0.0;
uniform float signal_glitch = 0.0;
uniform vec3 cloud_origin = vec3(0.0,2.0,0.0);
uniform float cloud_altitude = 35.0;
uniform float cloud_clock = 0.0;
uniform float cloud_weather = 0.0;
uniform float cloud_amount = 0.18;
uniform vec2 wind_offset = vec2(0.0);
uniform float daylight = 1.0;
uniform vec2 procedural_offset = vec2(0.0);
uniform sampler2D spectral_field : repeat_enable, filter_linear;
uniform sampler2D spectral_previous : repeat_enable, filter_linear;
uniform float spectral_blend = 1.0;
uniform bool spectral_enabled = false;
uniform vec3 zenith_color : source_color = vec3(0.025, 0.032, 0.027);
uniform vec3 horizon_color : source_color = vec3(0.23, 0.21, 0.15);
uniform vec3 SUN_DIR = vec3(-0.460, 0.374, -0.805);

float hash21(vec2 p) {
	p += procedural_offset;
	vec3 h = fract(vec3(p.xyx) * 0.1031);
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float n = 0.0;
	float weight = 0.55;
	for (int i = 0; i < 4; i++) {
		n += value_noise(p) * weight;
		p = mat2(vec2(1.76, 1.08), vec2(-1.08, 1.76)) * p + vec2(8.1, 2.3);
		weight *= 0.48;
	}
	return n;
}

vec3 atmosphere(vec3 ray) {
	float up = max(ray.y, 0.0);
	vec3 color = mix(horizon_color, zenith_color, pow(up, 0.40));
	color += vec3(0.07, 0.09, 0.055) * exp(-abs(ray.y - 0.10) * 9.0);
	float sun = max(dot(ray, SUN_DIR), 0.0);
	color += vec3(0.65, 0.38, 0.14) * pow(sun, 22.0) * 0.23;
	// Infinite, deliberately low-detail underworld horizon matches the local FFT surface.
	vec3 haze = mix(vec3(0.012,0.028,0.05),vec3(0.055,0.18,0.16),0.5);
	return mix(haze, color, smoothstep(-0.04, 0.01, ray.y));
}

vec4 cable_layer(vec3 ray,float altitude,float angle,vec2 offset,float layer_id) {
	vec2 p = ray.xz/max(ray.y+0.18,0.14)*altitude;
	p = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*p+offset;
	float curve = sin(p.x*0.65+offset.x)*0.48+sin(p.x*0.21)*0.55;
	float band_id = floor((p.y-curve+2.0)/4.0);
	float y = mod(p.y-curve+2.0,4.0)-2.0;
	float mask = 1.0-smoothstep(0.27,0.31,abs(y));
	float strand = fract((y+0.32)*15.0);
	float cylinder = pow(max(sin(strand*PI),0.0),0.65);
	float choice = hash21(vec2(band_id,floor((y+0.32)*15.0))+offset);
	vec3 jacket = mix(vec3(0.055,0.085,0.075),vec3(0.30,0.19,0.075),step(0.62,choice));
	jacket = mix(jacket,vec3(0.13,0.15,0.25),step(0.88,choice));
	jacket *= (0.40+cylinder*0.90)*(0.18+daylight*0.82);
	float tie = smoothstep(0.91,0.94,fract(p.x*0.43+band_id*0.2));
	jacket = mix(jacket,vec3(0.12,0.17,0.14),tie*0.86);
	// One selected strand in one selected bundle/layer, then a quiet interval.
	float epoch = floor(TIME/12.0);
	float phase = mod(TIME,12.0);
	float selected_layer = floor(hash21(vec2(epoch,7.0))*3.0);
	float selected_band = floor(hash21(vec2(epoch,17.0))*5.0)-2.0;
	float selected_strand = floor(hash21(vec2(epoch,31.0))*9.0);
	float selected = (1.0-step(0.1,abs(layer_id-selected_layer)))*(1.0-step(0.1,abs(band_id-selected_band)))*(1.0-step(0.1,abs(floor((y+0.32)*15.0)-selected_strand)));
	float pulse = exp(-pow((p.x-(-18.0+phase*12.0))*1.8,2.0))*step(phase,3.0);
	jacket += vec3(0.2,2.8,1.9)*pulse*selected*cylinder;
	vec2 node_uv = vec2(mod(p.x+3.0,6.0)-3.0,y);
	float socket = 1.0-smoothstep(0.36,0.40,length(node_uv));
	float rim = 1.0-smoothstep(0.012,0.028,abs(length(node_uv)-0.32));
	float node_enabled = step(0.64,hash21(vec2(floor((p.x+3.0)/6.0),band_id)+offset));
	jacket = mix(jacket,vec3(0.065,0.10,0.105)+vec3(0.08,0.35,0.28)*rim,socket*node_enabled);
	mask = max(mask,socket*node_enabled);
	return vec4(jacket,mask*smoothstep(-0.08,0.16,ray.y));
}

vec3 cable_canopy(vec3 ray) {
	vec3 color = atmosphere(ray);
	vec4 far = cable_layer(ray,2.7,-0.74,vec2(13.0,4.0),0.0);
	vec4 middle = cable_layer(ray,1.6,0.58,vec2(2.0,8.0),1.0);
	vec4 near = cable_layer(ray,0.90,1.78,vec2(0.0,1.0),2.0);
	color = mix(color,far.rgb*0.65+atmosphere(ray)*0.35,far.a);
	color = mix(color,middle.rgb*0.82+atmosphere(ray)*0.18,middle.a);
	return mix(color,near.rgb,near.a);
}

vec4 cloud_layer(vec3 ray, float altitude, vec2 wind, float opacity) {
	vec2 p = ray.xz / max(ray.y, 0.055) * altitude + wind;
	float broad = fbm(p * 0.37 + vec2(71.4, 21.9));
	float curl = fbm(p * 0.82 + broad * 2.2);
	float coverage = smoothstep(0.40, 0.59, fbm(p * 0.13 + vec2(19.5, 51.0)));
	float density = smoothstep(0.46, 0.70, broad * 0.73 + curl * 0.35) * coverage;
	// This lower cloud field is shared analytically with the rain emitter on the CPU.
	if (altitude < 2.0) {
		vec2 world = cloud_origin.xz+ray.xz/max(ray.y,0.055)*max(1.0,cloud_altitude-cloud_origin.y);
		vec2 q = world+wind_offset+procedural_offset;
		float field = 0.5+sin(q.x*0.055)*0.23+sin(q.y*0.043)*0.20+sin((q.x+q.y)*0.031)*0.10+cloud_weather*0.12;
		float cover = smoothstep(0.50,0.73,field)*max(cloud_amount,cloud_weather);
		density = cover*(0.72+0.28*density);
	}
	else { density *= cloud_amount; }
	// Quantized cells make the condensation feel assembled, not a painted cloud texture.
	vec2 tile = p * 13.0;
	vec2 cell = floor(tile);
	vec2 uv = fract(tile);
	float edge_distance = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float seam = 1.0 - smoothstep(0.012, 0.052, edge_distance);
	float tile_height = hash21(cell + vec2(17.0, 44.0));
	float micro = mix(0.96, 1.04, tile_height);
	density *= mix(micro, micro * 0.78, seam);
	float light = clamp((fbm((p + vec2(-0.22, -0.12)) * 0.37 + vec2(71.4, 21.9)) - broad) * 6.0 + 0.53, 0.0, 1.0);
	vec3 shade = mix(vec3(0.09, 0.095, 0.065), vec3(0.30, 0.28, 0.19), light);
	shade *= mix(0.86, 1.10, tile_height);
	shade *= 0.12+daylight*0.88;
	float conductor = seam * step(0.88, tile_height) * smoothstep(0.12, 0.50, density);
	float pulse = 0.65 + 0.35 * sin(TIME * 0.45 + tile_height * 40.0);
	shade += vec3(0.10, 0.75, 0.65) * conductor * pulse * 0.9;
	// Glitch fragments are part of the condensation, never a separate sky overlay.
	float glitch_cell = step(0.80,hash21(cell+floor(cloud_clock*7.0)));
	float glitch_line = step(0.75,fract(tile.y*0.25+floor(cloud_clock*11.0)*0.17));
	float glitch = glitch_cell*glitch_line*signal_glitch;
	shade += vec3(0.12,0.85,0.65)*(glitch+signal_storm*0.35);
	density *= 1.0-glitch*0.7;
	if (spectral_enabled) {
		float wave = mix(texture(spectral_previous,p*0.05).r,texture(spectral_field,p*0.05).r,spectral_blend);
		shade *= 0.92+wave*0.16;
	}
	float fade = smoothstep(0.025, 0.17, ray.y);
	return vec4(shade, clamp(density * opacity * fade, 0.0, 0.93));
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		// Animated reflections stay inexpensive: clouds are evaluated in the half-res background.
		COLOR = atmosphere(ray);
	} else if (AT_HALF_RES_PASS) {
		if (ray.y > 0.025) {
			vec2 wind = wind_offset*0.025*cloud_speed;
			vec4 high = cloud_layer(ray, 3.4, wind * 0.42 + vec2(37.0, 11.0), 0.72);
			vec4 low = cloud_layer(ray, 1.55, wind + vec2(4.0, 9.0), 0.94);
			float alpha = low.a + high.a * (1.0 - low.a);
			COLOR = (low.rgb * low.a + high.rgb * high.a * (1.0 - low.a)) / max(alpha, 0.001);
			ALPHA = alpha;
		} else {
			COLOR = vec3(0.0);
			ALPHA = 0.0;
		}
	} else {
		vec3 color = cable_canopy(ray);
		// A distant abstract power node, suspended among the cable canopy.
		float angle = acos(clamp(dot(ray, SUN_DIR), -1.0, 1.0));
		float core = 1.0 - smoothstep(0.027, 0.032, angle);
		float ring = (1.0 - smoothstep(0.0011, 0.0028, abs(angle - 0.065)));
		float outer_ring = (1.0 - smoothstep(0.0005, 0.0015, abs(angle - 0.078)));
		color += vec3(2.8, 2.2, 1.4) * core;
		color += vec3(0.12, 1.0, 0.78) * ring * 1.3;
		color += vec3(0.13, 0.32, 0.35) * outer_ring;
		// Remote backplane indicator lights, not astronomical stars.
		vec2 star_uv = vec2(atan(ray.x, ray.z), asin(clamp(ray.y, -1.0, 1.0))) * 170.0;
		vec2 star_cell = floor(star_uv);
		vec2 center = vec2(hash21(star_cell), hash21(star_cell + 13.3));
		float star = (1.0 - smoothstep(0.015, 0.09, length(fract(star_uv) - center))) * step(0.988, hash21(star_cell + 29.0));
		color += vec3(0.15, 0.30, 0.12) * star * smoothstep(0.2, 0.7, ray.y) * 0.2;
		if (web_profile && ray.y > 0.025) {
			vec2 wind = wind_offset*0.025*cloud_speed;
			vec4 cloud = cloud_layer(ray, 1.55, wind + vec2(4.0, 9.0), 0.94);
			COLOR = mix(color, cloud.rgb, cloud.a);
		} else {
			COLOR = mix(color, HALF_RES_COLOR.rgb, HALF_RES_COLOR.a);
		}
	}
}

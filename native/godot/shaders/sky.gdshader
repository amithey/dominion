// The sky: a clear gradient, a sun with a soft halo, haze at the horizon and drifting
// clouds (fair-weather cumulus below, thin high cloud above). Clouds are lit from the
// sun's side and dark underneath, so the sky has depth. No TIME: the drift is a uniform
// the game moves slowly (world.gd), so the sky's light is not re-rendered every frame.
shader_type sky;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 zenith : source_color = vec3(0.07, 0.25, 0.62);
uniform vec3 horizon : source_color = vec3(0.70, 0.82, 0.94);
uniform vec3 ground : source_color = vec3(0.55, 0.62, 0.66);
uniform float cloud_amount = 0.62;     // 0 clear .. 1 overcast
uniform vec2 drift = vec2(0.0, 0.0);
uniform float energy = 1.15;

float fbm(vec2 p) {
	float v = texture(noise_tex, p).r * 0.55;
	v += texture(noise_tex, p * 2.1 + 0.37).r * 0.30;
	v += texture(noise_tex, p * 4.3 + 0.71).r * 0.15;
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, -1.0, 1.0);
	// Gradient: deep blue overhead, pale at the horizon, a hazy band just above it.
	vec3 col = mix(horizon, zenith, pow(clamp(up, 0.0, 1.0), 0.42));
	if (up < 0.0) { col = mix(horizon, ground, clamp(-up * 3.0, 0.0, 1.0)); }
	// Sun: disc, halo and the warm glow of the lower sky around it.
	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	float s = max(dot(dir, sun_dir), 0.0);
	vec3 sun_col = LIGHT0_COLOR;
	col += sun_col * (pow(s, 600.0) * 6.0 + pow(s, 28.0) * 0.28 + pow(s, 6.0) * 0.09) * LIGHT0_ENERGY * 0.55;
	if (up > -0.02) {
		// Clouds on a plane overhead: dense low cumulus (thicker near the horizon, where it is seen edge-on) and a thin high veil.
		float t = 1.0 / (up + 0.18);
		vec2 p = dir.xz * t * 0.20 + drift;
		float low = fbm(p);
		float cover = 1.0 - cloud_amount;
		float dense = smoothstep(0.34 + cover * 0.2, 0.52 + cover * 0.2, low);
		// Lit side: sample the field a little toward the sun, the difference is the shading.
		vec2 toward = normalize(sun_dir.xz + vec2(0.0001)) * 0.03;
		float lit = fbm(p + toward);
		float shade = clamp(0.5 + (low - lit) * 9.0, 0.0, 1.0);
		vec3 cloud_col = mix(vec3(0.56, 0.63, 0.77), vec3(1.08, 1.04, 0.98), shade) * (0.78 + 0.35 * s);
		cloud_col = mix(cloud_col, sun_col * 1.1, pow(s, 12.0) * 0.45 * (1.0 - dense * 0.4));
		float veil = smoothstep(0.50, 0.75, fbm(dir.xz * (1.0 / (up + 0.30)) * 0.09 + drift * 0.5 + 3.1)) * 0.3;
		float fade = smoothstep(-0.02, 0.22, up);   // clouds melt into the haze at the horizon
		col = mix(col, vec3(0.95, 0.97, 1.0), veil * fade);
		col = mix(col, cloud_col, dense * fade * 0.97);
	}
	COLOR = col * energy;
}

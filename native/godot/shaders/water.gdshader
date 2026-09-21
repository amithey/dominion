// Sea surface. Requires the Forward+ renderer (screen and depth textures).
// - Gerstner swell moves the vertices; fine ripples perturb the normal.
// - Colour comes from how much water the view ray crosses: the seabed shows
//   through turquoise shallows and fades into deep blue offshore.
// - The scene behind the surface is refracted, the sky is reflected through
//   the regular specular path (Fresnel), and foam gathers along the shore.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.52, 0.50);
uniform vec3 deep_color : source_color = vec3(0.012, 0.075, 0.13);
uniform float clarity = 0.16;          // how quickly colour saturates with depth
uniform float swell = 0.32;            // wave height in metres
uniform float foam_width = 0.4;

varying vec3 world_pos;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

// Seamless noise texture: hash noise was blocky at sea-scale coordinates.
float noise(vec2 p) { return texture(noise_tex, p).r; }
// Two ripple layers drifting in different directions.
float ripples(vec2 p, float t) {
	return noise(p * 0.011 + vec2(t * 0.006, t * 0.0025)) * 0.6
		+ noise(p * 0.029 - vec2(t * 0.004, t * 0.009)) * 0.4;
}

vec3 gerstner(vec2 p, vec2 dir, float wavelength, float steep, float t) {
	float k = 6.28318 / wavelength;
	float c = sqrt(9.8 / k);
	float f = k * (dot(normalize(dir), p) - c * t * 0.35);
	float a = steep / k;
	return vec3(normalize(dir).x * a * cos(f), a * sin(f), normalize(dir).y * a * cos(f));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 d = gerstner(w.xz, vec2(1.0, 0.35), 38.0, 0.16, TIME)
		+ gerstner(w.xz, vec2(-0.4, 1.0), 23.0, 0.12, TIME)
		+ gerstner(w.xz, vec2(0.7, -0.8), 13.0, 0.08, TIME);
	VERTEX += d * (swell / 0.32);
	world_pos = w + d;
}

void fragment() {
	// Ripple normal from the gradient of an animated noise field.
	float e = 0.6;
	float h0 = ripples(world_pos.xz, TIME);
	float hx = ripples(world_pos.xz + vec2(e, 0.0), TIME);
	float hz = ripples(world_pos.xz + vec2(0.0, e), TIME);
	vec3 wn = normalize(vec3((h0 - hx) * 1.4, e, (h0 - hz) * 1.4));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Vertical water depth below this pixel, from the scene depth buffer.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	float depth = max(world_pos.y - floor_world.y, 0.0);
	float path = max(length(view.xyz) - length(VERTEX), 0.0);

	// Refract the seabed, less so in very shallow water.
	vec2 offset = wn.xz * 0.035 * clamp(depth * 0.5, 0.0, 1.0);
	float raw_off = texture(depth_tex, SCREEN_UV + offset).r;
	vec4 view_off = INV_PROJECTION_MATRIX * vec4((SCREEN_UV + offset) * 2.0 - 1.0, raw_off, 1.0);
	if (-view_off.z / view_off.w < -VERTEX.z) offset = vec2(0.0); // don't refract things above water
	vec3 behind = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;

	float absorb = 1.0 - exp(-path * clarity);
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, 1.0 - exp(-depth * 0.09)));
	vec3 seen = mix(behind * mix(vec3(1.0), shallow_color * 1.6, 0.55), water, absorb);

	// Shore foam: a thin broken line at the waterline with lacy streaks behind it.
	float band = 1.0 - smoothstep(0.0, foam_width, depth);
	float lace = noise(world_pos.xz * 0.05 + vec2(TIME * 0.01, 0.0));
	float foam = smoothstep(0.5, 0.75, lace + band * 0.45) * band;
	foam = clamp(foam + pow(band, 6.0) * 0.8, 0.0, 1.0) * 0.85;

	ALBEDO = vec3(0.92, 0.95, 0.95) * foam;
	EMISSION = seen * (1.0 - foam);
	ROUGHNESS = mix(0.035, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.55;
	ALPHA = 1.0;
}

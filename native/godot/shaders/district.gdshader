// Ground of one hex district, Civilization-style: each building owns a whole
// hex whose surface says what it is without harsh white slabs.
//   0 civic plaza   warm stone courtyard pavers around the core fading into lawn
//   1 residential   lush mown green lawn, garden path and clipped dark hedge
//   2 industrial    dark charcoal weathered tarmac/concrete with subtle amber bay line
//   3 farm          rich dark ploughed soil and green/golden crop rows
//   4 military      dark olive-khaki tactical tarmac with subtle bay markings
// Streets run from connected hex edges (6-bit mask, bit k = direction k*60 deg)
// into a perimeter loop around the central building, joining neighbouring districts
// into a cohesive dark-asphalt street grid.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D paving_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
global uniform float winter;
uniform float hex_radius = 12.0;
uniform float core = 5.0;
instance uniform int style = 0;
instance uniform int streets = 0;
instance uniform float seed = 0.0;
instance uniform float solid = 0.0;

varying vec2 local;
varying vec3 world_pos;

void vertex() {
	local = VERTEX.xz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float noise(vec2 p) { return texture(noise_tex, p).r; }
float luma(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }
vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

void fragment() {
	vec2 p = local;
	float apothem = hex_radius * 0.8660254;
	float edge = 0.0;
	for (int k = 0; k < 6; k++) {
		float a = float(k) * 1.0471976;
		edge = max(edge, dot(p, vec2(cos(a), sin(a))));
	}
	float to_rim = apothem - edge;
	float rad = length(p);
	vec2 w = world_pos.xz;
	float stain = noise(w * 0.05 + seed);
	float grain = noise(w * 0.8 + seed * 1.7);
	vec3 meadow = texture(grass_tex, w * 0.16).rgb * vec3(0.80, 0.90, 0.68) * mix(0.90, 1.04, stain);
	vec3 stone = texture(paving_tex, w * 0.25).rgb;
	vec3 col;
	float rough = 0.90;

	if (style == 0) {
		// Civic / Research: warm medium-dark courtyard flagstones fading into manicured park lawn.
		vec2 q = w / vec2(1.5, 0.75);
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		vec2 cell = fract(q) - 0.5;
		float joint = smoothstep(0.47, 0.43, max(abs(cell.x), abs(cell.y)));
		float tone = noise(floor(q) * 0.37 + seed);
		col = mix(srgb(vec3(0.40, 0.37, 0.33)), srgb(vec3(0.50, 0.46, 0.40)), tone) * mix(0.90, 1.04, luma(stone));
		col *= mix(0.74, 1.0, joint);
		float wobble = (noise(w * 0.09 + seed * 2.3) - 0.5) * 1.8;
		float green = smoothstep(core + 1.4, core + 3.6, rad + wobble) * (1.0 - solid);
		float mown = step(0.5, fract(dot(w, vec2(0.6, 0.8)) / 3.0));
		vec3 lawn = meadow * vec3(0.88, 1.02, 0.84) * mix(0.95, 1.05, mown);
		col = mix(col, lawn, green);
		rough = mix(0.82, 0.92, green);
	} else if (style == 1) {
		// Residential: lush mown green garden turf, flower beds, and warm stone footpath.
		float ang = seed * 1.7;
		float stripe = step(0.5, fract(dot(w, vec2(cos(ang), sin(ang))) / 3.2));
		col = meadow * vec3(0.88, 1.04, 0.82) * mix(0.94, 1.06, stripe);
		float bed = smoothstep(0.67, 0.71, noise(w * 0.22 + seed * 3.1)) * step(core + 0.8, rad) * step(1.5, to_rim);
		vec3 flowers = mix(srgb(vec3(0.68, 0.28, 0.36)), srgb(vec3(0.78, 0.66, 0.26)), step(0.5, noise(w * 1.3 + seed)));
		flowers = mix(texture(dirt_tex, w * 0.4).rgb * 0.48, flowers, step(0.55, grain) * 0.80);
		col = mix(col, flowers, bed);
		rough = 0.92;
	} else if (style == 2) {
		// Industrial & Energy: dark charcoal weathered asphalt/concrete so structures & unit badges pop.
		vec2 slab = abs(fract(w / 4.0) - 0.5);
		col = srgb(vec3(0.24, 0.25, 0.265)) * mix(0.90, 1.08, luma(stone));
		col *= mix(0.72, 1.0, smoothstep(0.495, 0.482, max(slab.x, slab.y)));
		col *= mix(1.0, 0.72, smoothstep(0.60, 0.82, stain));
		// Subtle muted amber safety line inside the work apron.
		float safety = (1.0 - smoothstep(0.06, 0.13, abs(to_rim - 1.9))) * (1.0 - solid * 0.5);
		col = mix(col, srgb(vec3(0.68, 0.52, 0.14)), safety * 0.65);
		float wobble = (noise(w * 0.11 + seed * 1.9) - 0.5) * 1.4;
		float verge = smoothstep(1.6, 0.2, to_rim + wobble * 0.5) * (1.0 - solid);
		col = mix(col, meadow * 0.92, verge);
		rough = mix(0.86, 0.92, verge);
	} else if (style == 3) {
		// Farm: rich dark ploughed soil and vibrant green/golden crop rows, soft meadow rim.
		float ang = seed * 2.3 + 0.4;
		vec2 dir = vec2(cos(ang), sin(ang));
		float row = sin(dot(p, vec2(-dir.y, dir.x)) * 3.8);
		vec3 soil = texture(dirt_tex, w * 0.28).rgb * vec3(0.52, 0.44, 0.34);
		vec3 crop = mix(srgb(vec3(0.26, 0.42, 0.12)), srgb(vec3(0.62, 0.52, 0.18)), smoothstep(0.32, 0.72, noise(w * 0.035 + seed)));
		col = mix(soil, crop, smoothstep(-0.15, 0.35, row));
		float margin = smoothstep(1.3, 0.1, to_rim);
		col = mix(col, meadow * 0.95, margin);
		rough = 0.95;
	} else {
		// Military: dark olive-drab / tactical tarmac with subtle bay markings and natural scrub verge.
		col = srgb(vec3(0.26, 0.28, 0.23)) * mix(0.92, 1.06, luma(stone));
		vec2 slab = abs(fract(w / 5.0) - 0.5);
		col *= mix(0.80, 1.0, smoothstep(0.496, 0.486, max(slab.x, slab.y)));
		float bay = step(0.93, fract(p.x / 3.2)) * step(abs(p.y), 3.5) * step(core + 0.5, rad);
		col = mix(col, srgb(vec3(0.58, 0.56, 0.44)), bay * 0.55);
		float verge = smoothstep(1.5, 0.15, to_rim) * (1.0 - solid);
		col = mix(col, meadow * 0.90, verge);
		rough = 0.90;
	}

	// Connecting city streets: dark asphalt avenues from connected neighbour edges right up to the building courtyard.
	float road = 0.0;
	float kerb = 0.0;
	float walk = 0.0;
	float dash = 0.0;
	float half_w = (style == 1) ? 1.05 : 1.32;
	for (int k = 0; k < 6; k++) {
		if ((streets & (1 << k)) == 0) continue;
		float a = float(k) * 1.0471976;
		vec2 n = vec2(cos(a), sin(a));
		float along = dot(p, n);
		if (along < 3.6) continue;
		float fade_in = smoothstep(3.6, 5.0, along);
		float across = abs(dot(p, vec2(-n.y, n.x)));
		road = max(road, (1.0 - smoothstep(half_w, half_w + 0.14, across)) * fade_in);
		kerb = max(kerb, (1.0 - smoothstep(half_w + 0.24, half_w + 0.34, across)) * smoothstep(half_w, half_w + 0.14, across) * fade_in);
		walk = max(walk, (1.0 - smoothstep(half_w + 0.85, half_w + 1.00, across)) * smoothstep(half_w + 0.24, half_w + 0.34, across) * fade_in);
		if (style != 1) {
			dash = max(dash, (1.0 - smoothstep(0.045, 0.085, across)) * step(0.55, fract(along / 2.2)) * smoothstep(5.4, 6.2, along));
		}
	}
	if (style == 3) {
		vec3 track = texture(dirt_tex, w * 0.35).rgb * 0.56;
		col = mix(col, track, road);
	} else if (streets != 0) {
		vec3 asphalt = srgb(vec3(0.165, 0.17, 0.18)) * mix(0.90, 1.10, grain) * mix(0.94, 1.04, stain);
		asphalt = mix(asphalt, srgb(vec3(0.52, 0.50, 0.44)), dash * 0.55);
		col = mix(col, srgb(vec3(0.38, 0.37, 0.34)) * mix(0.92, 1.04, grain), walk * (style == 1 ? 0.72 : 0.50));
		col = mix(col, srgb(vec3(0.44, 0.42, 0.39)), kerb * 0.85);
		col = mix(col, asphalt, road);
		rough = mix(rough, 0.92, road);
	}

	float open = max(road, walk);
	if (style == 1) {
		float hedge = (1.0 - smoothstep(0.35, 0.58, abs(to_rim - 2.3))) * (1.0 - open);
		col = mix(col, srgb(vec3(0.13, 0.24, 0.09)) * mix(0.82, 1.18, grain), hedge * 0.92);
	}
	// Grounded ambient contact shadow beneath the central building footprint.
	float footprint = max(abs(p.x), abs(p.y));
	col *= mix(1.0, 0.74, (1.0 - smoothstep(core * 0.42, core * 0.42 + 1.8, footprint)) * (1.0 - open));
	if (solid > 0.5) {
		float kerb_band = 1.0 - smoothstep(0.35, 0.46, to_rim);
		col = mix(col, srgb(vec3(0.36, 0.36, 0.35)) * mix(0.95, 1.05, grain), kerb_band * (1.0 - open) * 0.8);
	}
	// Green boulevard verge around each district lot so adjacent buildings read clearly apart.
	col = mix(col, meadow * 0.94, smoothstep(2.6, 0.8, to_rim) * (1.0 - open) * (1.0 - solid));
	if (winter > 0.0) {
		float drift = smoothstep(0.25, 0.7, grain + winter * 0.6);
		col = mix(col, vec3(0.70, 0.74, 0.80), winter * drift * (1.0 - road * 0.8) * 0.9);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}

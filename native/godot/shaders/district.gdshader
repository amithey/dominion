// Ground of one hex district, Civilization-style: each building owns a whole
// hex whose surface says what it is.
//   0 civic plaza   light stone pavers laid in courses, a stone kerb at the edge
//   1 residential   a mown lawn in stripes, flower beds, a stone garden path
//                   round the houses and a clipped hedge along the edge
//   2 industrial    poured concrete slabs with joints, oil stains and a yellow
//                   safety line inside the edge
//   3 farm          ploughed crop rows; farm tracks instead of asphalt
//   4 military      khaki gravel with painted parking bays
// Streets run from the middle to every connected neighbour (6-bit mask, bit k
// = direction k*60 deg) as dark asphalt with pale kerb stones and pavements, and
// they run on across the edge of the tile, so neighbouring districts join into
// one street instead of each tile ending in a hard frame. Coordinates are
// local to the hex centre.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;  // the skirt is seen from both sides

uniform sampler2D paving_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float hex_radius = 12.0;
uniform float core = 5.0;            // the central building's footprint
instance uniform int style = 0;
instance uniform int streets = 0;
instance uniform float seed = 0.0;

varying vec2 local;
varying vec3 world_pos;

void vertex() {
	local = VERTEX.xz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float noise(vec2 p) { return texture(noise_tex, p).r; }
float luma(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }
// Colours below are chosen as sRGB (as a paint picker shows them); ALBEDO is linear.
vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

void fragment() {
	vec2 p = local;
	float apothem = hex_radius * 0.8660254;
	// Distance to the hex boundary along the six edge normals (k * 60 deg).
	float edge = 0.0;
	for (int k = 0; k < 6; k++) {
		float a = float(k) * 1.0471976;
		edge = max(edge, dot(p, vec2(cos(a), sin(a))));
	}
	float to_rim = apothem - edge;            // metres to the edge of the tile
	vec2 w = world_pos.xz;
	float stain = noise(w * 0.05 + seed);
	float grain = noise(w * 0.8 + seed * 1.7);
	// The same meadow as the terrain around it (terrain.gdshader tints its grass the same way).
	vec3 meadow = texture(grass_tex, w * 0.16).rgb * vec3(0.82, 0.9, 0.7) * mix(0.9, 1.04, stain);
	vec3 stone = texture(paving_tex, w * 0.25).rgb;
	vec3 col;
	float rough = 0.9;

	if (style == 0) {
		// Pavers in courses, each course offset by half a stone.
		vec2 q = w / vec2(1.6, 0.8);
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		vec2 cell = fract(q) - 0.5;
		float joint = smoothstep(0.47, 0.44, max(abs(cell.x) * 1.0, abs(cell.y) * 1.0));
		float tone = noise(floor(q) * 0.37 + seed);
		col = mix(srgb(vec3(0.56, 0.53, 0.48)), srgb(vec3(0.7, 0.66, 0.58)), tone) * mix(0.9, 1.05, luma(stone));
		col *= mix(0.72, 1.0, joint);
		rough = 0.78;
	} else if (style == 1) {
		// A mown lawn: broad stripes where the mower went up and back.
		float ang = seed * 1.7;
		float stripe = step(0.5, fract(dot(w, vec2(cos(ang), sin(ang))) / 3.2));
		col = meadow * mix(0.94, 1.07, stripe);
		// Flower beds: small clusters of colour near the houses.
		float bed = smoothstep(0.66, 0.7, noise(w * 0.22 + seed * 3.1)) * step(core + 0.8, length(p)) * step(1.2, to_rim);
		vec3 flowers = mix(srgb(vec3(0.78, 0.32, 0.42)), srgb(vec3(0.9, 0.78, 0.3)), step(0.5, noise(w * 1.3 + seed)));
		flowers = mix(texture(dirt_tex, w * 0.4).rgb * 0.55, flowers, step(0.55, grain) * 0.85);
		col = mix(col, flowers, bed);
		// A stone garden path round the houses.
		float ring = abs(length(p) - (core + 1.6));
		col = mix(col, srgb(vec3(0.62, 0.55, 0.44)) * mix(0.88, 1.06, grain), 1.0 - smoothstep(0.32, 0.42, ring));
	} else if (style == 2) {
		// Poured slabs, 4 m, with dark joints and oil and rust stains.
		vec2 slab = abs(fract(w / 4.0) - 0.5);
		col = srgb(vec3(0.6, 0.6, 0.58)) * mix(0.9, 1.06, luma(stone));
		col *= mix(0.62, 1.0, smoothstep(0.495, 0.485, max(slab.x, slab.y)));
		col *= mix(1.0, 0.6, smoothstep(0.62, 0.8, stain));
		// A yellow safety line a metre inside the edge.
		col = mix(col, srgb(vec3(0.86, 0.7, 0.18)), (1.0 - smoothstep(0.08, 0.14, abs(to_rim - 1.0))) * 0.9);
		rough = 0.72;
	} else if (style == 3) {
		// Crop rows running across the hex at a per-farm angle.
		float ang = seed * 2.3;
		vec2 dir = vec2(cos(ang), sin(ang));
		float row = sin(dot(p, vec2(-dir.y, dir.x)) * 3.4);
		vec3 soil = texture(dirt_tex, w * 0.25).rgb * 0.78;
		vec3 crop = mix(srgb(vec3(0.33, 0.42, 0.13)), srgb(vec3(0.62, 0.55, 0.22)), smoothstep(0.35, 0.75, noise(w * 0.03 + seed)));
		col = mix(soil, crop, smoothstep(-0.1, 0.35, row));
	} else {
		// Khaki gravel with painted bays near the core.
		// Maintained concrete apron: quiet broad slabs, not speckled bare soil.
		col = srgb(vec3(0.48, 0.51, 0.49)) * mix(0.96, 1.03, luma(stone));
		vec2 slab = abs(fract(w / 5.0) - 0.5);
		col *= mix(0.82, 1.0, smoothstep(0.496, 0.488, max(slab.x, slab.y)));
		float bay = step(0.93, fract(p.x / 3.2)) * step(abs(p.y), 3.5) * step(core + 0.5, length(p));
		col = mix(col, srgb(vec3(0.9, 0.87, 0.72)), bay * 0.8);
	}

	// Streets: asphalt with kerb stones and a pavement on each side (a track on a farm).
	float road = 0.0;
	float kerb = 0.0;
	float walk = 0.0;
	for (int k = 0; k < 6; k++) {
		if ((streets & (1 << k)) == 0) continue;
		float a = float(k) * 1.0471976;
		vec2 n = vec2(cos(a), sin(a));
		if (dot(p, n) < 0.0) continue;
		float across = abs(dot(p, vec2(-n.y, n.x)));
		road = max(road, 1.0 - smoothstep(1.45, 1.55, across));
		kerb = max(kerb, (1.0 - smoothstep(1.7, 1.8, across)) * smoothstep(1.45, 1.55, across));
		walk = max(walk, (1.0 - smoothstep(2.7, 2.8, across)) * smoothstep(1.7, 1.8, across));
	}
	// Where streets meet in the middle they widen into a small square.
	if (streets != 0) {
		float r = length(p);
		road = max(road, 1.0 - smoothstep(2.9, 3.0, r));
		kerb = max(kerb, (1.0 - smoothstep(3.15, 3.25, r)) * smoothstep(2.9, 3.0, r));
	}
	if (style == 3) {
		vec3 track = texture(dirt_tex, w * 0.35).rgb * 0.85;
		col = mix(col, track, road);
	} else {
		vec3 asphalt = srgb(vec3(0.3, 0.305, 0.31)) * mix(0.85, 1.12, grain) * mix(0.92, 1.05, stain);
		col = mix(col, srgb(vec3(0.72, 0.7, 0.66)) * mix(0.9, 1.05, grain), walk * (style == 1 ? 0.9 : 0.6));
		col = mix(col, srgb(vec3(0.78, 0.76, 0.72)), kerb);
		col = mix(col, asphalt, road);
		rough = mix(rough, 0.92, road);
	}

	// The edge of the tile: a clipped hedge round a garden, a stone kerb round
	// paving; nothing across a street, so streets run on into the next district.
	float open = max(road, walk);
	if (style == 1) {
		float hedge = (1.0 - smoothstep(0.6, 0.75, to_rim)) * (1.0 - open);
		col = mix(col, srgb(vec3(0.16, 0.27, 0.11)) * mix(0.8, 1.2, grain), hedge);
	} else if (style == 0 || style == 2) {
		float curb = (1.0 - smoothstep(0.3, 0.4, to_rim)) * (1.0 - open);
		col = mix(col, srgb(vec3(0.7, 0.68, 0.63)), curb);
	}
	// A touch of shade where the tile meets the ground (none across streets).
	col *= mix(1.0, 0.82, (1.0 - smoothstep(0.0, 0.12, to_rim)) * (1.0 - open));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}

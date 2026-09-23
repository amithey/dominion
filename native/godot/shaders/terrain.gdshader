// Terrain surface for maps exported from the browser game.
// Four CC0 ground materials (ambientCG) are blended by height, slope and
// large-scale noise: wet sand at the waterline, grass, patches of worn dirt,
// and rock on steep ground. Each is sampled at two scales, steep rock is
// projected from the side (triplanar), and layers with no weight are skipped,
// so most of the screen (plain grass) costs four texture reads.
// Noise comes from a seamless texture: per-pixel hash noise was both the
// single most expensive part of the frame and blocky at map-scale coordinates.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 0.16;          // repeats per metre, near scale
uniform float far_tile = 0.031;     // second, coarser scale that hides repetition
uniform float sea_level = 0.0;
uniform float cloud_shadow = 0.3;  // how dark drifting cloud shadows get
// Territory (territory.gd): the land is the districts' hex grid. One texel per
// hex: the owner's colour in RGB and the tint strength in A (0 = unclaimed),
// stored by row (r) and offset column. Borders between owners are always
// drawn along the hex edges, each nation's colour on its own side; the
// territory view (show_territory) also washes the land and hatches contested
// hexes in gold.
uniform bool show_territory = false;
uniform bool show_borders = false;
uniform sampler2D territory_tex : filter_nearest, repeat_disable;
uniform float hex_radius = 12.0;
uniform vec4 hex_grid = vec4(0.0, 0.0, 1.0, 1.0);   // c0, r0, columns, rows

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 weights;               // grass, dirt, sand, rock
varying float macro;

float noise(vec2 p) { return textureLod(noise_tex, p, 0.0).r; }

vec2 hex_round(vec2 a) {
	vec3 c = vec3(a.x, -a.x - a.y, a.y);
	vec3 r = round(c);
	vec3 d = abs(r - c);
	if (d.x > d.y && d.x > d.z) { r.x = -r.y - r.z; }
	else if (d.y > d.z) { r.y = -r.x - r.z; }
	else { r.z = -r.x - r.y; }
	return vec2(r.x, r.z);
}
vec2 hex_centre(vec2 h) { return vec2(hex_radius * sqrt(3.0) * (h.x + h.y * 0.5), hex_radius * 1.5 * h.y); }
vec4 hex_owner(vec2 h) {
	float col = h.x + (h.y - mod(h.y, 2.0)) * 0.5 + hex_grid.x;
	float row = h.y + hex_grid.y;
	if (col < 0.0 || row < 0.0 || col >= hex_grid.z || row >= hex_grid.w) { return vec4(0.0); }
	return texelFetch(territory_tex, ivec2(int(col), int(row)), 0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The grid is 2.5 m, finer than every feature below, so the weights are
	// computed per vertex and interpolated.
	vec2 p = world_pos.xz;
	float h = world_pos.y - sea_level;
	float slope = 1.0 - world_normal.y;
	macro = noise(p * 0.0035);
	float detail = noise(p * 0.021 + 0.31);
	float sand = 1.0 - smoothstep(0.6, 2.2, h + (detail - 0.5) * 2.2);
	float rock = smoothstep(0.16, 0.34, slope + (macro - 0.5) * 0.14);
	float dirt = smoothstep(0.6, 0.76, noise(p * 0.0045 + 0.57) * 0.65 + noise(p * 0.017 + 0.21) * 0.35) * 0.75;
	dirt = max(dirt, smoothstep(0.08, 0.16, slope) * 0.6);
	rock *= 1.0 - sand * 0.7;
	dirt *= (1.0 - rock) * (1.0 - sand);
	weights = vec4(max(0.0, 1.0 - sand - rock - dirt), dirt, sand, rock);
}

vec3 two_scale(sampler2D t, vec2 p) {
	return mix(texture(t, p * tile).rgb, texture(t, p * far_tile).rgb, 0.35);
}
vec3 two_scale_normal(sampler2D t, vec2 p) {
	return mix(texture(t, p * tile).rgb, texture(t, p * far_tile).rgb, 0.35) * 2.0 - 1.0;
}
// Tangent-space normal -> world, for a surface whose texture axes are u and v.
vec3 to_world(vec3 n_ts, vec3 n, vec3 u, vec3 v) {
	vec3 t = normalize(u - n * dot(u, n));
	vec3 b = normalize(v - n * dot(v, n));
	return t * n_ts.x + b * n_ts.y + n * n_ts.z;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 n = normalize(world_normal);
	vec4 w = weights / max(weights.x + weights.y + weights.z + weights.w, 0.001);
	vec3 albedo = vec3(0.0);
	vec3 wn = vec3(0.0);
	const vec3 X = vec3(1, 0, 0);
	const vec3 Z = vec3(0, 0, 1);
	if (w.x > 0.01) { albedo += two_scale(grass_albedo, p) * w.x; wn += to_world(two_scale_normal(grass_normal, p), n, X, Z) * w.x; }
	if (w.y > 0.01) { albedo += two_scale(dirt_albedo, p) * w.y; wn += to_world(two_scale_normal(dirt_normal, p), n, X, Z) * w.y; }
	if (w.z > 0.01) { albedo += two_scale(sand_albedo, p) * w.z; wn += to_world(two_scale_normal(sand_normal, p), n, X, Z) * w.z; }
	if (w.w > 0.01) {
		// Rock is projected from the side on steep ground so it does not smear.
		vec3 blend = pow(abs(n), vec3(4.0));
		blend /= (blend.x + blend.y + blend.z);
		vec3 rock = two_scale(rock_albedo, world_pos.zy) * blend.x + two_scale(rock_albedo, p) * blend.y + two_scale(rock_albedo, world_pos.xy) * blend.z;
		vec3 rn = to_world(two_scale_normal(rock_normal, world_pos.zy), n, Z, vec3(0, 1, 0)) * blend.x
			+ to_world(two_scale_normal(rock_normal, p), n, X, Z) * blend.y
			+ to_world(two_scale_normal(rock_normal, world_pos.xy), n, X, vec3(0, 1, 0)) * blend.z;
		albedo += rock * w.w;
		wn += rn * w.w;
	}

	// Large-scale colour variation: meadows are never one flat green.
	// The grass photo is a bright spring lime; pull it toward a deeper summer green.
	albedo = mix(albedo, albedo * vec3(0.82, 0.9, 0.7), w.x);
	albedo *= mix(0.8, 1.1, macro);
	albedo = mix(albedo, albedo * vec3(1.06, 1.0, 0.84), smoothstep(0.55, 0.75, noise(p * 0.0017 + 0.13)) * w.x);

	// Shadows of drifting clouds: large soft patches crossing the land slowly.
	float cloud = noise(p * 0.0016 + vec2(TIME * 0.0009, TIME * 0.0004));
	albedo *= 1.0 - cloud_shadow * smoothstep(0.5, 0.68, cloud);

	// Wet band just above the water and a darker, smoother seabed below it.
	float h = world_pos.y - sea_level;
	float wet = 1.0 - smoothstep(0.0, 0.7, h);
	albedo *= mix(1.0, 0.62, wet);

	if ((show_territory || show_borders) && world_pos.y > sea_level - 0.2) {
		vec2 p = world_pos.xz;
		vec2 h = hex_round(vec2((sqrt(3.0) / 3.0 * p.x - p.y / 3.0) / hex_radius, (2.0 / 3.0 * p.y) / hex_radius));
		vec4 own = hex_owner(h);
		if (own.a > 0.0) {
			vec2 c = hex_centre(h);
			vec2 d = p - c;
			// Distance to each of the six edges; a border where the neighbour across differs.
			float near = 1e6;
			vec2 dirs[6] = vec2[](vec2(1.0, 0.0), vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, 0.0), vec2(-1.0, 1.0), vec2(0.0, 1.0));
			for (int k = 0; k < 6; k++) {
				vec4 other = hex_owner(h + dirs[k]);
				if (distance(other.rgb, own.rgb) > 0.02 || other.a == 0.0) {
					vec2 n = normalize(hex_centre(h + dirs[k]) - c);
					near = min(near, hex_radius * 0.8660254 - dot(d, n));
				}
			}
			float edge = 1.0 - smoothstep(0.35, 1.3, near);   // the border line
			float band = 1.0 - smoothstep(1.3, 5.5, near);    // a soft wash of colour inside it
			bool contested = own.a > 0.95;
			if (show_territory) {
				float strength = contested ? 0.5 : own.a;
				vec3 tint = own.rgb;
				if (contested) {
					float stripe = step(0.5, fract((world_pos.x + world_pos.z) * 0.12));
					tint = mix(own.rgb, vec3(1.0, 0.78, 0.25), stripe);
				}
				albedo = mix(albedo, tint * (0.4 + dot(albedo, vec3(0.3, 0.59, 0.11)) * 0.8), strength);
			} else {
				// Outside the territory view: a soft band of colour inside the border, as a 4X map shows it.
				albedo = mix(albedo, own.rgb * 0.75 + albedo * 0.35, band * 0.35);
			}
			albedo = mix(albedo, own.rgb * 1.25 + 0.15, edge * 0.9);
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = mix(mix(0.92, 0.82, w.w), 0.35, wet);
	SPECULAR = mix(0.35, 0.5, wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(wn), 0.0)).xyz);
}

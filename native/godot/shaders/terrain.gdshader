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
#include "res://shaders/territory.gdshaderinc"
// Buildable ground (buildable.gd). The map's heights, so slopes can be measured
// over a district's width: ground too steep to build on is bare grey rock.
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec4 height_grid = vec4(0.0, 0.0, 1.0, 0.0);   // origin x, origin z, step, size (0: none)
// While a district is being placed, one texel per hex (the territory layout):
// G = it can go here, R = the land forbids it, B = something else does.
uniform bool show_build = false;
uniform sampler2D build_tex : filter_nearest, repeat_disable;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 weights;               // grass, dirt, sand, rock
varying float macro;

float noise(vec2 p) { return textureLod(noise_tex, p, 0.0).r; }
float map_height(vec2 p) {
	return textureLod(height_tex, ((p - height_grid.xy) / height_grid.z + 0.5) / height_grid.w, 0.0).r;
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
	// Rise across a district's width (16 m), the same measure the building
	// rules use (more than 6 m across a hex is too steep): such ground reads
	// as a rocky hillside, not as meadow you could build a town on.
	if (height_grid.w > 0.0) {
		float gx = map_height(p + vec2(8.0, 0.0)) - map_height(p - vec2(8.0, 0.0));
		float gz = map_height(p + vec2(0.0, 8.0)) - map_height(p - vec2(0.0, 8.0));
		float broad = length(vec2(gx, gz)) / 16.0;
		rock = max(rock, smoothstep(0.22, 0.32, broad + (detail - 0.5) * 0.05) * 0.95);
	}
	rock *= 1.0 - sand * 0.7;
	dirt *= (1.0 - rock) * (1.0 - sand);
	weights = vec4(max(0.0, 1.0 - sand - rock - dirt), dirt, sand, rock);
}

// How much of the fine, near texture shows: all of it close up, none from
// far away (the 6 m repeat of the photo turns into a speckle of dots from high
// above; the coarse scale alone reads as smooth meadow).
vec3 two_scale(sampler2D t, vec2 p, float near_detail) {
	vec3 coarse = texture(t, p * far_tile).rgb;
	if (near_detail < 0.01) return coarse;
	return mix(coarse, mix(texture(t, p * tile).rgb, coarse, 0.35), near_detail);
}
vec3 two_scale_normal(sampler2D t, vec2 p, float near_detail) {
	vec3 coarse = texture(t, p * far_tile).rgb;
	vec3 n = near_detail < 0.01 ? coarse : mix(coarse, mix(texture(t, p * tile).rgb, coarse, 0.35), near_detail);
	return mix(vec3(0.5, 0.5, 1.0), n, 0.4 + 0.6 * near_detail) * 2.0 - 1.0;
}
// Tangent-space normal -> world, for a surface whose texture axes are u and v.
vec3 to_world(vec3 n_ts, vec3 n, vec3 u, vec3 v) {
	vec3 t = normalize(u - n * dot(u, n));
	vec3 b = normalize(v - n * dot(v, n));
	return t * n_ts.x + b * n_ts.y + n * n_ts.z;
}

void fragment() {
	vec2 p = world_pos.xz;
	float nd = 1.0 - smoothstep(70.0, 200.0, length(VERTEX));
	vec3 n = normalize(world_normal);
	vec4 w = weights / max(weights.x + weights.y + weights.z + weights.w, 0.001);
	vec3 albedo = vec3(0.0);
	vec3 wn = vec3(0.0);
	const vec3 X = vec3(1, 0, 0);
	const vec3 Z = vec3(0, 0, 1);
	if (w.x > 0.01) { albedo += two_scale(grass_albedo, p, nd) * w.x; wn += to_world(two_scale_normal(grass_normal, p, nd), n, X, Z) * w.x; }
	if (w.y > 0.01) { albedo += two_scale(dirt_albedo, p, nd) * w.y; wn += to_world(two_scale_normal(dirt_normal, p, nd), n, X, Z) * w.y; }
	if (w.z > 0.01) { albedo += two_scale(sand_albedo, p, nd) * w.z; wn += to_world(two_scale_normal(sand_normal, p, nd), n, X, Z) * w.z; }
	if (w.w > 0.01) {
		// Rock is projected from the side on steep ground so it does not smear.
		vec3 blend = pow(abs(n), vec3(4.0));
		blend /= (blend.x + blend.y + blend.z);
		vec3 rock = two_scale(rock_albedo, world_pos.zy, nd) * blend.x + two_scale(rock_albedo, p, nd) * blend.y + two_scale(rock_albedo, world_pos.xy, nd) * blend.z;
		vec3 rn = to_world(two_scale_normal(rock_normal, world_pos.zy, nd), n, Z, vec3(0, 1, 0)) * blend.x
			+ to_world(two_scale_normal(rock_normal, p, nd), n, X, Z) * blend.y
			+ to_world(two_scale_normal(rock_normal, world_pos.xy, nd), n, X, vec3(0, 1, 0)) * blend.z;
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
		float near;
		vec4 own = hex_territory(world_pos.xz, near);
		if (own.a > 0.0) {
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
			albedo = mix(albedo, own.rgb * 1.05, edge * 0.8);  // the nation's own colour, not washed pale
		}
	}
	if (show_build && world_pos.y > sea_level - 1.5) {
		// Placing a district: every hex says whether it can go there.
		vec2 hx = hex_round(vec2((sqrt(3.0) / 3.0 * p.x - p.y / 3.0) / hex_radius, (2.0 / 3.0 * p.y) / hex_radius));
		float col = hx.x + (hx.y - mod(hx.y, 2.0)) * 0.5 + hex_grid.x;
		float row = hx.y + hex_grid.y;
		vec4 verdict = vec4(0.0);
		if (col >= 0.0 && row >= 0.0 && col < hex_grid.z && row < hex_grid.w) {
			verdict = texelFetch(build_tex, ivec2(int(col), int(row)), 0);
		}
		if (verdict.a > 0.0) {
			vec2 d = p - hex_centre(hx);
			float inset = hex_radius * 0.8660254 - max(abs(d.x), max(abs(0.5 * d.x + 0.8660254 * d.y), abs(-0.5 * d.x + 0.8660254 * d.y)));
			float rim = 1.0 - smoothstep(0.25, 0.9, inset);
			float grey = dot(albedo, vec3(0.3, 0.59, 0.11));
			vec3 mark;
			if (verdict.g > 0.5) {
				mark = vec3(0.3, 0.95, 0.45);
				albedo = mix(albedo, albedo * 0.7 + mark * 0.3, 0.55);
			} else if (verdict.r > 0.5) {
				mark = vec3(0.95, 0.18, 0.12);
				float stripe = step(0.55, fract((p.x - p.y) * 0.22));
				albedo = mix(albedo, mix(vec3(grey) * 0.8, mark * (0.35 + grey), 0.35 + 0.4 * stripe), 0.8);
			} else {
				mark = vec3(0.55);
				albedo = mix(albedo, vec3(grey * 0.55), 0.7);
			}
			albedo = mix(albedo, mark, rim * 0.85);
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = mix(mix(0.92, 0.82, w.w), 0.35, wet);
	SPECULAR = mix(0.35, 0.5, wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(wn), 0.0)).xyz);
}

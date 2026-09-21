// Ground of one hex district, Civilization-style: each building owns a whole
// hex whose surface says what it is. Styles: 0 plaza (paved, with joints),
// 1 residential (lawns and garden beds with pavements along the streets),
// 2 industrial (stained concrete yard), 3 farm (ploughed crop rows),
// 4 military (packed gravel with painted bays). Streets run from the core to
// every neighbouring district or road (6-bit mask, bit k = direction k*60°),
// and a kerb marks the hex edge. Coordinates are local to the hex centre.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;  // the skirt is seen from both sides

uniform sampler2D paving_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float hex_radius = 12.0;
uniform float core = 5.0;            // streets start at the edge of the central building
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

void fragment() {
	vec2 p = local;
	float apothem = hex_radius * 0.8660254;
	// Distance to the hex boundary along the six edge normals (k * 60°).
	float edge = 0.0;
	for (int k = 0; k < 6; k++) {
		float a = float(k) * 1.0471976;
		edge = max(edge, dot(p, vec2(cos(a), sin(a))));
	}
	vec2 w = world_pos.xz;
	float stain = noise(w * 0.05 + seed);
	vec3 col;
	float rough = 0.9;
	if (style == 0) {
		col = texture(paving_tex, w * 0.22).rgb * vec3(0.95, 0.92, 0.86);
		vec2 tile = abs(fract(w / 2.4) - 0.5);
		col *= mix(0.72, 1.0, smoothstep(0.46, 0.44, max(tile.x, tile.y)));
		rough = 0.8;
	} else if (style == 1) {
		col = texture(grass_tex, w * 0.16).rgb * mix(0.85, 1.05, stain);
		// Garden beds: darker soil patches between the houses.
		float bed = smoothstep(0.62, 0.66, noise(w * 0.12 + seed * 3.0));
		col = mix(col, texture(dirt_tex, w * 0.3).rgb * 0.7, bed * 0.8);
	} else if (style == 2) {
		col = texture(paving_tex, w * 0.12).rgb * vec3(0.82, 0.82, 0.8);
		col *= mix(1.0, 0.55, smoothstep(0.62, 0.8, stain));   // oil and rust stains
		rough = 0.75;
	} else if (style == 3) {
		// Crop rows running across the hex at a per-farm angle.
		float ang = seed * 2.3;
		vec2 dir = vec2(cos(ang), sin(ang));
		float row = sin(dot(p, vec2(-dir.y, dir.x)) * 3.4);
		vec3 soil = texture(dirt_tex, w * 0.25).rgb * 0.78;
		vec3 crop = mix(vec3(0.33, 0.42, 0.13), vec3(0.62, 0.55, 0.22), smoothstep(0.35, 0.75, noise(w * 0.03 + seed)));
		col = mix(soil, crop, smoothstep(-0.1, 0.35, row));
	} else {
		col = texture(dirt_tex, w * 0.2).rgb * vec3(0.78, 0.76, 0.7);
		col = mix(col, texture(paving_tex, w * 0.2).rgb * 0.7, 0.35);
		// Painted parking bays near the core.
		float bay = step(0.93, fract(p.x / 3.2)) * step(abs(p.y), 3.5) * step(core + 0.5, length(p));
		col = mix(col, vec3(0.85, 0.8, 0.55), bay * 0.7);
	}
	// Streets to connected neighbours, with pavements on residential blocks.
	for (int k = 0; k < 6; k++) {
		if ((streets & (1 << k)) == 0) continue;
		float a = float(k) * 1.0471976;
		vec2 n = vec2(cos(a), sin(a));
		float along = dot(p, n);
		float across = abs(dot(p, vec2(-n.y, n.x)));
		if (along > core * 0.6) {
			if (across < 1.7) {
				col = texture(paving_tex, w * 0.3).rgb * 0.42;
				col = mix(col, vec3(0.8, 0.76, 0.6), step(across, 0.07) * step(0.5, fract(along / 2.0)));
				rough = 0.85;
			} else if (across < 2.6 && style != 3) {
				col = texture(paving_tex, w * 0.35).rgb * 0.85;
			}
		}
	}
	// Kerb and a dark joint at the hex edge.
	float kerb = smoothstep(apothem - 0.75, apothem - 0.6, edge);
	col = mix(col, vec3(0.62, 0.6, 0.55), kerb);
	col *= mix(1.0, 0.55, smoothstep(apothem - 0.15, apothem - 0.02, edge));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}

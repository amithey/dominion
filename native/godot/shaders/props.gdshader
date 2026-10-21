// The small things of a district (houses' garden walls, fences, lamps, trees, containers, tanks, crates):
// painted in vertex colours, then given a weathered life: faint patina so no two surfaces are one flat
// colour, grime and damp that gather toward the ground, dust on what faces the sky, and winter snow on
// the roofs and tops. Same cost as the plain material it replaces (one texture read).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
global uniform float winter;

varying vec3 world_pos;
varying vec3 local;
varying vec3 world_normal;

void vertex() {
	local = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));   // vertex colours are sRGB
	float patina = texture(noise_tex, world_pos.xz * 0.35 + world_pos.y * 0.17).r;
	float fine = texture(noise_tex, world_pos.xz * 1.9 + world_pos.y * 0.9).r;
	c *= 0.86 + 0.2 * patina + 0.08 * fine;
	// Grime and damp toward the foot of everything, strongest on the first half metre.
	float foot = 1.0 - smoothstep(0.0, 1.3, local.y);
	c *= 1.0 - foot * (0.16 + 0.16 * patina);
	// Dust and sun-bleach on the surfaces that face the sky.
	c = mix(c, c * vec3(1.06, 1.05, 1.0) + vec3(0.012), smoothstep(0.6, 0.95, world_normal.y) * 0.5);
	if (winter > 0.0) {
		float top = smoothstep(0.6, 0.9, world_normal.y);
		float lay = winter * top * smoothstep(0.28, 0.62, patina + winter * 0.35);
		c = mix(c, vec3(0.62, 0.67, 0.74), lay * 0.85);
	}
	ALBEDO = c;
	ROUGHNESS = 0.8 + 0.1 * (1.0 - foot);
	SPECULAR = 0.3;
}

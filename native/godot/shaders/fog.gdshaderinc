// Fog of war (fog_of_war.gd), shared by everything that draws the land (the
// terrain, the sea, the trees and the grass) through global uniforms (project
// settings, shader_globals): one texel per 10 m cell, its alpha how dark the
// land is (0 watched now, 0.45 seen before, 0.82 never seen), over the
// rectangle fog_rect (origin x, origin z, width, depth). Off the map counts as
// never seen.
global uniform bool fog_on;
global uniform sampler2D fog_tex;
global uniform vec4 fog_rect;
// Winter (ambience.gd): 0 most of the year, 1 in deep winter; snow settles on
// what faces the sky.
global uniform float winter;

vec3 snowy(vec3 c, float amount) {
	return mix(c, vec3(0.86, 0.89, 0.93), clamp(amount, 0.0, 1.0));
}

float fog_at(vec2 p) {
	if (!fog_on) { return 0.0; }
	vec2 uv = (p - fog_rect.xy) / fog_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.82; }
	return texture(fog_tex, uv).a;
}

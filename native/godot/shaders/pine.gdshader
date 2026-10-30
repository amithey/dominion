// Pine needles (pines.gd): vertex colours for shade, the tree's own tint from
// its instance colour, and the same gusting wind as the birches (foliage.gdshader),
// stronger toward the top of the tree.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying vec3 tint;
varying vec3 local;   // the tree's own coordinates, for the needle clumps

#include "res://shaders/fog.gdshaderinc"
varying vec2 fog_xz;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	fog_xz = origin.xz;
	float phase = origin.x * 0.043 + origin.z * 0.061;
	float gust = sin(TIME * 0.9 + phase) * 0.6 + sin(TIME * 2.1 + phase * 1.7) * 0.25;
	float height = max(VERTEX.y, 0.0);
	vec3 world_offset = vec3(gust * 0.035 * height * height, 0.0, gust * 0.02 * height * height);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_offset;
	tint = INSTANCE_CUSTOM.rgb;
	local = VERTEX;
}

void fragment() {
	vec3 c = COLOR.rgb * COLOR.rgb;  // vertex colours are sRGB
	// Needle clumps: a fine speckle of lighter and darker tufts over the boughs, stronger at the tips.
	vec3 cell = floor(local * vec3(120.0, 96.0, 120.0));
	float clump = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	c *= 0.92 + 0.16 * clump * (0.5 + 0.5 * UV.x);
	ALBEDO = snowy(c * mix(vec3(1.0), tint * 2.0, 0.6), winter * 0.45) * (1.0 - fog_at(fog_xz));   // fog of war; snow-dusted in winter
	BACKLIGHT = ALBEDO * 0.4;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}

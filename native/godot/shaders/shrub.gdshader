// Shrub leaves (shrubs.gd): each bush has its own green (instance data), its blobs differ a little
// (vertex colour R), and the tops are lighter than the insides (G). Clumps of leaves speckle the surface
// and the whole bush moves a little in the same gusts as the trees.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying float tone;
varying float blob;
varying float top;
varying vec3 local;

#include "res://shaders/fog.gdshaderinc"
varying vec2 fog_xz;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	fog_xz = origin.xz;
	float phase = origin.x * 0.043 + origin.z * 0.061;
	float gust = sin(TIME * 0.9 + phase) * 0.6 + sin(TIME * 2.1 + phase * 1.7) * 0.25;
	VERTEX.x += gust * 0.03 * max(VERTEX.y, 0.0);
	tone = INSTANCE_CUSTOM.r;
	blob = COLOR.r;
	top = COLOR.g;
	local = VERTEX;
}

void fragment() {
	vec3 deep = mix(vec3(0.05, 0.13, 0.05), vec3(0.09, 0.16, 0.04), tone);
	vec3 lit = mix(vec3(0.14, 0.27, 0.08), vec3(0.24, 0.33, 0.09), tone);
	vec3 c = mix(deep, lit, top * (0.7 + 0.3 * blob));
	vec3 cell = floor(local * 40.0);
	float leaf = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	c *= 0.88 + 0.24 * leaf;
	ALBEDO = snowy(c, winter * top * 0.7) * (1.0 - fog_at(fog_xz));
	BACKLIGHT = ALBEDO * 0.3;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}

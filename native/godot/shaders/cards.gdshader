// Plant cards from an atlas (assets/art/foliage/*_atlas_*.png, grids of equal cells): grass tufts, wildflowers, shrubs, reeds.
// Each instance is a few crossed quads (foliage_cards.gd); its cell in the atlas is INSTANCE_CUSTOM.x, a tone variation is
// INSTANCE_CUSTOM.y. Alpha-cut, so there is no sorting; the plant sways in the same gusts as the trees (stronger toward the
// top of the card), catches back-light, takes snow in winter and follows the fog of war.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(4.0, 3.0);
uniform float cut = 0.45;
uniform float sway = 0.1;
uniform float snow_amount = 0.6;
uniform vec3 tint : source_color = vec3(1.0);
uniform float far_fade_start = 70.0;   // beyond this the card fades into the meadow (a card from afar is a speck)
uniform vec3 far_color : source_color = vec3(0.30, 0.38, 0.17);

varying float cell;
varying float tone;
varying float height01;
varying float distance_to_camera;

#include "res://shaders/fog.gdshaderinc"
varying vec2 fog_xz;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	fog_xz = origin.xz;
	cell = INSTANCE_CUSTOM.x;
	tone = INSTANCE_CUSTOM.y;
	height01 = 1.0 - UV.y;
	float phase = origin.x * 0.09 + origin.z * 0.07;
	float gust = sin(TIME * 1.4 + phase) * 0.65 + sin(TIME * 3.1 + phase * 2.0) * 0.25;
	float bend = height01 * height01;
	vec3 world_offset = vec3(gust * sway * bend, 0.0, sin(TIME * 1.1 + phase * 1.3) * sway * 0.6 * bend);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_offset;
	distance_to_camera = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

vec2 atlas_uv(vec2 uv) {
	vec2 c = vec2(mod(cell, grid.x), floor(cell / grid.x));
	return (c + uv) / grid;
}

void fragment() {
	vec4 t = texture(atlas, atlas_uv(UV));
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = cut;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ALPHA_TEXTURE_COORDINATE = atlas_uv(UV) * vec2(textureSize(atlas, 0));
	vec3 c = t.rgb * tint * mix(0.86, 1.1, tone);
	// Darker toward the roots, lighter at the tips: depth inside a clump.
	c *= mix(0.72, 1.06, smoothstep(0.0, 0.8, height01));
	float far = smoothstep(far_fade_start, far_fade_start + 45.0, distance_to_camera);
	c = mix(c, far_color * mix(0.9, 1.1, tone), far * 0.55);
	c = snowy(c, winter * snow_amount * (0.4 + 0.6 * height01));
	ALBEDO = c * (1.0 - fog_at(fog_xz));
	NORMAL_MAP = texture(atlas_normal, atlas_uv(UV)).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	BACKLIGHT = ALBEDO * 0.45;
	ROUGHNESS = 0.78;
	SPECULAR = 0.2;
}

// The Blender-made trees (assets/art/blender/env, scripts/env_trees.gd): vertex colours for the bark and the crowns, the tree's own
// tint from its instance colour, a fine speckle of lighter and darker tufts over the crowns, and the same gusting wind as the other
// trees, stronger toward the top. The bark moves with the crown so a trunk never tears away from it.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform bool bark = false;

varying vec3 tint;
varying vec3 local;       // the tree's own coordinates, for the leaf clumps
varying float facing_up;  // crowns facing the sky catch the light; the undersides sit in shade

#include "res://shaders/fog.gdshaderinc"
varying vec2 fog_xz;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	fog_xz = origin.xz;
	float phase = origin.x * 0.043 + origin.z * 0.061;
	float gust = sin(TIME * 0.9 + phase) * 0.6 + sin(TIME * 2.1 + phase * 1.7) * 0.25;
	float height = max(VERTEX.y, 0.0);
	vec3 world_offset = vec3(gust * 0.0045 * height * height, 0.0, gust * 0.0025 * height * height);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_offset;
	tint = INSTANCE_CUSTOM.rgb;
	local = VERTEX;
	facing_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y * 0.5 + 0.5;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (bark) {
		c *= 0.9 + 0.2 * fract(sin(dot(floor(local * vec3(30.0, 14.0, 30.0)), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		ALBEDO = snowy(c, winter * 0.25) * (1.0 - fog_at(fog_xz));
		ROUGHNESS = 0.95;
		SPECULAR = 0.15;
	} else {
		vec3 cell = floor(local * vec3(6.0, 5.0, 6.0));
		float clump = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		c *= (0.88 + 0.24 * clump) * 0.78;
		c *= mix(0.7, 1.08, facing_up);
		ALBEDO = snowy(c * mix(vec3(1.0), tint * 2.0, 0.6), winter * facing_up * 0.6) * (1.0 - fog_at(fog_xz));
		BACKLIGHT = ALBEDO * 0.35;
		ROUGHNESS = 0.8;
		SPECULAR = 0.25;
	}
}

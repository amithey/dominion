// Grass tufts near the camera. Each tuft is a handful of real blade triangles
// (no alpha textures, so no overdraw sorting); UV.y runs root to tip. Colour
// follows the same large-scale noise as the terrain so tufts sit on matching
// ground, and tips bend with the same wind as the trees.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 root_color : source_color = vec3(0.30, 0.37, 0.16);
uniform vec3 tip_color : source_color = vec3(0.47, 0.55, 0.25);
uniform vec3 dry_color : source_color = vec3(0.58, 0.54, 0.30);

varying float dryness;
varying float tuft;   // 0..1 per tuft: a tenth of them carry a flower

#include "res://shaders/fog.gdshaderinc"
varying vec2 fog_xz;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	fog_xz = origin.xz;
	tuft = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	dryness = smoothstep(0.5, 0.8, textureLod(noise_tex, origin.xz * 0.0045 + 0.57, 0.0).r);
	float phase = origin.x * 0.09 + origin.z * 0.07;
	float bend = UV.y * UV.y;
	VERTEX.x += (sin(TIME * 1.6 + phase) * 0.12 + sin(TIME * 3.7 + phase * 2.0) * 0.04) * bend;
	VERTEX.z += sin(TIME * 1.3 + phase * 1.3) * 0.08 * bend;
}

void fragment() {
	vec3 tip = mix(tip_color, dry_color, dryness);
	vec3 blade = mix(root_color, tip, UV.y);
	// From far away a tuft is a speck: it takes the colour of the meadow around it, so the ground is not freckled with dark blades.
	float far = smoothstep(25.0, 95.0, length(VERTEX));
	blade = mix(blade, mix(vec3(0.34, 0.42, 0.20), dry_color * 0.8, dryness), far * 0.75);
	// Meadow flowers on the tips of some tufts, near the camera only: white, yellow and violet.
	vec3 petal = tuft < 0.015 ? vec3(0.95, 0.94, 0.86) : (tuft < 0.06 ? vec3(0.96, 0.78, 0.14) : vec3(0.62, 0.38, 0.88));
	blade = mix(blade, petal, smoothstep(0.74, 0.86, UV.y) * step(tuft, 0.10) * (1.0 - far) * (1.0 - dryness * 0.7));
	ALBEDO = snowy(blade, winter * 0.75) * (1.0 - fog_at(fog_xz));   // fog of war; frosted in winter
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = ALBEDO * 0.3;
}

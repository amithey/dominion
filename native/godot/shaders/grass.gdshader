// Grass tufts near the camera. Each tuft is a handful of real blade triangles
// (no alpha textures, so no overdraw sorting); UV.y runs root to tip. Colour
// follows the same large-scale noise as the terrain so tufts sit on matching
// ground, and tips bend with the same wind as the trees.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 root_color : source_color = vec3(0.25, 0.31, 0.13);
uniform vec3 tip_color : source_color = vec3(0.47, 0.55, 0.25);
uniform vec3 dry_color : source_color = vec3(0.58, 0.54, 0.30);

varying float dryness;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	dryness = smoothstep(0.5, 0.8, textureLod(noise_tex, origin.xz * 0.0045 + 0.57, 0.0).r);
	float phase = origin.x * 0.09 + origin.z * 0.07;
	float bend = UV.y * UV.y;
	VERTEX.x += (sin(TIME * 1.6 + phase) * 0.12 + sin(TIME * 3.7 + phase * 2.0) * 0.04) * bend;
	VERTEX.z += sin(TIME * 1.3 + phase * 1.3) * 0.08 * bend;
}

void fragment() {
	vec3 tip = mix(tip_color, dry_color, dryness);
	ALBEDO = mix(root_color, tip, UV.y);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = ALBEDO * 0.3;
}

// Tree bark and leaves with wind. Replaces the imported birch materials so
// the trees sway: the whole tree leans slowly with gusts, and leaves add a
// faster flutter. Each tree gets its own phase from its world position, so
// a grove never moves in lockstep.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.5;
uniform bool leaves = false;
uniform float sway = 0.035;       // lean per metre of height
uniform float flutter = 0.05;     // leaf movement in metres

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.043 + origin.z * 0.061;
	float gust = sin(TIME * 0.9 + phase) * 0.6 + sin(TIME * 2.1 + phase * 1.7) * 0.25;
	float height = max(VERTEX.y, 0.0);
	VERTEX.x += gust * sway * height * height * 0.15;
	VERTEX.z += gust * sway * height * height * 0.08;
	if (leaves) {
		float f = sin(TIME * 7.0 + VERTEX.x * 3.1 + VERTEX.z * 2.7 + phase * 5.0);
		VERTEX += NORMAL * f * flutter;
	}
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	ALBEDO = c.rgb;
	if (leaves) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
		// Thin leaves let light through: a little back-lighting reads as foliage.
		BACKLIGHT = c.rgb * 0.35;
	}
	ROUGHNESS = leaves ? 0.75 : 0.9;
	SPECULAR = 0.3;
}

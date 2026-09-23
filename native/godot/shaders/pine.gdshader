// Pine needles (pines.gd): vertex colours for shade, the tree's own tint from
// its instance colour, and the same gusting wind as the birches (foliage.gdshader),
// stronger toward the top of the tree.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying vec3 tint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.043 + origin.z * 0.061;
	float gust = sin(TIME * 0.9 + phase) * 0.6 + sin(TIME * 2.1 + phase * 1.7) * 0.25;
	float height = max(VERTEX.y, 0.0);
	VERTEX.x += gust * 0.035 * height * height;
	VERTEX.z += gust * 0.02 * height * height;
	tint = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	vec3 c = COLOR.rgb * COLOR.rgb;  // vertex colours are sRGB
	ALBEDO = c * mix(vec3(1.0), tint * 2.0, 0.6);
	BACKLIGHT = ALBEDO * 0.25;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}

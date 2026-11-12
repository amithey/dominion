// The pressure wave of a large burst (blasts.gd): a thin bright shell racing outward, seen only at its edge (where the
// eye looks along it), fading as it spreads. `age` runs 0..1 over its short life.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;

instance uniform float age = 0.0;
instance uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.8);
instance uniform float strength = 0.5;

void fragment() {
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float fade = (1.0 - age) * (1.0 - age);
	ALBEDO = tint;
	ALPHA = clamp(edge * fade * strength, 0.0, 1.0);
}

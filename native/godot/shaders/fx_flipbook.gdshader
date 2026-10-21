// One frame of a flipbook sheet (assets/art/fx/*.png, grids of equal cells read left to right, top to bottom),
// drawn on a quad that always faces the camera: turning only about the vertical (ground effects, anchored at the
// quad's foot) or fully (a ball in the air). The frame is a float: the two neighbouring frames are blended, so
// a 24-frame-a-second film plays smoothly at any speed. Additive sheets (fire on black) use the same code with
// blend_add (effects.gd swaps the render mode).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(8.0, 8.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform bool yaw_only = true;
instance uniform float frame = 0.0;

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - pos;
	vec3 fwd;
	vec3 up;
	if (yaw_only) {
		fwd = normalize(vec3(to_cam.x, 0.0001, to_cam.z));
		up = vec3(0.0, 1.0, 0.0);
	} else {
		fwd = normalize(to_cam);
		up = vec3(0.0, 1.0, 0.0);
	}
	vec3 right = normalize(cross(up, fwd));
	up = cross(fwd, right);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * scale.x, 0.0), vec4(up * scale.y, 0.0), vec4(fwd, 0.0), vec4(pos, 1.0));
}

vec4 cell(vec2 uv, float f) {
	float n = grid.x * grid.y;
	float i = clamp(floor(f), 0.0, n - 1.0);
	vec2 c = vec2(mod(i, grid.x), floor(i / grid.x));
	return texture(sheet, (c + uv) / grid);
}

void fragment() {
	float f = frame;
	vec4 a = cell(UV, f);
	vec4 b = cell(UV, f + 1.0);
	vec4 c = mix(a, b, fract(f));
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = clamp(c.a * tint.a, 0.0, 1.0);
}

// Painted military vehicle surface. The source models carry flat colours, so
// realism comes from the paint itself: matte army paint in the nation's
// colour, mottled grime and weathering from a noise texture, and road dust that
// gathers low on the hull. Everything is projected in the model's own space,
// so the pattern stays on the vehicle as it drives.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 paint : source_color = vec3(0.34, 0.37, 0.25);
uniform float shade = 1.0;              // Main / Main_Light / Main_Dark panels
uniform vec3 dust_color : source_color = vec3(0.47, 0.42, 0.33);
uniform float dust_height = 1.1;        // metres above the ground below which dust gathers
instance uniform float ground_y = 0.0;  // terrain height under this vehicle, set by the game
uniform float metal = 0.0;              // 1 for tracks, wheels and fittings
// Procedural vehicles (armor.gd) are one mesh per moving part, so each vertex
// carries its own finish: COLOR.r = shade / 2, COLOR.g = metal, COLOR.b = 1
// for the nation's markings, 0.5 for glass and lamps, 0.25 for
// the red antifouling below a ship's waterline.
uniform bool vertex_tone = false;
uniform vec3 team : source_color = vec3(0.2, 0.4, 0.9);

varying vec3 local_pos;
varying vec3 local_normal;
varying float above_ground;
varying vec3 tone;

void vertex() {
	// Model units vary between assets (FBX centimetres, glTF metres): scale the
	// pattern to metres so grime has the same size on every vehicle.
	local_pos = VERTEX * length(MODEL_MATRIX[0].xyz);
	local_normal = NORMAL;
	above_ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - ground_y;
	tone = vertex_tone ? COLOR.rgb : vec3(0.5, 0.0, 0.0);
}

float tri_noise(float scale) {
	vec3 b = pow(abs(normalize(local_normal)), vec3(4.0));
	b /= b.x + b.y + b.z;
	return texture(noise_tex, local_pos.zy * scale).r * b.x
		+ texture(noise_tex, local_pos.xz * scale).r * b.y
		+ texture(noise_tex, local_pos.xy * scale).r * b.z;
}

void fragment() {
	float grime = tri_noise(0.9);
	float speckle = tri_noise(4.5);
	float s = vertex_tone ? tone.r * 2.0 : shade;
	float m = vertex_tone ? tone.g : metal;
	vec3 base = mix(paint * s, vec3(0.13, 0.13, 0.12), m);
	if (vertex_tone && tone.b > 0.75) {
		base = team * 0.8;
	} else if (vertex_tone && tone.b > 0.4) {
		base = vec3(0.05, 0.07, 0.08);  // vision blocks and lenses
	} else if (vertex_tone && tone.b > 0.15) {
		base = vec3(0.32, 0.1, 0.08) * s;  // antifouling
	}
	// Mottled weathering: faded and darker patches, like sun-bleached paint.
	vec3 col = base * mix(0.8, 1.06, grime) * mix(0.94, 1.03, speckle);
	// Road dust on the lower hull and running gear.
	float dust = (1.0 - smoothstep(dust_height * 0.35, dust_height, above_ground)) * smoothstep(0.35, 0.65, grime + speckle * 0.3);
	col = mix(col, dust_color, dust * 0.7);
	ALBEDO = col;
	bool glass = vertex_tone && tone.b > 0.4 && tone.b < 0.75;
	ROUGHNESS = glass ? 0.12 : mix(mix(0.72, 0.9, grime), 0.55, m) + dust * 0.1;
	METALLIC = glass ? 0.6 : mix(0.08, 0.55, m) * (1.0 - dust);
	SPECULAR = 0.4;
}

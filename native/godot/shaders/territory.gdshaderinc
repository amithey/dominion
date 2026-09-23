// Territory on the hex grid (territory.gd), shared by the terrain and the sea:
// one texel per hex with the owner's colour in RGB and the tint strength in A
// (0 = unclaimed), stored by row (r) and offset column. territory.gd sets the
// same uniforms on both materials.
uniform bool show_territory = false;
uniform bool show_borders = false;
uniform sampler2D territory_tex : filter_nearest, repeat_disable;
uniform float hex_radius = 12.0;
uniform vec4 hex_grid = vec4(0.0, 0.0, 1.0, 1.0);   // c0, r0, columns, rows

vec2 hex_round(vec2 a) {
	vec3 c = vec3(a.x, -a.x - a.y, a.y);
	vec3 r = round(c);
	vec3 d = abs(r - c);
	if (d.x > d.y && d.x > d.z) { r.x = -r.y - r.z; }
	else if (d.y > d.z) { r.y = -r.x - r.z; }
	else { r.z = -r.x - r.y; }
	return vec2(r.x, r.z);
}
vec2 hex_centre(vec2 h) { return vec2(hex_radius * sqrt(3.0) * (h.x + h.y * 0.5), hex_radius * 1.5 * h.y); }
vec4 hex_owner(vec2 h) {
	float col = h.x + (h.y - mod(h.y, 2.0)) * 0.5 + hex_grid.x;
	float row = h.y + hex_grid.y;
	if (col < 0.0 || row < 0.0 || col >= hex_grid.z || row >= hex_grid.w) { return vec4(0.0); }
	return texelFetch(territory_tex, ivec2(int(col), int(row)), 0);
}
// Owner of the hex under ground point p (x, z) and the distance in metres from p
// to the nearest edge where the land passes to someone else (1e6 if none).
vec4 hex_territory(vec2 p, out float near) {
	vec2 h = hex_round(vec2((sqrt(3.0) / 3.0 * p.x - p.y / 3.0) / hex_radius, (2.0 / 3.0 * p.y) / hex_radius));
	vec4 own = hex_owner(h);
	near = 1e6;
	if (own.a <= 0.0) { return own; }
	vec2 c = hex_centre(h);
	vec2 d = p - c;
	vec2 dirs[6] = vec2[](vec2(1.0, 0.0), vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, 0.0), vec2(-1.0, 1.0), vec2(0.0, 1.0));
	for (int k = 0; k < 6; k++) {
		vec4 other = hex_owner(h + dirs[k]);
		if (distance(other.rgb, own.rgb) > 0.02 || other.a == 0.0) {
			vec2 n = normalize(hex_centre(h + dirs[k]) - c);
			near = min(near, hex_radius * 0.8660254 - dot(d, n));
		}
	}
	return own;
}

shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Tong mau xanh co tuoi tu nhien kieu anh mau nguoi dung chon
const vec3 AOE_GRASS_DEEP  = vec3(0.060, 0.100, 0.024);
const vec3 AOE_GRASS_MID   = vec3(0.090, 0.138, 0.034);
const vec3 AOE_GRASS_LIGHT = vec3(0.122, 0.172, 0.044);
const vec3 AOE_DIRT_EARTH  = vec3(0.160, 0.120, 0.038);

float hash(vec2 p) {
	vec2 q = fract(p * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 world_xz = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;

	// Hat co phan bo da tang
	float n_macro = smooth_noise(world_xz * 0.15);
	float n_micro = smooth_noise(world_xz * 0.85);
	float n_detail = smooth_noise(world_xz * 2.2);

	float n_grass = n_macro * 0.5 + n_micro * 0.35 + n_detail * 0.15;
	vec3 col = mix(AOE_GRASS_DEEP, AOE_GRASS_LIGHT, n_grass);

	// Cac vet dat reu lo thien
	float n_dirt = smooth_noise(world_xz * 0.08 + vec2(33.1, 71.4));
	float dirt_mask = smoothstep(0.66, 0.82, n_dirt) * 0.32;

	ALBEDO = mix(col, AOE_DIRT_EARTH, dirt_mask);
	ROUGHNESS = 0.98;
	SPECULAR = 0.0;
}

shader_type canvas_item;

// DigitalWorld Mobiles landing backdrop: midnight gradient, drifting amber/cyan
// light, a perspective stage grid and floating particles in one cheap full-screen pass.

const vec3 AMBER = vec3(0.773, 0.541, 0.227);
const vec3 CYAN = vec3(0.247, 0.816, 0.878);
const vec3 VIOLET = vec3(0.420, 0.330, 0.820);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amplitude * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

float soft_glow(vec2 p, vec2 centre, float radius) {
	vec2 d = p - centre;
	return exp(-dot(d, d) / (radius * radius));
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float t = TIME;
	float horizon = 0.63;

	// Deep midnight base, slightly lifted towards the horizon.
	vec3 col = mix(vec3(0.018, 0.024, 0.042), vec3(0.040, 0.050, 0.078), smoothstep(0.0, horizon, uv.y));
	col = mix(col, vec3(0.006, 0.008, 0.014), smoothstep(horizon, 1.0, uv.y));

	// Slow drifting aurora light.
	float clouds = fbm(p * 2.1 + vec2(t * 0.020, -t * 0.014));
	vec2 amber_pos = vec2(0.06 * aspect + 0.07 * sin(t * 0.11), -0.04 + 0.04 * cos(t * 0.13));
	vec2 cyan_pos = vec2(-0.36 * aspect + 0.10 * cos(t * 0.09), -0.30 + 0.05 * sin(t * 0.07));
	vec2 violet_pos = vec2(0.40 * aspect + 0.06 * sin(t * 0.08 + 1.3), -0.22 + 0.05 * cos(t * 0.10));
	col += AMBER * soft_glow(p, amber_pos, 0.40) * (0.26 + 0.26 * clouds);
	col += CYAN * soft_glow(p, cyan_pos, 0.55) * (0.10 + 0.18 * clouds);
	col += VIOLET * soft_glow(p, violet_pos, 0.45) * (0.08 + 0.14 * clouds);

	// Glowing horizon line where the stage meets the sky.
	float horizon_distance = abs(uv.y - horizon);
	float horizon_width = 1.0 - smoothstep(0.0, 0.62 * aspect, abs(p.x));
	col += mix(CYAN, AMBER, 0.55) * exp(-horizon_distance * 70.0) * 0.45 * horizon_width;
	col += AMBER * exp(-horizon_distance * 9.0) * 0.06;

	// Perspective grid on the stage floor, gently scrolling towards the viewer.
	float floor_depth = max(uv.y - horizon, 0.0005);
	float depth = 0.16 / floor_depth;
	vec2 grid_uv = vec2((uv.x - 0.5) * aspect * depth * 5.0, depth * 3.0 + t * 0.35);
	vec2 grid_width = fwidth(grid_uv) * 1.4;
	vec2 grid_lines = 1.0 - smoothstep(vec2(0.0), grid_width, abs(fract(grid_uv - 0.5) - 0.5));
	float grid = max(grid_lines.x, grid_lines.y);
	float floor_mask = step(horizon, uv.y) * smoothstep(0.0, 0.10, floor_depth) * (1.0 - smoothstep(0.0, 0.85 * aspect, abs(p.x)));
	col += mix(CYAN, AMBER, uv.x) * grid * floor_mask * 0.26;

	// Floating particles drifting upwards.
	vec2 sp = vec2(uv.x * aspect, uv.y) * 26.0 + vec2(0.0, t * 0.45);
	vec2 cell = floor(sp);
	vec2 local = fract(sp) - 0.5;
	float seed = hash21(cell);
	vec2 jitter = vec2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5;
	float particle = smoothstep(0.09, 0.0, length(local - jitter * 0.7)) * step(0.88, seed);
	float twinkle = 0.45 + 0.55 * sin(t * (0.8 + seed * 2.2) + seed * 40.0);
	col += mix(CYAN, AMBER, seed) * particle * twinkle * 0.55 * (1.0 - smoothstep(horizon - 0.05, horizon + 0.10, uv.y));

	// Occasional diagonal light sweep.
	float sweep_pos = mod(t * 0.07, 3.2) - 1.6;
	col += vec3(0.9, 0.85, 0.75) * exp(-pow(p.x * 0.55 + p.y * 0.85 - sweep_pos, 2.0) * 30.0) * 0.025;

	// Keep the headline side calm and readable, then vignette and fine grain.
	col *= mix(0.70, 1.0, smoothstep(0.02, 0.48, uv.x));
	float vignette = length((uv - 0.5) * vec2(1.0, 1.2));
	col *= mix(0.38, 1.0, smoothstep(0.85, 0.18, vignette));
	col += (hash21(FRAGCOORD.xy + fract(t) * 91.0) - 0.5) * 0.016;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}

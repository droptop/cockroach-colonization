shader_type canvas_item;

// Soft dark vignette — quiet edges pull the eye to the lit center (kage-style).

uniform float strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.55, 1.2));
	float v = smoothstep(0.42, 0.95, d);
	COLOR = vec4(0.015, 0.01, 0.035, v * strength);
}

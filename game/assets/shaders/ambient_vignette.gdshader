shader_type canvas_item;

// Ambient vignette: subtle, always-on edge darkening for dungeon atmosphere.
// Unlike hit_vignette, this uses smooth (non-pixelated) falloff at low intensity.

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	// Smooth falloff from edges toward center
	float vignette = smoothstep(0.5, 0.5 - vignette_softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - vignette) * vignette_intensity);
}

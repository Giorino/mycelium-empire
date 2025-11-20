shader_type canvas_item;

// Pulsing glow effect for mycelium network
// Creates an organic "breathing" effect with color shifting

uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);  // Cyan
uniform float brightness_boost : hint_range(1.0, 3.0) = 1.5;

void fragment() {
	// Sample original texture
	vec4 tex_color = texture(TEXTURE, UV);

	// Create pulsing effect using sine wave
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;  // Oscillates 0-1

	// Apply pulse to brightness
	float glow_intensity = 1.0 + (pulse * pulse_strength);

	// Boost cyan/blue channels for bioluminescent effect
	vec3 enhanced_color = tex_color.rgb * brightness_boost;
	enhanced_color = mix(enhanced_color, glow_color.rgb, pulse * 0.2);  // Subtle color shift

	// Final color with glow
	COLOR = vec4(enhanced_color * glow_intensity, tex_color.a);
}

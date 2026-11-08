shader_type canvas_item;

uniform sampler2D watercolor_wash : source_color, repeat_enable, filter_linear;
uniform sampler2D paper_grain : repeat_enable, filter_linear;
uniform float wash_scale = 0.0008;   // Size of sunlit yellow/sage patches
uniform float grain_scale = 0.006;   // Size of watercolor paper grain
uniform float wash_strength : hint_range(0.0, 1.0) = 0.65;
uniform float grain_strength : hint_range(0.0, 0.4) = 0.08;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec3 wash = texture(watercolor_wash, world_pos * wash_scale).rgb;
	float grain = texture(paper_grain, world_pos * grain_scale).r;
	
	// Blend continuous world-space watercolor wash over your base tile color
	vec3 final_rgb = mix(base.rgb, wash, wash_strength);
	// Multiply slightly by base luminance so darker tiles stay darker
	final_rgb *= mix(vec3(1.0), base.rgb * 1.15, 0.35);
	// Add fine paper tooth texture
	final_rgb += (grain - 0.5) * grain_strength;
	
	COLOR = vec4(final_rgb, base.a);
}
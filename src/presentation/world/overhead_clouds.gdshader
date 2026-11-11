shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cloud_noise : repeat_enable, filter_linear;
uniform vec2 world_origin;
uniform vec2 world_size;
uniform vec2 drift = vec2(0.0);
uniform float opacity : hint_range(0.0, 0.5) = 0.24;

void fragment() {
	vec2 world_position = world_origin + UV * world_size;
	vec2 noise_uv = (world_position - drift) / 1500.0;
	float density = texture(cloud_noise, noise_uv).r;
	float edge = smoothstep(0.52, 0.76, density);
	vec3 color = mix(vec3(0.85, 0.91, 0.96), vec3(1.0), density);
	COLOR = vec4(color, edge * opacity);
}

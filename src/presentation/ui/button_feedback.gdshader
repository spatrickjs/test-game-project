shader_type canvas_item;

uniform vec2 button_center = vec2(0.0);
uniform float press_amount = 0.0;
uniform float press_scale = 0.95;
uniform float disabled_amount = 0.0;

void vertex() {
	VERTEX = button_center + (VERTEX - button_center) * mix(1.0, press_scale, press_amount);
}

void fragment() {
	vec4 color = COLOR;
	color.rgb *= mix(1.0, 0.8, press_amount);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(gray), disabled_amount * 0.65);
	color.a *= mix(1.0, 0.45, disabled_amount);
	COLOR = color;
}

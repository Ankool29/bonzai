// Terre : texture pixel art (PixelLab) répétée en miroir, sans raccord visible.
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec2 scale = vec2(1.0);

void fragment() {
	ALBEDO = texture(tex, abs(fract(UV * scale * 0.5) * 2.0 - 1.0)).rgb;
	ROUGHNESS = 1.0;
}

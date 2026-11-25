// Écorce et terre : texture pixel art (PixelLab) répétée en miroir (aucun raccord visible).
// Couleur de sommet : rgb = teinte, a = part de teinte unie (pousse verte, bois mort, sélection).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec2 scale = vec2(1.0);
uniform bool use_vertex_color = true;

void fragment() {
	vec2 uv = abs(fract(UV * scale * 0.5) * 2.0 - 1.0);
	vec3 c = texture(tex, uv).rgb;
	if (use_vertex_color) {
		c = mix(c, COLOR.rgb, COLOR.a);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

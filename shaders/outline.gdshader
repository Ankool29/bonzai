// Contour : le maillage est redessiné légèrement gonflé, faces avant masquées (« coque inversée »).
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 color : source_color = vec4(0.13, 0.09, 0.08, 1.0);
uniform float width = 0.0008;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}

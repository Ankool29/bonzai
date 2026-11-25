// Contour : le maillage est redessiné légèrement gonflé, faces avant masquées (« coque inversée »).
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

#include "res://shaders/anim.gdshaderinc"

uniform int anim = 0;  // 1 : suit l'animation du bois

uniform vec4 color : source_color = vec4(0.13, 0.09, 0.08, 1.0);
uniform float width = 0.0008;

void vertex() {
	float shown = 1.0;
	float w = width;
	if (anim == 1) {
		w = min(width, length(VERTEX - CUSTOM1.xyz) * 0.5);  // contour plus fin sur les jeunes rameaux
		VERTEX = anim_wood(VERTEX, CUSTOM0, CUSTOM1, CUSTOM2, shown);
	}
	VERTEX += NORMAL * w * shown;
}

void fragment() {
	ALBEDO = color.rgb;
}

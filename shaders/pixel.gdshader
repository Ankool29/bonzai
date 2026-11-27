// Rendu pixel art : appliqué à l'image basse résolution de la scène 3D (SubViewport agrandi sans lissage).
// Contour d'un pixel sur les bords nets, couleurs ramenées à quelques niveaux avec un tramage de Bayer 4×4.
shader_type canvas_item;

uniform bool pixel = false;
uniform float levels = 12.0;     // niveaux par couleur
uniform float edge = 0.18;       // écart de luminosité qui fait un contour

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (pixel) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float l = lum(c.rgb);
		float hi = max(max(lum(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb), lum(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb)),
				max(lum(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb), lum(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb)));
		if (hi - l > edge) {
			c.rgb *= 0.35;  // pixel du côté sombre d'un bord : il devient trait
		}
		ivec2 ip = ivec2(floor(UV / px));
		float b = (BAYER[(ip.y % 4) * 4 + (ip.x % 4)] + 0.5) / 16.0 - 0.5;
		c.rgb = clamp(floor(c.rgb * (levels - 1.0) + 0.5 + b * 0.3) / (levels - 1.0), 0.0, 1.0);
	}
	COLOR = c;
}

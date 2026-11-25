// Écorce procédurale en pixels : cellules d'environ 2,5 mm autour du tronc et le long du bois,
// deux tons de fond, quelques taches (desquamation de l'orme) et des fissures allongées.
// UV.x = fraction du tour, UV.y = longueur depuis la base de l'axe (m), UV2.x = nombre de cellules du tour.
// Couleur de sommet : rgb = teinte, a = part de teinte unie (pousse verte, bois mort, sélection).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 tone1 : source_color = vec3(0.55, 0.52, 0.47);
uniform vec3 tone2 : source_color = vec3(0.63, 0.6, 0.55);
uniform vec3 fleck : source_color = vec3(0.62, 0.45, 0.32);
uniform vec3 fissure : source_color = vec3(0.33, 0.28, 0.24);
uniform float fleck_amount = 0.15;
uniform float fissure_amount = 0.18;
uniform float cell_len = 0.0025;
uniform float plate_len = 0.012;

float h(vec2 p, float s) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + s) * 43758.5453);
}

void fragment() {
	float cells = max(UV2.x, 3.0);
	float cu = mod(floor(UV.x * cells), cells);
	float cl = floor(UV.y / cell_len);
	float plate = floor(UV.y / plate_len + h(vec2(cu, 0.0), 1.0));
	vec3 c = h(vec2(cu, cl), 3.0) < 0.55 ? tone1 : tone2;
	if (h(vec2(cu, cl), 5.0) < fleck_amount) {
		c = fleck;
	}
	if (h(vec2(cu, plate), 2.0) < fissure_amount) {
		c = fissure;
	}
	ALBEDO = mix(c, COLOR.rgb, COLOR.a);
	ROUGHNESS = 1.0;
}

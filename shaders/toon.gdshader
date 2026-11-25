// Cel shading : éclairage arrondi à 3 tons nets (lumière, mi-teinte, ombre), ombres portées nettes.
// L'ombre prend la couleur de la lumière ambiante (bleutée), pas du gris.
// pattern : 0 = couleur de sommet × albedo ; 1 = écorce d'orme (plaques) ; 2 = écorce de pin (fissures) ;
// 3 = terre (granulés). Écorce : UV.x = fraction du tour, UV.y = longueur (m), UV2.x = cellules de 2,5 mm
// sur le tour ; couleur de sommet rgb = teinte, a = part de teinte unie (rameau de l'année, bois mort, sélection).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform int pattern = 0;
uniform vec3 tone1 : source_color = vec3(0.56, 0.55, 0.5);
uniform vec3 tone2 : source_color = vec3(0.5, 0.52, 0.42);
uniform vec3 tone3 : source_color = vec3(0.72, 0.5, 0.3);
uniform vec3 fissure : source_color = vec3(0.33, 0.28, 0.24);

varying vec3 wpos;

float h(vec2 p, float s) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + s) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = albedo.rgb * COLOR.rgb;
	if (pattern == 1 || pattern == 2) {
		// grandes plaques : 4 cellules de 2,5 mm par plaque autour du tronc, 12 à 20 mm de long
		float big = max(floor(UV2.x / 4.0), 1.0);
		float cu = mod(floor(UV.x * big), big);
		float row = floor(UV.y / (pattern == 1 ? 0.012 : 0.02) + h(vec2(cu, 0.0), 1.0));
		float k = h(vec2(cu, row), 9.0);
		vec3 b = tone1;
		if (pattern == 1 && big >= 3.0) {
			b = k < 0.5 ? tone1 : (k < 0.8 ? tone2 : tone3);
		} else if (pattern == 2 && k < 0.35) {
			b = fissure;
		}
		c = mix(b, COLOR.rgb, COLOR.a);
	} else if (pattern == 3) {
		float k = h(floor(wpos.xz / 0.004), 4.0);
		c = albedo.rgb * (k < 0.3 ? 1.25 : (k < 0.6 ? 1.0 : 0.8));
	}
	ALBEDO = c;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl > 0.3 ? 1.0 : (ndl > 0.0 ? 0.55 : 0.0);
	lit *= ATTENUATION > 0.5 ? 1.0 : 0.0;  // ombre portée : tout ou rien
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
}

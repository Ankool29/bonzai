// Cel shading : éclairage arrondi à 3 tons nets (lumière, mi-teinte, ombre), ombres portées nettes.
// L'ombre prend la couleur de la lumière ambiante (bleutée), pas du gris.
// pattern : 0 = couleur de sommet × albedo ; 1 = écorce d'orme (plaques) ; 2 = écorce de pin (fissures) ;
// 3 = terre (granulés) ; 4 = écorce d'érable (lisse, stries). Écorce : UV.x = fraction du tour, UV.y = longueur (m), UV2.x = cellules de 2,5 mm
// sur le tour ; couleur de sommet rgb = teinte, a = part de teinte unie (rameau de l'année, bois mort, sélection).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/anim.gdshaderinc"

uniform int anim = 0;  // 0 : immobile, 1 : bois animé, 2 : feuilles ou aiguilles animées
uniform bool deciduous = true;  // feuilles qui jaunissent en automne
uniform vec3 young_color : source_color = vec3(0.55, 0.47, 0.38);  // rameau de l'année
uniform vec3 dry_color : source_color = vec3(0.85, 0.82, 0.75);    // bois mort
uniform vec3 autumn_color : source_color = vec3(0.82, 0.6, 0.2);

uniform vec4 albedo : source_color = vec4(1.0);
uniform int pattern = 0;
uniform vec3 tone1 : source_color = vec3(0.56, 0.55, 0.5);
uniform vec3 tone2 : source_color = vec3(0.5, 0.52, 0.42);
uniform vec3 tone3 : source_color = vec3(0.72, 0.5, 0.3);
uniform vec3 fissure : source_color = vec3(0.33, 0.28, 0.24);

varying vec3 wpos;
varying float young_k;
varying float dry_k;
varying float autumn_k;

float h(vec2 p, float s) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + s) * 43758.5453);
}

// Cellules de Voronoï, périodiques en x (le tour du tronc) : (distance au centre, écart au bord, hasard de la cellule).
vec3 voro(vec2 p, float per, float sd) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 c = ip + g;
			c.x = mod(c.x, per);
			vec2 r = g + vec2(h(c, sd), h(c, sd + 5.0)) * 0.8 + 0.1 - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = h(c, sd + 9.0);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2) - sqrt(d1), id);
}

void vertex() {
	young_k = 0.0;
	dry_k = 0.0;
	autumn_k = 0.0;
	if (anim == 1) {
		float shown;
		VERTEX = anim_wood(VERTEX, CUSTOM0, CUSTOM1, CUSTOM2, shown);
		young_k = 1.0 - clamp((anim_time - CUSTOM0.x) / 52.0, 0.0, 1.0);
		dry_k = (CUSTOM0.w >= 0.0 && anim_time >= CUSTOM0.w) ? 1.0 : 0.0;
	} else if (anim == 2) {
		VERTEX = anim_leaf(VERTEX, CUSTOM0, CUSTOM1);
		if (deciduous) {
			autumn_k = clamp((mod(anim_time, 52.0) - 40.0) / 5.0, 0.0, 1.0);  // jaunit en octobre
		}
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = albedo.rgb * COLOR.rgb;
	if (pattern == 1 || pattern == 2 || pattern == 4) {
		vec3 b = tone1;
		if (pattern == 1) {
			// orme de Chine : plaques arrondies de tailles variées qui s'écaillent (gris, beige, orangé, vert)
			float per = max(floor(UV2.x / 3.0), 1.0);
			vec3 v = voro(vec2(UV.x * per, UV.y / 0.012), per, 1.0);
			vec3 w = voro(vec2(UV.x * per * 2.0, UV.y / 0.006), per * 2.0, 4.0);  // petites écailles par-dessus
			float id = w.z < 0.25 ? w.z * 4.0 : v.z;
			if (per >= 2.0) {
				b = id < 0.45 ? tone1 : (id < 0.7 ? tone2 : (id < 0.88 ? tone3 : mix(tone1, vec3(0.5, 0.56, 0.4), 0.6)));
				if (v.y < 0.04 && v.z < 0.6) {
					b = mix(b, fissure, 0.4);
				}
			}
		} else if (pattern == 2) {
			// pin noir : épaisses plaques allongées, fissures brun-rouge qui se creusent avec l'âge ; jeune bois lisse
			float per = max(floor(UV2.x / 5.0), 1.0);
			vec3 v = voro(vec2(UV.x * per, UV.y / 0.035), per, 2.0);
			float w = 0.03 + 0.09 * clamp((per - 1.0) / 3.0, 0.0, 1.0);
			if (UV2.x >= 8.0) {
				b = v.z < 0.5 ? tone1 : tone2;
				if (v.y < w) {
					b = fissure;
				}
			}
		} else {
			// érable : lisse, gris-vert, fines stries claires interrompues dans le sens du bois
			float col = floor(UV.x * UV2.x * 1.5);
			float k = h(vec2(col, 0.0), 3.0);
			if (k > 0.85 && fract(UV.y / 0.03 + k * 7.0) < 0.6) {
				b = tone2;
			}
		}
		b = mix(b, young_color, young_k * 0.35);
		b = mix(b, dry_color, dry_k * 0.7);
		c = mix(b, COLOR.rgb, COLOR.a);
	} else if (pattern == 3) {
		float k = h(floor(wpos.xz / 0.004), 4.0);
		c = albedo.rgb * (k < 0.3 ? 1.25 : (k < 0.6 ? 1.0 : 0.8));
	}
	c = mix(c, autumn_color, autumn_k * 0.85);
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

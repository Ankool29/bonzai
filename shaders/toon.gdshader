// Cel shading : éclairage arrondi à 3 tons nets (lumière, mi-teinte, ombre), ombres portées nettes.
// L'ombre prend la couleur de la lumière ambiante (bleutée), pas du gris.
// pattern : 0 = couleur de sommet × albedo ; 1 = écorce d'orme (plaques) ; 2 = écorce de pin (fissures) ;
// 3 = terre (granulés) ; 4 = écorce d'érable (lisse, stries) ; 5 = gravier ratissé (lignes, ondes autour des pierres) ;
// 6 = écorce de ginkgo (crêtes et sillons). Étape 27 : motifs revus d'après les descriptions botaniques (docs/ETAPE27.md),
// prototype numpy : check/ecorce2.py. Écorce : UV.x = fraction du tour, UV.y = longueur (m), UV2.x = cellules de 2,5 mm
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
uniform vec3 stones[3];
uniform int leaf_shape = -1;  // feuilles : 0 orme, 1 érable, 2 ginkgo ; contour et nervures tracés ici (audit, phase 2)  // gravier : x, z, rayon des pierres (coordonnées du monde)

varying vec3 wpos;
varying float young_k;
varying float dry_k;
varying float autumn_k;

float h(vec2 p, float s) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + s) * 43758.5453);
}

// Bruit de valeur lissé, périodique en x (période per) pour ne pas faire de couture autour du tronc.
float vn(vec2 p, float per, float s) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, per);
	float x1 = mod(i.x + 1.0, per);
	return mix(mix(h(vec2(x0, i.y), s), h(vec2(x1, i.y), s), f.x),
			mix(h(vec2(x0, i.y + 1.0), s), h(vec2(x1, i.y + 1.0), s), f.x), f.y);
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
	if (pattern == 1 || pattern == 2 || pattern == 4 || pattern == 6) {
		vec3 b = tone1;
		if (pattern == 1) {
			// orme de Chine : plaques grises irrégulières qui s'exfolient en révélant du cannelle, de l'orangé, du crème,
			// plus clair au centre, bord sombre du lambeau qui se décolle (UF/IFAS ST-652, Boone County Arboretum)
			float per = max(floor(UV2.x / 3.0), 1.0);
			vec2 p = vec2(UV.x * per + 0.7 * (vn(vec2(UV.x * per, UV.y / 0.02), per, 7.0) - 0.5),
					UV.y / 0.012 + 0.9 * (vn(vec2(UV.x * per, UV.y / 0.03), per, 8.0) - 0.5));
			vec3 v = voro(p, per, 1.0);
			if (per >= 2.0) {
				if (v.z < 0.66) {
					b = mix(tone1, tone2, h(vec2(v.z, 0.0), 2.0) * 0.5) * (v.y < 0.03 ? 0.8 : 1.0);
				} else {
					b = (v.z < 0.85 ? tone3 : mix(tone3, vec3(0.86, 0.8, 0.66), 0.5)) * (1.1 - 0.35 * v.x);
					if (v.y < 0.05) {
						b = mix(b, fissure, 0.6);
					}
				}
			}
		} else if (pattern == 2) {
			// pin noir : gris sur les jeunes branches ; puis plaques allongées faites de petites écailles, gris foncé
			// à gris-violet, fissures longitudinales brun-rouge qui se creusent avec l'âge (Conifer Society, Wikipédia)
			float per = max(floor(UV2.x / 5.0), 1.0);
			float px = UV.x * per + 0.3 * (vn(vec2(UV.x * per, UV.y / 0.04), per, 3.0) - 0.5);
			vec3 v = voro(vec2(px, UV.y / 0.05), per, 2.0);
			vec3 sc = voro(vec2(px * 3.0, UV.y / 0.012), per * 3.0, 5.0);
			if (UV2.x >= 8.0) {
				float w = 0.03 + 0.12 * clamp((per - 1.0) / 4.0, 0.0, 1.0);
				b = mix(tone1, tone2, v.z) * (0.9 + 0.15 * vn(vec2(UV.x * per * 6.0, UV.y / 0.006), per * 6.0, 9.0));
				if (sc.y < 0.035) {
					b *= 0.8;
				}
				if (v.y < w) {
					b = v.y < w * 0.4 ? fissure * 0.7 : fissure;
				}
			} else {
				b = tone1 * (sc.y < 0.03 ? 0.88 : 1.05);
			}
		} else if (pattern == 4) {
			// érable : lisse, gris clair, marbrures discrètes, fines stries claires interrompues, petites lenticelles
			// (Virginia Tech Dendrology, NC State)
			float n = max(floor(UV2.x * 0.6), 1.0);
			b = mix(tone1, tone3, clamp((vn(vec2(UV.x * n, UV.y / 0.02), n, 3.0) - 0.55) / 0.2, 0.0, 1.0) * 0.6);
			float col = floor(UV.x * UV2.x * 1.5);
			float k = h(vec2(col, 0.0), 3.0);
			if (k > 0.85 && fract(UV.y / 0.03 + k * 7.0) < 0.6) {
				b = tone2;
			}
			if (h(vec2(floor(UV.x * UV2.x * 3.0), floor(UV.y / 0.0025)), 11.0) < 0.012) {
				b *= 0.86;
			}
		} else {
			// ginkgo : rameau gris-brun clair, lisse et finement strié ; tronc à crêtes verticales entrecroisées,
			// sillons qui se creusent avec l'âge (Virginia Tech Dendrology, College of DuPage)
			float per = max(floor(UV2.x / 2.5), 1.0);
			if (UV2.x >= 20.0) {
				float px = UV.x * per + 0.45 * (vn(vec2(UV.x * per, UV.y / 0.05), per, 6.0) - 0.5);
				vec3 v = voro(vec2(px, UV.y / 0.03), per, 6.0);
				float w = 0.02 + 0.08 * clamp((per - 8.0) / 8.0, 0.0, 1.0);
				b = mix(tone2, tone1, clamp(v.y * 4.0, 0.0, 1.0));
				if (v.y < w) {
					b = v.y < w * 0.5 ? fissure * 0.75 : fissure;
				}
			} else if (h(vec2(floor(UV.x * UV2.x * 3.0), 0.0), 4.0) > 0.8) {
				b = tone2;
			}
		}
		b = mix(b, young_color, young_k * 0.35);
		b = mix(b, dry_color, dry_k * 0.7);
		c = mix(b, COLOR.rgb, COLOR.a);
	} else if (pattern == 3) {
		float k = h(floor(wpos.xz / 0.004), 4.0);
		c = albedo.rgb * (k < 0.3 ? 1.25 : (k < 0.6 ? 1.0 : 0.8));
	} else if (pattern == 5) {
		float d = 9.0;
		for (int i = 0; i < 3; i++) {
			d = min(d, length(wpos.xz - stones[i].xy) - stones[i].z);
		}
		float l = d < 0.36 ? d / 0.08 : wpos.z / 0.08;  // ondes concentriques près des pierres, sinon lignes droites
		c = albedo.rgb * (fract(l) < 0.22 ? 0.86 : 1.0) * (h(floor(wpos.xz / 0.02), 2.0) < 0.2 ? 0.95 : 1.0);
	}
	c = mix(c, autumn_color, autumn_k * 0.85);
	if (leaf_shape >= 0 && UV.x > 0.0) {
		// UV.x : 0 au centre du limbe, 1 au bord ; UV2 : position dans le plan de la feuille, base du limbe en 0,
		// unité = longueur de la feuille, x le long de la nervure centrale, y sur le côté.
		vec2 q = UV2;
		bool vein = false;
		if (leaf_shape == 0) {
			// orme : nervure centrale, 5 paires de nervures secondaires obliques vers le bord
			float k = (q.x - abs(q.y) * 0.6) / (0.85 / 6.0);
			vein = (abs(q.y) < 0.012 && q.x < 0.95) || (abs(q.y) > 0.01 && abs(k - round(k)) < 0.06 && round(k) >= 1.0 && round(k) <= 5.0);
		} else {
			float a = atan(q.y, q.x);
			float r = length(q);
			if (leaf_shape == 1) {
				// érable : une nervure par lobe (5 ou 7, dans l'alpha de la couleur), depuis la base du limbe
				float lobes = round(COLOR.a * 10.0);
				float spread = radians(lobes > 6.0 ? 105.0 : 95.0);
				float gap = spread * 2.0 / (lobes - 1.0);
				float i = clamp(round((a + spread) / gap), 0.0, lobes - 1.0);
				vein = abs(a - (-spread + gap * i)) * r < 0.006 && r < 0.27;
			} else {
				// ginkgo : fines nervures en éventail, à peine plus sombres
				vein = abs(fract(a / 0.14 + 0.5) - 0.5) * 0.14 * r < 0.0035 && r > 0.04;
			}
		}
		if (vein) {
			c *= leaf_shape == 2 ? 0.88 : 0.75;
		}
		if (UV.x > 0.95) {
			c = vec3(0.08, 0.14, 0.06);  // contour fin à l'encre
		}
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

// Animation de la pousse jouée par la carte graphique : le maillage est celui de fin de période,
// chaque sommet porte ses dates (semaines) et le shader affiche l'arbre à l'instant anim_time.
uniform float anim_time = 0.0;
uniform float anim_t0 = 0.0;   // début de la période animée
uniform float anim_t1 = 0.0;   // fin de la période animée (état du maillage)

// Bois. c0 = (naissance de l'entre-nœud, durée d'allongement, épaisseur début/fin, séchage),
// c1 = (centre de l'anneau, disparition), c2 = (départ de la pousse, part de l'entre-nœud où se trouve l'anneau).
// shown = 0 si l'anneau n'existe pas encore (ou plus) à cet instant.
vec3 anim_wood(vec3 v, vec4 c0, vec4 c1, vec4 c2, out float shown) {
	float f = clamp((anim_time - c0.x) / max(c0.y, 0.001), 0.0, 1.0);
	float g = c2.w > 0.0 ? clamp(f / c2.w, 0.0, 1.0) : 1.0;
	if (anim_time < c0.x || anim_time > c1.w) {
		g = 0.0;
	}
	shown = g > 0.0 ? 1.0 : 0.0;
	float k = anim_t1 > anim_t0 ? clamp((anim_time - anim_t0) / (anim_t1 - anim_t0), 0.0, 1.0) : 1.0;
	vec3 cc = mix(c2.xyz, c1.xyz, g);  // l'anneau suit la pointe qui avance
	return cc + (v - c1.xyz) * mix(c0.z, 1.0, k) * g;  // et le bois épaissit
}

// Feuilles et aiguilles. c0 = (naissance, durée de croissance, chute), c1 = (point d'attache final),
// c2 = (départ de l'entre-nœud, durée de son allongement ; 0 = attache immobile).
// La feuille sort petite (15 %) et suit la pointe de la tige qui s'allonge, puis finit de grandir (étape 30a).
vec3 anim_leaf(vec3 v, vec4 c0, vec4 c1, vec4 c2) {
	float f = mix(0.15, 1.0, clamp((anim_time - c0.x) / max(c0.y, 0.001), 0.0, 1.0));
	if (anim_time < c0.x || anim_time > c0.z) {
		f = 0.0;
	}
	float g = c2.w > 0.0 ? clamp((anim_time - c0.x) / c2.w, 0.0, 1.0) : 1.0;
	return mix(c2.xyz, c1.xyz, g) + (v - c1.xyz) * f;
}

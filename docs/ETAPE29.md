# Étape 29 — Racines à nu et racines sur pierre

Validé par le joueur le 28/11/2026. 29a : niveau de la terre. 29b : la pierre (faite).

## Sources
- Sekijoju (racines sur pierre) : les racines enserrent une pierre au pied du tronc, plus ou moins à nu, puis plongent
  dans la terre ; neagari : racines à nu prolongeant le tronc, jusqu'à la moitié ou aux deux tiers de la hauteur
  (Wikipédia, Bonsai styles).
- Méthode : arbre posé sur la pierre, racines serrées, planté profond ; la terre est retirée peu à peu sur des années
  (Meislik, Ficus) ; les racines mises à nu s'épaississent et prennent une écorce (A Certain Luck) ; une racine à l'air
  devient du tronc, seulement si ses pointes sont dans la terre (Bonsai Bark).
- Une racine épaisse exposée ne meurt pas mais ne fait plus de latérales ; les fines exposées ne grossissent plus
  (Bonsai Nut) ; exposer trop tôt fait perdre des racines par dessèchement (Fire Escape Bonsai) ; on retire la terre
  au fil des années, à mesure que les racines s'épaississent, en 2 à 6 ans ou plus (Bonsai Tonight).

## 29a — Contenu
- Mode racines du rempotage : boutons « Baisser la terre » et « Monter la terre », par 1 cm (de -3 cm, ou 60 % de la
  profondeur du pot, à +4 cm en butte). Niveau gardé dans `RootSim.soil_y`.
- Pousse : pointe à l'air = ne pousse plus ; les racines visent une profondeur sous le niveau de la terre ; la butte
  est une terre plus étroite vers le haut.
- Fin d'année : racine fine (moins de 2 mm) à l'air = desséchée avec tout ce qu'elle porte ; racine sans pointe dans la
  terre = desséchée ; les épaisses continuent de grossir ; l'arbre perd la part de racines desséchées.
- Dessin : terre à son niveau, butte au-dessus du pot (écran de travail et jardin) ; toutes les racines au-dessus de
  la terre sont dessinées.

## Vérification (banc d'essai, orme, 6 ans, terre baissée d'1 cm chaque printemps dès la 4e année)
| | segments | à nu | à nu épaisses | rayon moyen à nu |
|---|---|---|---|---|
| terre d'origine | 1 250 | 0 | 0 | — |
| terre baissée (-3 cm) | 920 | 350 | 320 | 1,8 mm |
Dessin des racines exportées : docs/racines_nu_29a.png (check/racines_nu.py).

## 29b : la pierre (faite)
- Bouton « Poser sur une pierre » en mode racines : petite, moyenne ou haute. Une seule pierre par arbre.
- La pierre touche le collet ; le pot est abaissé pour l'enterrer aux deux tiers ; la terre monte en butte jusqu'au
  collet (comme en vrai : on plante profond, puis on dégage). Les racines à plus de 3 cm du collet sont coupées,
  les autres plaquées sur la pierre.
- Simulation : forme de pierre commune au calcul et au dessin (ellipsoïde bosselé) ; aucune racine n'y entre ;
  près de la pierre, les pointes descendent en suivant sa surface, plaquées contre elle, puis s'étalent dans le pot.
- Baisser la terre au fil des années découvre la pierre et ses racines : les épaisses restent (elles deviennent du
  tronc), les fines à nu sèchent (règle du 29a).
- Banc (orme, pierre moyenne en 2e année, terre baissée de 1,5 cm par an dès la 4e) : 1197 segments, 92 à nu dont
  89 épaisses, aucune dans la pierre, santé 1,08. Dessin : `docs/pierre_29b.png`.
- Jardin d'exposition : la pierre est dessinée, le pot posé plus bas sur l'emplacement.

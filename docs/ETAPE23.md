# Étape 23a — Racines simulées (pousse, grossissement, collet)

Validé par le joueur le 27/11/2026. L'étape 23b (travail des racines au rempotage : coupe, pivot, tuile) suivra.

## Botanique (sources)
- 5 à 15 racines structurelles (ou plus) partent du collet, d'abord en oblique puis à l'horizontale ; près du tronc (zone de rapide décroissance), fort épaississement secondaire absent plus loin : contreforts. — Arboriculture & Urban Forestry, synthèse sur l'architecture racinaire (uf.frec.vt.edu, 2010).
- Le pivot pousse très lentement chez la plupart des arbres ; quelques grosses latérales horizontales dominent, puis se ramifient en racines fines. — Encyclopedia.com, « Tree Architecture ».
- Sectorialité : chez certaines espèces, une racine nourrit surtout les branches du même côté ; chez les conifères la sève monte en spirale. — Colorado State Extension, CMG GardenNotes #659.
- Érable : système intégré, chaque secteur de racines nourrit deux grandes parties du houppier. — Nadezhdina et al., Annals of Forest Science 2010 (Acer platanoides).
- Équilibre : un petit système racinaire ne nourrit qu'un petit houppier ; les racines ne grossissent qu'avec le sucre des feuilles. — Portland, Tree physiology primer.
- Bonsaï : retirer les racines plongeantes, favoriser les radiales (BCI, BSAM 2016 Q3) ; une grosse racine coupée en donne deux plus petites (forum Bonsai Nut) ; l'érable forme facilement de belles racines de surface (Bonsai Tonight, 2016) ; semis de pin bouturé : 3 à 7 racines au point de coupe (Bonsai Nut).

## Contenu
1. Charpente racinaire en entre-nœuds de 1,2 cm (`scripts/root_sim.gd`, `RootSim`), selon l'espèce :
   - orme : 7 racines primaires, ramification moyenne, secteurs marqués (intégration 0,25) ;
   - érable : 9 racines, très ramifiées et superficielles, système intégré (0,6) ;
   - pin : un pivot et 4 latérales, ramification faible, intégration 0,4.
2. Pousse au printemps, début d'été et fin d'été (semaines 14, 22, 36). Les pointes vont vers la terre libre (grille de 1 cm dans le pot) ; elles courent sous la surface, à fleur de terre près du tronc et plus profond au-delà ; au bord du pot elles glissent le long de la paroi (encerclement). Ramification : latérale presque horizontale, jusqu'à l'ordre 4.
3. Grossissement chaque fin d'été (modèle des tuyaux) : chaque pointe porte la part du houppier de son secteur (8 secteurs autour du tronc), mélangée selon l'intégration de l'espèce ; une racine grossit selon le flux qu'elle porte, comme le tronc ; contreforts : grossissement jusqu'à 3 fois plus fort près du collet. Les grosses racines proches du tronc dépassent de la terre : c'est le nebari.
4. Dessin : racines avec les mêmes anneaux que le bois ; seules les parties qui dépassent de la terre sont dessinées. Les fausses racines décoratives disparaissent.
5. Physiologie : la quantité de racines garde ses règles actuelles (équilibre validé à l'étape 17) ; la charpente pousse pour la suivre (5 cm de racine ligneuse par unité). Au rempotage, la part coupée retire les racines les plus éloignées du tronc (la coupe à la main viendra en 23b). Anciennes sauvegardes : charpente de départ reconstituée.
6. Plafond de 1500 segments racinaires ; mesure du temps de calcul, C++ seulement si besoin.

## Écart avec la proposition
- Point 6 de la proposition : la quantité de racines ne sera pas recalculée depuis la charpente en 23a, pour ne pas dérégler l'équilibre physiologique ; c'est la charpente qui suit la quantité. En 23b, couper des racines retirera la même part de la quantité.

## Vérification
- `check/racines.py` : prototype Python du même algorithme, vue de dessus, coupe et collet de trois quarts.

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

# Étape 23b — Travail des racines et tronc plus lent

Validé par le joueur le 27/11/2026.

## Tronc
- En pot, un arbre pousse environ cinq fois moins vite qu'en pleine terre (Toronto Master Gardeners) ; orme ou érable champêtre en pleine terre : de 1,3 cm à 5-7,5 cm de diamètre en trois ans (bonsai4me) ; en pot de bonsaï, racines à l'étroit et taille régulière, le tronc ne grossit plus que très lentement (bonsaibark) ; pot trop petit : épaississement quasi nul (bonsai4me).
- Cerne de base 0,6 fois l'ancien (`RING_AREA` 0,9e-6, appliqué aussi aux anciens arbres).
- Pot plein (racines au-delà de 70 % de la limite du pot) : jusqu'à -60 %. Santé (réserves / racines) : cerne × santé, au moins 20 %. Le rapport racines / houppier limite toujours. Les racines suivent les mêmes facteurs.
- Diamètre du tronc affiché en mm dans les infos, pour régler à l'usage.

## Rempotage
- « Rempoter » : l'arbre sort du pot, toute la charpente est dessinée, la caméra descend au collet.
- Toucher une racine la choisit (surlignée avec ce qui en part) ; « Couper la racine » la retire ; 2 ou 3 jeunes racines repartent du bout coupé. Le pivot du pin se retire de la même façon.
- Tuile : posée ou retirée depuis ce mode ; tant qu'elle est là, les racines au-dessus d'elle (6 cm autour du tronc) ne descendent plus sous 1,2 cm.
- « Replanter » : choix du pot ; la part coupée est la vraie part de racines retirée ; les racines qui dépassent du nouveau pot sont coupées (comptées dans la part coupée). Réaction de l'arbre inchangée (réserves, saison).

## Plus tard (idées du joueur)
- Arbre sur rocher (ishitsuki) : le rocher devient un obstacle dans la terre, les racines suivent sa surface et l'enserrent.
- Mettre à nu plus de racines : hauteur de plantation réglable au rempotage (on remonte l'arbre / on baisse la terre).

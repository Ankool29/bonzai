# Étape 25 — Ginkgo biloba

Validé par le joueur le 27/11/2026.

## Botanique (sources)
- Deux sortes de pousses : pousses longues aux feuilles espacées ; rameaux courts aux entre-nœuds minimes, nés à l'aisselle des feuilles sur le bois de 2 ans, qui ne gagnent que 1 à 2 cm en plusieurs années, feuilles le plus souvent non lobées (Conifer Society, Ginkgo ; Critchfield 1970, Bot. Gaz. 131 ; Leigh et al. 2011, New Phytologist 189).
- Les rameaux courts portent une rosette chaque année pendant de nombreuses années, puis peuvent s'allonger en pousse longue (EBSCO Research Starters, Ginkgos ; Gymno-info).
- Feuilles en éventail, bilobées à 4 lobes sur les pousses longues, en éventail entier sur les rameaux courts (EBSCO) ; jaune vif à l'automne, chute en 1 à 15 jours (Conifer Society).
- Pousse lente, couronne ouverte et irrégulière (UF/IFAS ST-273).
- Bonsaï : rabattage sévère possible, repart sur le tronc et rejette du pied (Bonsai Nut, « Ginkgo chop ») ; les cicatrices ne se referment pas, éviter les grosses coupes ; ramification limitée en pot (Phoenix Bonsai ; Aussie Bonsai, « Ginkgo ramification »).

## Contenu
- Fiche `Species.GINKGO` : vigueur 1,4 (lente), entre-nœuds 2,5 cm, alterne spiralée, une poussée au printemps (semaine 15) et une petite reprise (22), jusqu'à 6 rejets, racines pivotantes.
- Nouvelles clés communes à toutes les fiches : `heal` (fermeture des plaies ; ginkgo 0,15), `fall_span` (chute des feuilles ; ginkgo 1 semaine), `spur_years` (rosettes des rameaux courts ; ginkgo 12 ans, autres 5).
- Feuille en éventail (`leaf_shape` 2) : bilobée sur les pousses longues, entière dans les rosettes ; jaune vif à l'automne.
- Écorce gris-brun fissurée (motif de l'orme, couleurs du ginkgo).
- Liste `Species.ALL` utilisée par le jardin et le chargement.

## Vérification
- Portage Python (check/gink.py, pot de 8 L) : à 6 ans, 31 cm et 115 entre-nœuds (orme : 57 cm, 712), environ 28 rameaux courts ; jeune arbre élancé à couronne ouverte. Feuille dessinée avec la même formule (check/fan.py). Image : docs/ginkgo_verif.png.

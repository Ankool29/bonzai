# Étape 27 — Écorces et feuilles plus réalistes

Validé par le joueur le 28/11/2026. Le style encre de l'étape 26 est retiré (le joueur garde le rendu d'origine).

## Sources
- Orme de Chine : écorce marbrée gris clair, gris foncé, vert, crème, orangé, argent, fauve, brun, qui s'exfolie par plaques irrégulières en révélant une écorce plus claire (Boone County Arboretum ; UF/IFAS ST-652 ; NC State). Feuilles vert foncé brillant.
- Pin noir du Japon : écorce grise sur les jeunes arbres et petites branches, puis noire et en plaques, épaisse sur les vieux troncs (Wikipédia) ; gris foncé ou gris-violet, écailleuse, fissurée en long (Conifer Society).
- Érable du Japon : jeunes tiges vertes à brun-rouge poli, branches âgées grises (NC State) ; écorce lisse gris clair, tronc un peu cannelé (Virginia Tech Dendrology).
- Ginkgo : rameaux brun-rouge clair puis gris ; écorce gris-brun clair à crêtes irrégulières, finissant profondément sillonnée (Virginia Tech Dendrology ; College of DuPage). Feuilles vert clair dessus comme dessous.

## Contenu
- `shaders/toon.gdshader` : bruit lissé périodique autour du tronc (pas de couture) ; orme (plaques irrégulières, lambeaux cannelle, orangé, crème au bord sombre), pin (plaques d'écailles, fissures brun-rouge plus profondes au fond), érable (marbrures, stries, lenticelles), nouveau motif 6 pour le ginkgo (rameau lisse strié ; crêtes et sillons à partir d'environ 8 mm de rayon).
- Couleurs d'écorce de l'orme et du ginkgo ajustées ; nouvelle clé `leaf_colors` (deux verts) dans chaque fiche : orme vert foncé, érable vert tendre, ginkgo vert clair vif.
- Retrait du bouton Rendu, de `shaders/ink.gdshader` et de l'icône pinceau.

## Vérification
- Prototype numpy des motifs (même calcul que le shader) : check/ecorce2.py ; image docs/ecorces_avant_apres.png.

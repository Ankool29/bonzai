# Étape 26 — Style « encre et papier » (retiré à l'étape 27)

Validé par le joueur le 28/11/2026 (modèle : estampe moderne à l'encre, soleil rouge ; « on garde les couleurs d'origine »).

## Contenu
- Bouton « Rendu » (onglet Arbre, icône pinceau) : passe du cel shading au style encre et retour ; choix gardé dans `user://reglages.cfg`.
- `shaders/ink.gdshader` : quad plein écran sous la caméra, sur la scène 3D seulement (l'interface n'est pas touchée) :
  - couleurs d'origine en lavis : légèrement fondues, éclaircies de 18 % vers le papier ;
  - traits d'encre : les contours sombres prennent une densité qui varie par touches, comme au pinceau ;
  - pinceau sec : fines stries horizontales sur les zones foncées ;
  - fond de papier blanc et grand soleil rouge en lavis (plus pâle vers le bas) ;
  - grain du papier.
- Coût : une passe plein écran (5 lectures de l'image), plus la profondeur pour reconnaître le fond.

## Vérification
- Aperçu Python appliqué à la maquette du jardin : check/encre.py.

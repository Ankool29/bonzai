# Étape 7 — cel shading (validé, remplace le rendu pixel art de l'étape 6)

- Pleine résolution (plus de SubViewport basse résolution).
- `shaders/toon.gdshader` : éclairage arrondi à 3 tons nets, ombres portées nettes (tout ou rien), ombres bleutées
  par la lumière ambiante. Motifs : couleur unie, écorce d'orme en grandes plaques, écorce de pin à fissures, terre.
- `shaders/outline.gdshader` : contour par coque inversée (bois et pot), en `next_pass` du matériau.
- Feuilles d'orme en géométrie (pétiole de 3 mm, limbe ovale pointu à base oblique), deux verts, jaunissement à l'automne.
- Les textures PixelLab ne sont plus utilisées (retirées du dépôt, gardées dans l'historique).
- Feuilles détaillées : limbe le plus large sous le milieu, pointe aiguë, base oblique, bord finement denté,
  contour fin sombre, pétiole prolongé en nervure centrale (liseré sombre), 5 paires de nervures secondaires.

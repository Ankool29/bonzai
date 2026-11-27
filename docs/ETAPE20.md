# Étape 20 — rendu pixel art (validé)

- La scène 3D est calculée dans un SubViewport, agrandi sans lissage (SubViewportContainer, stretch_shrink =
  taille du pixel : 1 normal, 2, 3, 4, 6). L'interface reste nette par-dessus.
- shaders/pixel.gdshader : contour d'un pixel (côté sombre d'un écart de luminosité > 0,18), 12 niveaux par
  couleur, léger tramage de Bayer 4×4 (0,3).
- Onglet « Rendu » : « Pixels : non / ×2 / ×3 / ×4 / ×6 » et « Vue : perspective / isométrique ».
  Isométrique = projection orthogonale au même cadrage ; en pixel art, la caméra est calée sur la grille de pixels.
- Positions à l'écran : _sp() (unproject × taille du pixel) partout où l'on touche la scène.
- À venir : palette par espèce (au lieu de niveaux par couleur), rameaux d'au moins un pixel, interface PixelLab.

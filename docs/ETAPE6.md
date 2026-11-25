# Étape 6 — rendu pixel art texturé (validé, remplace les rendus des étapes 5 et 5 bis)

- Scène rendue à ~360 px de large (SubViewport) puis agrandie sans lissage ; lumière du soleil avec ombres.
- Bois : tubes continus, épaisseur lissée le long de chaque axe (fin des à-coups), écorce texturée répétée en miroir
  (`shaders/bark.gdshader`) ; teinte unie pour pousses de l'année, branches affaiblies, bois mort, sélection.
- Feuillage : petites images tournées vers la caméra (`shaders/foliage.gdshader`, MultiMesh), 3 variantes par espèce,
  assombries à l'intérieur de la couronne, jaunies à l'automne (orme).
- Pot rectangulaire en terre cuite, terre d'akadama texturée.
- Textures générées avec PixelLab (16 générations) dans `textures/` : écorces orme et pin (128 px, éclairage cuit
  atténué), terre (128 px), atlas de 3 bouquets de feuilles d'orme (32 px) et de 3 touffes d'aiguilles (48 px).

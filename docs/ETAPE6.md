# Étape 6 — rendu pixel art texturé (validé, remplace les rendus des étapes 5 et 5 bis)

- Scène rendue à ~360 px de large (SubViewport) puis agrandie sans lissage ; lumière du soleil avec ombres.
- Bois : tubes continus, épaisseur lissée le long de chaque axe (fin des à-coups), écorce texturée répétée en miroir
  (`shaders/bark.gdshader`) ; teinte unie pour pousses de l'année, branches affaiblies, bois mort, sélection.
- Feuillage : petites images tournées vers la caméra (`shaders/foliage.gdshader`, MultiMesh), 3 variantes par espèce,
  assombries à l'intérieur de la couronne, jaunies à l'automne (orme).
- Pot rectangulaire en terre cuite, terre d'akadama texturée.
- Textures générées avec PixelLab (16 générations) dans `textures/` : écorces orme et pin (128 px, éclairage cuit
  atténué), terre (128 px), atlas de 3 bouquets de feuilles d'orme (32 px) et de 3 touffes d'aiguilles (48 px).

## Correctifs après essai (validés)
- Feuilles d'orme : une feuille simple par nœud (atlas PixelLab de 3 feuilles sans tige, 1,6 cm), tournée au hasard
  dans son plan ; fini les « branches collées ».
- Pin : aiguilles par paires dessinées en géométrie (deux triangles fins croisés, trois verts) au lieu d'images.
- Écorce procédurale en pixels (cellules de 2,5 mm, deux tons, taches orangées de l'orme, fissures allongées) au lieu
  des textures PixelLab ; tracé des axes lissé en plus de l'épaisseur ; tubes à 12 faces.
- Terre plus fine. Vérifié sur un aperçu calculé avec le portage Python (orme 2 et 8 ans, pin 4 ans).

## Correctifs 2 (validés)
- Tronc : les anneaux du tube sont espacés d'au moins 1,2 rayon (sinon un tube épais se replie dans les virages,
  d'où le tronc « en morceaux »), puis tracé en courbe de Catmull-Rom.
- Feuilles d'orme : plan texturé ancré au nœud (pétiole au nœud), limbe presque horizontal dans le prolongement du
  bourgeon, feuilles de 2 cm ; plus d'images tournées vers la caméra.
- Écorce d'orme d'après la documentation : plaques desquamées marbrées (gris, olive, beige, orangé, crème) sur le bois
  âgé, rameaux fins gris-brun lisses.
- Sources : UF/IFAS ST-652 (Ulmus parvifolia), UConn Plant Database, Flora of North America.

## Correctifs 3 (tronc)
- Anneaux espacés d'au moins 2,5 rayons puis lissage de Chaikin (la spline de Catmull-Rom dépassait et faisait des boucles).
- Départ de branche enfoncé dans le parent et jamais plus épais que lui ; bouts de tube fermés (plus de « manchons » creux).
- Pipe model en exposant 3 (branches plus fines) et zigzag de l'orme réduit (jitter 0,06).
- Épaisseur : le pipe model (épaisseur = nombre de rameaux portés, en marches d'escalier) est remplacé par un cerne
  annuel proportionnel au feuillage porté (loi de Pressler, ring_area = 1,5e-6) : branches qui s'affinent
  continûment, tronc conique qui grossit avec les années. Orme de 8 ans : tronc d'environ 3 cm à la base.

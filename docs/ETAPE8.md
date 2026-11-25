# Étape 8 — pousse fluide : calculer d'abord, animer ensuite (validé)

- « +1 semaine / saison / an » : la période est simulée puis maillée dans un fil de calcul
  (WorkerThreadPool) ; une feuille tourne pendant le calcul, la caméra reste utilisable, boutons grisés.
  Durée du calcul affichée (« calcul … ms ») pour la mesurer sur téléphone.
- Un seul maillage, celui de fin de période ; chaque sommet porte ses dates (CUSTOM0-2) :
  bois = naissance et durée d'allongement de l'entre-nœud, départ de la pousse, part de l'entre-nœud où est
  l'anneau, épaisseur début/fin, séchage, disparition ; feuilles et aiguilles = sortie, croissance, chute,
  point d'attache. Rameaux morts tombés pendant la période : notés par la simulation (`fallen`), dessinés
  jusqu'à leur chute.
- `shaders/anim.gdshaderinc` (inclus par le cel shading et le contour) affiche l'arbre à `anim_time` :
  pousses qui s'allongent, bois qui épaissit, feuilles qui sortent, jaunissent (dans le shader) et tombent,
  rameau de l'année qui brunit, bois qui sèche.
- Animation : ~1 s pour une semaine, ~3 s pour une saison, 6 s pour un an ; toucher l'écran saute à la fin ;
  pas de taille pendant l'animation. À la fin, rien n'est recalculé.
